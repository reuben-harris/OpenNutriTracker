"""Project the complete reviewed USDA import into the shared catalogue."""

import argparse
import contextlib
import json
import re
import sqlite3
import tempfile
from pathlib import Path

from catalogue import canonical, database, SourceRecords
from . import importer

MAPPING = {
    'energyKcal100': (2048, 2047, 1008),
    'carbohydrates100': (1005,), 'fat100': (1004,), 'proteins100': (1003,),
    'sugars100': (1063,), 'saturatedFat100': (1258,), 'fiber100': (1079,),
    'monounsaturatedFat100': (1292,), 'polyunsaturatedFat100': (1293,),
    'transFat100': (1257,), 'cholesterol100': (1253,), 'sodium100': (1093,),
    'potassium100': (1092,), 'magnesium100': (1090,), 'calcium100': (1087,),
    'iron100': (1089,), 'zinc100': (1095,), 'phosphorus100': (1091,),
    'vitaminA100': (1106,), 'vitaminC100': (1162,), 'vitaminD100': (1114,),
    'vitaminB6100': (1175,), 'vitaminB12100': (1178,), 'niacin100': (1167,),
}


def portion_label(row):
    description = (row['portion_description'] or '').strip()
    modifier = (row['modifier'] or '').strip()
    unit = row['unit_name']
    amount = float(row['amount'] or 1)
    count = amount if amount > 0 else 1.0
    number = str(int(count)) if count.is_integer() else str(count)
    measure = modifier if unit is None or unit == 'undetermined' else unit
    if description:
        return description if re.match(r'^\d', description) else f'{number} {description}'
    return f'{number} {measure or "portion"}'


def project(raw, output, lock):
    raw.row_factory = sqlite3.Row
    with database(output) as db:
        db.execute('INSERT INTO catalogue_source VALUES (?, ?, ?, ?, ?, ?, ?)', (
            'usda', 'FoodData Central', canonical({k: p['release'] for k, p in lock['sources'].items()}),
            'U.S. Department of Agriculture, Agricultural Research Service. FoodData Central.',
            'https://fdc.nal.usda.gov/', 'https://fdc.nal.usda.gov/data-documentation/', 0,
        ))
        records = SourceRecords(db, 'usda')
        for table in (*importer.CATALOGUE_TABLES, 'metadata'):
            columns = raw.execute(f'PRAGMA table_info({table})').fetchall()
            keys = [c[1] for c in sorted(columns, key=lambda c: c[5]) if c[5]]
            for row in raw.execute(f'SELECT * FROM {table}'):
                records.record(table, canonical([row[k] for k in keys]), dict(row))
        for food in raw.execute("SELECT fdc_id, description FROM food_name WHERE locale='en' ORDER BY fdc_id"):
            identity = food['fdc_id']
            code = f'usda:{identity}'
            amounts = {}
            for nutrient in raw.execute('SELECT nutrient_id, amount FROM food_nutrient WHERE fdc_id=? ORDER BY nutrient_id, id', (identity,)):
                amounts.setdefault(nutrient['nutrient_id'], nutrient['amount'])
            nutrition = {key: next((amounts[n] for n in ids if amounts.get(n) is not None), None)
                         for key, ids in MAPPING.items()}
            db.execute('INSERT INTO food VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (
                code, 'usda', str(identity), 'en', food['description'], '',
                f'https://fdc.nal.usda.gov/fdc-app.html#/food-details/{identity}/nutrients', canonical(nutrition),
            ))
            for portion in raw.execute('''SELECT p.*, m.name AS unit_name FROM food_portion p
                    LEFT JOIN measure_unit m ON m.dataset=p.dataset AND m.id=p.measure_unit_id
                    WHERE fdc_id=? ORDER BY p.seq_num, p.id''', (identity,)):
                if portion['gram_weight'] is not None and float(portion['gram_weight']) > 0:
                    db.execute('INSERT INTO food_portion VALUES (?, ?, ?, ?, ?)', (
                        f'usda:{portion["dataset"]}:{portion["id"]}', code,
                        portion['seq_num'] or 0, portion_label(portion), portion['gram_weight'],
                    ))


def build_database(lock, paths, output):
    with tempfile.TemporaryDirectory(prefix='usda-') as temporary:
        path = Path(temporary) / 'raw.sqlite'
        result = importer.build_database(lock, paths, path)
        with contextlib.closing(sqlite3.connect(path)) as raw:
            project(raw, output, lock)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', required=True, type=Path)
    parser.add_argument('--archive', action='append', default=[])
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--raw', type=Path)
    args = parser.parse_args()
    paths = {}
    for argument in args.archive:
        key, separator, path = argument.partition('=')
        if not separator or key in paths:
            parser.error('Each archive must be a unique NAME=PATH')
        paths[key] = Path(path)
    lock = importer.load_lock(args.lock)
    if args.raw is not None:
        with contextlib.closing(sqlite3.connect(f'file:{args.raw}?mode=ro', uri=True)) as raw:
            project(raw, args.output, lock)
    else:
        print(json.dumps(build_database(lock, paths, args.output), indent=2))


if __name__ == '__main__':
    main()
