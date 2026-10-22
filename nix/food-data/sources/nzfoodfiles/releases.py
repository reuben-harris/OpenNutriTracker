"""Discover official FOODfiles bulk releases and atomically update NZ pins."""

import copy
import json
import re
import tempfile
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin

from catalogue import sha256, ValidationError
from updates import open_url, download as source_download, publish, refresh_flake
from .importer import build_database, load_lock

INDEX_URL = 'https://www.foodcomposition.co.nz/foodfiles/'
HOST = 'www.foodcomposition.co.nz'


class DownloadLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == 'a' and dict(attrs).get('href'):
            self.links.append(urljoin(INDEX_URL, dict(attrs)['href']))


def discover(html):
    links = DownloadLinks()
    links.feed(html)
    candidates = {}
    for url in links.links:
        match = re.fullmatch(r'https://www\.foodcomposition\.co\.nz/downloads/foodfiles-(\d{4})-v([1-9][0-9]*)\.msi', url)
        if match:
            candidates[(int(match[1]), int(match[2]))] = {'release': f'{match[1]}-v{match[2]}', 'url': url}
    if not candidates:
        raise ValidationError('Official FOODfiles index has no bulk MSI release')
    return candidates[max(candidates)]


def fetch_index():
    with open_url(INDEX_URL, HOST) as response:
        return response.read().decode('utf-8')


def download(url, output):
    source_download(url, output, HOST)


def update(root, *, index_fetcher=fetch_index, downloader=download, refresher=refresh_flake, progress=None):
    root = Path(root).resolve()
    lock_path = root / 'nix/food-data/sources/nzfoodfiles/sources.json'
    if not (root / 'flake.nix').is_file() or not (root / 'flake.lock').is_file() or not lock_path.is_file():
        raise ValidationError('Run update-food-data from the repository root')
    progress = progress or (lambda message: None)
    lock = load_lock(lock_path)
    progress('Reading the official FOODfiles bulk release index...')
    latest = discover(index_fetcher())
    def version(release):
        year, number = release.split('-v')
        return int(year), int(number)
    if version(latest['release']) < version(lock['sources']['foodfiles']['release']):
        raise ValidationError('Official index would downgrade FOODfiles')
    cache = root / '.nix-cache/food-data'
    cache.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='nzfoodfiles-', dir=cache) as temporary:
        archive = Path(temporary) / 'foodfiles.msi'
        progress(f'Downloading FOODfiles {latest["release"]}...')
        downloader(latest['url'], archive)
        candidate = copy.deepcopy(lock)
        candidate['sources']['foodfiles'].update(latest, sha256=sha256(archive))
        progress('Generating and validating the candidate NZ catalogue...')
        result = build_database(candidate, {'foodfiles': archive}, Path(temporary) / 'catalogue.sqlite')
        result['pins_changed'] = publish(root, lock_path, candidate, refresher)
        progress('Update complete.' if result['pins_changed'] else 'Candidate validated; source pins are unchanged.')
        return result
