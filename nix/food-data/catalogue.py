"""Shared, lossless source storage and deterministic app catalogue generation."""

import argparse
import contextlib
import json
import re
import sqlite3
import tempfile
from decimal import Decimal
from pathlib import Path

SCHEMA = Path(__file__).with_name('schema.sql')
TABLES = ('catalogue_source', 'source_table', 'source_record', 'food', 'food_portion')
NUTRIENTS = {
    'energyKcal100', 'carbohydrates100', 'fat100', 'proteins100', 'sugars100',
    'saturatedFat100', 'fiber100', 'monounsaturatedFat100', 'polyunsaturatedFat100',
    'transFat100', 'cholesterol100', 'sodium100', 'potassium100', 'magnesium100',
    'calcium100', 'iron100', 'zinc100', 'phosphorus100', 'vitaminA100',
    'vitaminC100', 'vitaminD100', 'vitaminB6100', 'vitaminB12100', 'niacin100',
}


from values import ValidationError, canonical, sha256, decimal_value


class SourceRecords:
    """Store column names once rather than repeating them in every raw row."""
    def __init__(self, db, source):
        self.db, self.source = db, source
        self.columns = {}

    def record(self, table, identity, payload):
        columns = sorted(payload)
        if table not in self.columns:
            self.db.execute('INSERT INTO source_table VALUES (?, ?, ?)',
                            (self.source, table, canonical(columns)))
            self.columns[table] = columns
        elif self.columns[table] != columns:
            raise ValidationError(f'{self.source}/{table}: inconsistent columns')
        self.db.execute('INSERT INTO source_record VALUES (?, ?, ?, ?)',
                        (self.source, table, str(identity), canonical([payload[k] for k in columns])))


def validate(db):
    if db.execute('PRAGMA user_version').fetchone()[0] != 2:
        raise ValidationError('Unsupported catalogue schema')
    if db.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
        raise ValidationError('SQLite integrity check failed')
    if db.execute('PRAGMA foreign_key_check').fetchmany(5):
        raise ValidationError('Unresolved catalogue references')
    for source, in db.execute('SELECT id FROM catalogue_source'):
        if not re.fullmatch(r'[a-z][a-z0-9-]*', source):
            raise ValidationError(f'Invalid source ID: {source}')
        if not db.execute('SELECT 1 FROM food WHERE source=?', (source,)).fetchone():
            raise ValidationError(f'Empty source: {source}')
    for code, nutrition in db.execute('SELECT code, nutrition FROM food'):
        values = json.loads(nutrition)
        if not isinstance(values, dict) or not set(values) <= NUTRIENTS:
            raise ValidationError(f'{code}: unknown app nutrition fields')
        for value in values.values():
            if isinstance(value, dict):
                if (set(value) != {'value', 'qualification', 'limit'} or value['qualification'] not in {
                        'trace', 'lessThan', 'lessThanOrEqual', 'greaterThan', 'greaterThanOrEqual',
                        'approximate', 'belowDetection', 'belowDetectionOrQuantification',
                        'belowQuantification', 'aggregate'}):
                    raise ValidationError(f'{code}: invalid nutrient qualification')
                if decimal_value(value['value']) is None:
                    raise ValidationError(f'{code}: missing calculation value')
                decimal_value(value['limit'])
            else:
                decimal_value(value)
    for weight, in db.execute('SELECT gram_weight FROM food_portion'):
        if decimal_value(weight) is None or Decimal(weight) <= 0:
            raise ValidationError('Invalid portion weight')
    expected = db.execute('SELECT code, source, locale, name, aliases FROM food').fetchall()
    actual = db.execute('SELECT code, source, locale, name, aliases FROM food_search ORDER BY code').fetchall()
    if sorted(expected) != actual:
        raise ValidationError('Search coverage differs from food records')
    db.execute("INSERT INTO food_search(food_search) VALUES ('integrity-check')")


@contextlib.contextmanager
def database(output):
    """Publish only a validated, indexed and canonicalized database."""
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.catalogue-', dir=output.parent) as temporary:
        path = Path(temporary) / 'catalogue.sqlite'
        db = sqlite3.connect(path)
        try:
            db.executescript(SCHEMA.read_text())
            yield db
            db.execute('INSERT INTO food_search SELECT code, source, locale, name, aliases FROM food ORDER BY code')
            validate(db)
            db.commit()
            # Reinsert in primary-key order, removing dependence on input ordering.
            stable = sqlite3.connect(Path(temporary) / 'stable.sqlite')
            try:
                stable.executescript(SCHEMA.read_text())
                for table in TABLES:
                    columns = db.execute(f'PRAGMA table_info({table})').fetchall()
                    order = ','.join(c[1] for c in sorted(columns, key=lambda c: c[5]) if c[5])
                    stable.executemany(f'INSERT INTO {table} VALUES ({",".join("?" for _ in columns)})',
                                       db.execute(f'SELECT * FROM {table} ORDER BY {order}'))
                stable.execute('INSERT INTO food_search SELECT code, source, locale, name, aliases FROM food ORDER BY code')
                validate(stable)
                stable.commit()
                stable.execute('VACUUM')
            finally:
                stable.close()
        finally:
            db.close()
        (Path(temporary) / 'stable.sqlite').replace(output)


def merge(paths, output):
    with database(output) as db:
        for path in sorted(map(str, paths)):
            with contextlib.closing(sqlite3.connect(f'file:{Path(path).resolve()}?mode=ro', uri=True)) as source:
                if source.execute('PRAGMA user_version').fetchone()[0] != 2:
                    raise ValidationError('Unsupported source schema')
                for table in TABLES:
                    columns = source.execute(f'PRAGMA table_info({table})').fetchall()
                    db.executemany(f'INSERT INTO {table} VALUES ({",".join("?" for _ in columns)})',
                                   source.execute(f'SELECT * FROM {table}'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', action='append', default=[], type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        merge(args.source, args.output)
    except (ValueError, OSError, sqlite3.Error) as error:
        parser.exit(1, f'Catalogue generation failed: {error}\n')


if __name__ == '__main__':
    main()
