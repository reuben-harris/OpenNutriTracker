"""Update explicitly selected food databases without upgrading unrelated sources."""

import argparse
import importlib
import json
import sys
from pathlib import Path


def main():
    registered = json.loads(Path(__file__).with_name('registry.json').read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sources', nargs='*')
    parser.add_argument('--all', action='store_true')
    parser.add_argument('--root', type=Path, default=Path.cwd())
    args = parser.parse_args()
    if bool(args.sources) == args.all or not set(args.sources) <= set(registered):
        parser.error(f'Select database IDs ({", ".join(registered)}) or --all explicitly')
    failed = False
    for source in sorted(set(registered if args.all else args.sources)):
        try:
            module = importlib.import_module(f'sources.{source}.releases')
            result = module.update(args.root, progress=lambda message: print(message, file=sys.stderr, flush=True))
            print(json.dumps({'source': source, **result}, sort_keys=True))
        except KeyboardInterrupt:
            parser.exit(130, 'Food-data update cancelled.\n')
        except Exception as error:
            print(f'{source}: update failed; existing pins retained: {error}', file=sys.stderr)
            failed = True
    if failed:
        parser.exit(1)


if __name__ == '__main__':
    main()
