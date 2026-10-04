"""Discover, validate and atomically pin official USDA CSV releases."""

import argparse
import copy
import csv
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen
import re

from importer import ValidationError, build_database, canonical, load_lock, sha256

from source_fixes import required_auxiliary

INDEX_URL = "https://fdc.nal.usda.gov/download-datasets/"
PREFIXES = {
    "foundation": "FoodData_Central_foundation_food_csv_",
    "sr_legacy": "FoodData_Central_sr_legacy_food_csv_",
    "survey": "FoodData_Central_survey_food_csv_",
    "supporting": "FoodData_Central_Supporting_Data_csv_",
}


class DownloadLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            href = dict(attrs).get("href")
            if href:
                self.links.append(urljoin(INDEX_URL, href))


def discover(html):
    parser = DownloadLinks()
    parser.feed(html)
    candidates = {key: {} for key in PREFIXES}
    for url in parser.links:
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.netloc != "fdc.nal.usda.gov" or parsed.query or parsed.fragment:
            continue
        for key, prefix in PREFIXES.items():
            match = re.fullmatch(r"/fdc-datasets/" + re.escape(prefix) + r"(\d{4}-\d{2}(?:-\d{2})?)\.zip", parsed.path)
            if match:
                candidates[key][match[1]] = url
    result = {}
    for key, releases in candidates.items():
        if not releases:
            raise ValidationError(f"Official index has no CSV release for {key}")
        release = max(releases)
        result[key] = {"release": release, "url": releases[release]}
    return result


def open_url(url):
    response = urlopen(Request(url, headers={"User-Agent": "OpenNutriTracker-food-data/1"}), timeout=60)
    destination = urlparse(response.url)
    if destination.scheme != "https" or destination.netloc != "fdc.nal.usda.gov":
        response.close()
        raise ValidationError("USDA download redirected outside its official HTTPS host")
    return response


def fetch_index():
    with open_url(INDEX_URL) as response:
        return response.read().decode("utf-8")


def download(url, destination):
    with open_url(url) as response, Path(destination).open("wb") as output:
        shutil.copyfileobj(response, output)


def atomic_write(path, content):
    path = Path(path)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".food-data-", delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.chmod(temporary, path.stat().st_mode & 0o777 if path.exists() else 0o644)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def refresh_flake(root):
    # A named update never upgrades nixpkgs or the other root inputs.
    subprocess.run(["nix", "flake", "update", "food-data"], cwd=root, check=True)


def check_flake_refresh(before, after):
    before = json.loads(before)
    after = json.loads(after)
    before["nodes"].pop("food-data", None)
    after["nodes"].pop("food-data", None)
    if before != after:
        raise ValidationError("Flake refresh changed inputs other than food-data")


def update(root, *, index_fetcher=fetch_index, downloader=download, refresher=refresh_flake, progress=None):
    progress = progress or (lambda message: None)
    root = Path(root).resolve()
    lock_path = root / "nix/food-data/sources.json"
    flake_lock = root / "flake.lock"
    if not (root / "flake.nix").is_file() or not lock_path.is_file() or not flake_lock.is_file():
        raise ValidationError("Run update-food-data from the repository root")
    original = lock_path.read_bytes()
    original_flake = flake_lock.read_bytes()
    lock = load_lock(lock_path)
    progress("Reading USDA's release index...")
    releases = discover(index_fetcher())
    candidate = copy.deepcopy(lock)
    cache = root / ".nix-cache/food-data"
    cache.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="candidate-", dir=cache) as temporary:
        temporary = Path(temporary)
        paths = {}
        for key in sorted(releases):
            release = releases[key]
            if release["release"] < lock["sources"][key]["release"]:
                raise ValidationError(f"Official index would downgrade {key}")
            paths[key] = temporary / f"{key}.zip"
            progress(f"Downloading {key} {release['release']}...")
            downloader(release["url"], paths[key])
            candidate["sources"][key].update(release, sha256=sha256(paths[key]))
            progress(f"Downloaded {key}: {paths[key].stat().st_size:,} bytes; SHA256 calculated.")
        auxiliary = required_auxiliary(candidate)
        candidate.pop("auxiliary", None)
        if auxiliary:
            candidate["auxiliary"] = auxiliary
        for key, pin in auxiliary.items():
            paths[key] = temporary / f"{key}.zip"
            progress(f"Downloading auxiliary {key} {pin['release']}...")
            downloader(pin["url"], paths[key])
        progress("Generating and validating the candidate catalogue...")
        result = build_database(candidate, paths, temporary / "food-data.sqlite")
        changed = canonical(candidate) != canonical(lock)
        if changed:
            # All download, schema, reference, count and FTS checks have passed.
            # Roll back both locks if Nix fails or updates an unrelated input.
            try:
                progress("Candidate validated; updating source pins and the food-data flake entry...")
                atomic_write(lock_path, (json.dumps(candidate, indent=2, sort_keys=True) + "\n").encode("utf-8"))
                refresher(root)
                check_flake_refresh(original_flake, flake_lock.read_bytes())
            except BaseException:
                atomic_write(lock_path, original)
                atomic_write(flake_lock, original_flake)
                raise
        result["pins_changed"] = changed
        progress("Update complete." if changed else "Candidate validated; source pins are unchanged.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        result = update(args.root, progress=lambda message: print(message, file=sys.stderr, flush=True))
        print(json.dumps(result, indent=2, sort_keys=True))
    except KeyboardInterrupt:
        parser.exit(130, "Food-data update cancelled.\n")
    except (ValueError, sqlite3.Error, csv.Error, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Food-data update failed; existing pins retained: {error}\n")


if __name__ == "__main__":
    main()
