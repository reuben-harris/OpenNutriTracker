"""Shared download and atomic pin publication for independent sources."""

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from catalogue import ValidationError, canonical


def open_url(url, host):
    response = urlopen(Request(url, headers={'User-Agent': 'OpenNutriTracker-food-data/1'}), timeout=60)
    destination = urlparse(response.url)
    if destination.scheme != 'https' or destination.netloc != host:
        response.close()
        raise ValidationError('Download redirected outside its official HTTPS host')
    return response


def download(url, destination, host):
    with open_url(url, host) as response, Path(destination).open('wb') as output:
        shutil.copyfileobj(response, output)


def atomic_write(path, content):
    path = Path(path)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.food-data-', delete=False) as stream:
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
    subprocess.run(['nix', 'flake', 'update', 'food-data'], cwd=root, check=True)


def check_flake_refresh(before, after):
    before, after = json.loads(before), json.loads(after)
    before['nodes'].pop('food-data', None)
    after['nodes'].pop('food-data', None)
    if before != after:
        raise ValidationError('Flake refresh changed inputs other than food-data')


def publish(root, lock_path, candidate, refresher=refresh_flake):
    original = lock_path.read_bytes()
    if canonical(json.loads(original)) == canonical(candidate):
        return False
    flake_lock = root / 'flake.lock'
    original_flake = flake_lock.read_bytes()
    try:
        atomic_write(lock_path, (json.dumps(candidate, indent=2, sort_keys=True) + '\n').encode())
        refresher(root)
        check_flake_refresh(original_flake, flake_lock.read_bytes())
    except BaseException:
        atomic_write(lock_path, original)
        atomic_write(flake_lock, original_flake)
        raise
    return True
