"""Import the unabridged FOODfiles data without altering published values."""

import argparse
import hashlib
import json
import re
import sqlite3
import subprocess
import tempfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

from catalogue import SourceRecords, canonical, database, decimal_value, sha256, ValidationError

PIN_2024 = 'fad47d11c97814b1d7be5a9d538f0b32cd4807b7d231e516e57c939c75a18a5f'
NAME_ROW_2024 = '5e61d08f1b600aaf48be6c8ebe3d01d13ac0965a0be809c8ff15ea59b6293c98'
TEXT_FILES = ('Names', 'UnabridgedCodes', 'UnabridgedDataFT', 'Csm', 'Ingredients', 'CF', 'NFR', 'YF')
WORKBOOKS = ('ExcelDP', 'ComponentsDeletedFromLatestFOODfiles', 'FoodRecordsReplacingOldFOODRecords',
             'FoodsDeletedFromLatestFOODfiles', 'FoodsUpdatedInLatestFOODfiles')
# Source identifiers select definitions, not merely similarly named components.
MAPPING = {
    'energyKcal100': ('ENERC1_KCAL', 'kcal'),
    'carbohydrates100': ('CHOCDF', 'g'), 'fat100': ('FAT', 'g'), 'proteins100': ('PROT', 'g'),
    'sugars100': ('SUGAR', 'g'), 'saturatedFat100': ('FASAT', 'g'), 'fiber100': ('FIBTG', 'g'),
    'monounsaturatedFat100': ('FAMS', 'g'), 'polyunsaturatedFat100': ('FAPU', 'g'),
    'transFat100': ('FATRN', 'g'), 'cholesterol100': ('CHOLE', 'mg'),
    'sodium100': ('NA', 'mg'), 'potassium100': ('K', 'mg'), 'magnesium100': ('MG', 'mg'),
    'calcium100': ('CA', 'mg'), 'iron100': ('FE', 'mg'), 'zinc100': ('ZN', 'mg'),
    'phosphorus100': ('P', 'mg'), 'vitaminA100': ('VITA_RAE', 'µg'),
    'vitaminC100': ('VITC', 'mg'), 'vitaminD100': ('VITD', 'µg'),
    'vitaminB6100': ('VITB6A', 'mg'), 'vitaminB12100': ('VITB12', 'µg'), 'niacin100': ('NIA', 'mg'),
}
S = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
NS = {'s': S}


def validate_lock(lock):
    if lock.get('lock_version') != 1 or set(lock.get('sources', {})) != {'foodfiles'} or set(lock) != {'lock_version', 'sources'}:
        raise ValidationError('Expected one FOODfiles source and lock_version 1')
    pin = lock['sources']['foodfiles']
    match = re.fullmatch(r'https://www\.foodcomposition\.co\.nz/downloads/foodfiles-(\d{4})-v([1-9][0-9]*)\.msi', pin['url'])
    if (not match or pin['format'] != 'msi' or pin['release'] != f'{match[1]}-v{match[2]}'
            or not re.fullmatch(r'[0-9a-f]{64}', pin['sha256'])):
        raise ValidationError('Expected an official versioned FOODfiles MSI and SHA256')
    return pin


def load_lock(path):
    lock = json.loads(Path(path).read_text())
    validate_lock(lock)
    return lock


def text_rows(directory, member, pin, records, exceptions):
    path = directory / member
    with path.open(encoding='utf-8-sig', newline='') as stream:
        copyright_line = stream.readline().rstrip('\r\n')
        header = stream.readline().rstrip('\r\n').split('~')
        if not copyright_line.startswith('© Copyright') or not header or len(set(header)) != len(header):
            raise ValidationError(f'{member}: missing copyright or invalid header')
        records.record('files', member, {'member': member, 'sha256': sha256(path),
                                       'copyright': copyright_line, 'columns': header})
        for number, line in enumerate(stream, 3):
            original = line.rstrip('\r\n')
            values = original.split('~')
            if len(values) != len(header):
                # The tilde denotes approximation in sampling text. Rejoin only
                # this reviewed row, preserving every character and the raw row.
                if (member == 'Names' and len(header) == 15 and len(values) == 16
                        and values[0] == 'M1144' and pin['sha256'] == PIN_2024
                        and pin['release'] == '2024-v1'
                        and hashlib.sha256(original.encode()).hexdigest() == NAME_ROW_2024):
                    values = [*values[:13], '~'.join(values[13:15]), values[15]]
                    exception = {'member': member, 'line': number, 'food_id': 'M1144',
                                 'original': original, 'reason': 'embedded sampling-text delimiter'}
                    records.record('parsing_exception', 'M1144', exception)
                    exceptions.append(exception)
                else:
                    raise ValidationError(f'{member}: malformed row {number}')
            row = dict(zip(header, values))
            records.record(member, str(number), row)
            yield row


def workbook_records(path, records):
    """Retain supporting spreadsheet cells, including raw numeric spellings.

    These are source records, not a spreadsheet calculation engine. Formulas,
    cell types/styles and stored values remain distinct; no floats or dates are
    inferred. The original archive retains the complete Office documents.
    """
    with ZipFile(path) as archive:
        strings = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            strings = [''.join(t.text or '' for t in item.findall('.//s:t', NS))
                       for item in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('s:si', NS)]
        relationships = {item.attrib['Id']: item.attrib['Target']
                         for item in ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))}
        for sheet in ET.fromstring(archive.read('xl/workbook.xml')).findall('s:sheets/s:sheet', NS):
            target = relationships[sheet.attrib[f'{{{R}}}id']]
            target = target.lstrip('/') if target.startswith('/') else 'xl/' + target
            for row in ET.fromstring(archive.read(target)).findall('s:sheetData/s:row', NS):
                cells = []
                for cell in row.findall('s:c', NS):
                    value, formula = cell.find('s:v', NS), cell.find('s:f', NS)
                    raw = None if value is None else value.text
                    text = strings[int(raw)] if cell.attrib.get('t') == 's' else (
                        ''.join(t.text or '' for t in cell.findall('.//s:t', NS))
                        if cell.attrib.get('t') == 'inlineStr' else raw)
                    cells.append({'attributes': cell.attrib, 'value': text, 'raw_value': raw,
                                  'formula': None if formula is None else formula.text})
                records.record(f'{path.name}/{sheet.attrib["name"]}', row.attrib['r'], {'cells': cells})


def import_files(directory, pin, output, lock):
    counts, exceptions = {}, []
    external_references = Counter()
    with database(output) as db:
        with (directory / 'Names').open(encoding='utf-8-sig') as names_file:
            attribution = names_file.readline().rstrip('\r\n')
        db.execute('INSERT INTO catalogue_source VALUES (?, ?, ?, ?, ?, ?, ?)', (
            'nzfoodfiles', 'NZ FOODfiles', canonical({'foodfiles': pin['release']}),
            attribution + ' New Zealand FOODfiles™ ' + pin['release'] + '.',
            'https://www.foodcomposition.co.nz/foodfiles/', 'https://www.foodcomposition.co.nz/terms/', 1))
        records = SourceRecords(db, 'nzfoodfiles')
        records.record('source_lock', 'lock', {'lock': lock})
        names = {}
        for row in text_rows(directory, 'Names', pin, records, exceptions):
            identity = row['FoodID']
            if not re.fullmatch(r'[A-Z][0-9]{1,5}', identity) or identity in names or not row['Food Name']:
                raise ValidationError(f'Invalid or duplicate FoodID: {identity}')
            names[identity] = row
        codes = {}
        for row in text_rows(directory, 'UnabridgedCodes', pin, records, exceptions):
            if row['Code'] in codes:
                raise ValidationError(f'Duplicate component: {row["Code"]}')
            codes[row['Code']] = row
        for component, unit in MAPPING.values():
            definition = codes.get(component)
            if definition is None or (definition['Unit Code'], definition['Matrix Unit Code']) != (unit, 'W'):
                raise ValidationError(f'Unsupported app component definition: {component}')
        mapped = {component: key for key, (component, _) in MAPPING.items()}
        nutrition = {identity: {} for identity in names}
        seen = set()
        nutrient_count = 0
        for row in text_rows(directory, 'UnabridgedDataFT', pin, records, exceptions):
            identity, component = row['FoodID'], row['Component Identifier']
            key = (identity, component)
            if identity not in names or component not in codes or key in seen:
                raise ValidationError(f'Unresolved or duplicate food component: {key}')
            seen.add(key)
            definition = codes[component]
            if (row['Unit Code'], row['Matrix Unit Code']) != (definition['Unit Code'], definition['Matrix Unit Code']):
                raise ValidationError(f'Component units or basis differ: {key}')
            amount = decimal_value(row['Value'])
            if component in mapped:
                nutrition[identity][mapped[component]] = amount
            nutrient_count += 1
        for identity, row in sorted(names.items()):
            name = row['Short Food Name'] or row['Food Name']
            aliases = ' '.join(filter(None, [row['Food Name'], row['AlternativeNames']]))
            db.execute('INSERT INTO food VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (
                f'nzfoodfiles:{identity}', 'nzfoodfiles', identity, 'en', name, aliases,
                'https://www.foodcomposition.co.nz/foodfiles/', canonical(nutrition[identity])))
        measures = list(text_rows(directory, 'Csm', pin, records, exceptions))
        labels = Counter((row['FoodID'], row['CSM']) for row in measures)
        for position, row in enumerate(measures):
            identity, label = row['FoodID'], row['CSM']
            if identity not in names:
                raise ValidationError(f'Unknown portion food: {identity}')
            weight = decimal_value(row['Measure'])
            if row['Density (g/cm3)']:
                decimal_value(row['Density (g/cm3)'])
            if weight is None or float(weight) <= 0 or not label.strip():
                raise ValidationError(f'Invalid common standard measure: {identity}')
            # Unique labels remain stable when published weights change. Where
            # labels repeat with different weights, retain separate identities.
            basis = label if labels[(identity, label)] == 1 else canonical([label, weight, row['Density (g/cm3)']])
            portion_id = hashlib.sha256(basis.encode()).hexdigest()[:24]
            db.execute('INSERT INTO food_portion VALUES (?, ?, ?, ?, ?)', (
                f'nzfoodfiles:{identity}:{portion_id}', f'nzfoodfiles:{identity}', position, label.strip(), weight))
        for member in ('Ingredients', 'CF', 'NFR', 'YF'):
            rows = list(text_rows(directory, member, pin, records, exceptions))
            for row in rows:
                for field in ('FoodID', 'Recipe FoodID', 'Ingredient FoodID', 'Recipe Food ID'):
                    if field in row and row[field] not in names:
                        external_references[(member, field, row[field])] += 1
            counts[member] = len(rows)
        # Supporting recipe metadata can reference foods absent from this
        # published release. Keep those references verbatim; they are not app
        # catalogue foreign keys and must not be guessed or discarded.
        for (member, field, identity), total in sorted(external_references.items()):
            records.record('external_reference', canonical([member, field, identity]),
                           {'member': member, 'field': field, 'food_id': identity, 'records': total})
        for member in WORKBOOKS:
            workbook_records(directory / member, records)
        counts.update(foods=len(names), components=len(codes), nutrients=nutrient_count, measures=len(measures))
        if not names or not codes or not nutrient_count:
            raise ValidationError('Empty FOODfiles tables')
        if pin['sha256'] == PIN_2024 and {key: counts[key] for key in ('foods', 'components', 'nutrients', 'measures')} != {
                'foods': 2857, 'components': 434, 'nutrients': 571495, 'measures': 3676}:
            raise ValidationError('Pinned FOODfiles 2024 coverage differs from reviewed counts')
    return {'counts': counts, 'external_food_references': [
                {'member': member, 'field': field, 'food_id': identity, 'records': total}
                for (member, field, identity), total in sorted(external_references.items())],
            'parsing_exceptions': [{k: v for k, v in row.items() if k != 'original'} for row in exceptions]}


def build_database(lock, paths, output):
    pin = validate_lock(lock)
    if set(paths) != {'foodfiles'} or sha256(paths['foodfiles']) != pin['sha256']:
        raise ValidationError('FOODfiles archive coverage or SHA256 differs from its pin')
    with tempfile.TemporaryDirectory(prefix='nzfoodfiles-') as temporary:
        directory = Path(temporary)
        subprocess.run(['7zz', 'x', '-y', '-o' + str(directory), str(paths['foodfiles'])],
                       check=True, stdout=subprocess.DEVNULL)
        return import_files(directory, pin, output, lock)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', required=True, type=Path)
    parser.add_argument('--archive', action='append', default=[])
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    paths = {}
    for value in args.archive:
        name, separator, path = value.partition('=')
        if not separator or name in paths:
            parser.error('Each archive must be a unique NAME=PATH')
        paths[name] = Path(path)
    try:
        print(json.dumps(build_database(load_lock(args.lock), paths, args.output), indent=2))
    except (ValueError, OSError, sqlite3.Error, subprocess.CalledProcessError) as error:
        parser.exit(1, f'FOODfiles import failed: {error}\n')


if __name__ == '__main__':
    main()
