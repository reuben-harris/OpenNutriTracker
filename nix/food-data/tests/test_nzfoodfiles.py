import contextlib
import copy
import hashlib
import io
import json
import shutil
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
from zipfile import ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from catalogue import SourceRecords, ValidationError, canonical, database
from sources.nzfoodfiles import importer, releases


class NZTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.files = self.root / 'files'
        self.files.mkdir()
        self.lock = importer.load_lock(Path(importer.__file__).with_name('sources.json'))
        self.lock['sources']['foodfiles']['sha256'] = hashlib.sha256(b'fixture').hexdigest()
        self.pin = self.lock['sources']['foodfiles']
        self.output = self.root / 'catalogue.sqlite'
        self.write('Names', ['FoodID', 'Food Name', 'Short Food Name', 'AlternativeNames', 'Sampling Details'],
                   [['Q1', 'Kūmara, boiled, composite', 'Kūmara, boiled', 'Sweet potato, Māori food', 'Unchanged sampling text']])
        definitions = [(code, code, unit, 'W') for code, unit in importer.MAPPING.values()]
        definitions += [('VITA', 'Retinol equivalents', 'µg', 'W'), ('FASATF', 'Fatty acids per total fat', 'g', 'F'),
                        ('CHOAVL', 'Available carbohydrate', 'g', 'W'), ('ENERC_KCAL', 'Energy excluding fibre', 'kcal', 'W')]
        self.write('UnabridgedCodes', ['Code', 'Description', 'Unit Code', 'Matrix Unit Code'], definitions)
        self.nutrients = [
            ['Q1', 'ENERC1_KCAL', '201.2300', 'kcal', 'W', 'source', 'BE', 'D', 'A', 'method'],
            ['Q1', 'ENERC_KCAL', '190', 'kcal', 'W', '', '', '', '', ''],
            ['Q1', 'CHOCDF', '9.0001', 'g', 'W', '', '', '', '', ''],
            ['Q1', 'CHOAVL', '7', 'g', 'W', '', '', '', '', ''],
            ['Q1', 'NA', '0.00', 'mg', 'W', '', 'LZ', '', '', ''],
            ['Q1', 'VITC', '', 'mg', 'W', '', '', '', '', ''],
            ['Q1', 'VITA_RAE', '90.00', 'µg', 'W', '', '', '', '', ''],
            ['Q1', 'VITA', '999', 'µg', 'W', '', '', '', '', ''],
            ['Q1', 'FASATF', '0', 'g', 'F', 'reference', 'TR', '', '', ''],
        ]
        self.write_nutrients()
        self.write('Csm', ['FoodID', 'Food Name', 'CSM', 'Measure', 'Density (g/cm3)'], [
            ['Q1', 'Kūmara', '1 cup', '200', '0.8'], ['Q1', 'Kūmara', '1 cup', '215', '0.86'],
            ['Q1', 'Kūmara', '1 slice', '55.00', '0.9']])
        self.write('Ingredients', ['Recipe FoodID', 'Ingredient FoodID', 'Weight Fraction(%)'], [['Q1', 'M99999', '100']])
        self.write('CF', ['FoodID', 'XFA', 'XN'], [['Q1', '0.9560', '6.25']])
        self.write('NFR', ['Component Identifier', 'Nutrient Retention Factor'], [['VITC', '0.50']])
        self.write('YF', ['Recipe Food ID', 'Weight Yield Factor'], [['Q1', '1.2300']])
        for member in importer.WORKBOOKS:
            with ZipFile(self.files / member, 'w') as archive:
                archive.writestr('xl/sharedStrings.xml', f'<sst xmlns="{importer.S}"><si><t>Unaltered source text</t></si></sst>')
                archive.writestr('xl/workbook.xml', f'<workbook xmlns="{importer.S}" xmlns:r="{importer.R}"><sheets><sheet name="Data" sheetId="1" r:id="rId1"/></sheets></workbook>')
                archive.writestr('xl/_rels/workbook.xml.rels', '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>')
                archive.writestr('xl/worksheets/sheet1.xml', f'<worksheet xmlns="{importer.S}"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" s="1"><f>1+0.23</f><v>1.2300</v></c></row></sheetData></worksheet>')

    def write(self, member, columns, rows):
        (self.files / member).write_text('© Copyright Fixture publisher, 2024.\n' + '~'.join(columns) + '\n' +
                                        ''.join('~'.join(row) + '\n' for row in rows))

    def write_nutrients(self):
        self.write('UnabridgedDataFT', ['FoodID', 'Component Identifier', 'Value', 'Unit Code', 'Matrix Unit Code',
                   'Source Code', 'Value Type Code', 'Acquisition Type Code', 'Method Type Code', 'Method Indicator Code'], self.nutrients)

    def build(self):
        result = importer.import_files(self.files, self.pin, self.output, self.lock)
        db = sqlite3.connect(self.output)
        self.addCleanup(db.close)
        return db, result

    def records(self, db, table):
        columns = json.loads(db.execute('SELECT columns FROM source_table WHERE source=? AND table_name=?', ('nzfoodfiles', table)).fetchone()[0])
        return [dict(zip(columns, json.loads(row[0]))) for row in db.execute('SELECT payload FROM source_record WHERE table_name=? ORDER BY record_id', (table,))]

    def test_full_records_and_explicit_nutrition_definitions(self):
        db, result = self.build()
        food = db.execute('SELECT code, name, nutrition FROM food').fetchone()
        self.assertEqual(food[:2], ('nzfoodfiles:Q1', 'Kūmara, boiled'))
        values = json.loads(food[2])
        self.assertEqual(values['energyKcal100'], '201.2300')
        self.assertEqual(values['carbohydrates100'], '9.0001')
        self.assertEqual(values['sodium100'], '0.00')
        self.assertEqual(values['vitaminA100'], '90.00')
        self.assertIsNone(values['vitaminC100'])
        self.assertEqual(db.execute("SELECT code FROM food_search WHERE food_search MATCH 'maori'").fetchone()[0], 'nzfoodfiles:Q1')
        raw = {row['Component Identifier']: row for row in self.records(db, 'UnabridgedDataFT')}
        self.assertEqual(raw['ENERC1_KCAL']['Value'], '201.2300')
        self.assertEqual(raw['FASATF']['Matrix Unit Code'], 'F')
        self.assertEqual(raw['FASATF']['Value Type Code'], 'TR')
        self.assertEqual(self.records(db, 'CF')[0]['XFA'], '0.9560')
        self.assertEqual(result['external_food_references'], [{'member': 'Ingredients', 'field': 'Ingredient FoodID', 'food_id': 'M99999', 'records': 1}])
        self.assertEqual(self.records(db, 'Ingredients')[0]['Ingredient FoodID'], 'M99999')
        cells = self.records(db, 'ExcelDP/Data')[0]['cells']
        self.assertEqual(cells[0]['value'], 'Unaltered source text')
        self.assertEqual(cells[1]['raw_value'], '1.2300')
        self.assertEqual(cells[1]['formula'], '1+0.23')

    def test_expanded_nutrients_keep_units_precision_and_source_values(self):
        self.nutrients += [
            ['Q1', 'MN', '1234.5000', 'µg', 'W', '', '', '', '', ''],
            ['Q1', 'FOLDFE', '123.4500', 'µg', 'W', '', '', '', '', ''],
            ['Q1', 'TOCPHA', '0.00100', 'mg', 'W', '', '', '', '', ''],
            ['Q1', 'FAPUN3', '0', 'g', 'W', '', 'TR', '', '', ''],
        ]
        self.write_nutrients()
        db, _ = self.build()
        values = json.loads(db.execute('SELECT nutrition FROM food').fetchone()[0])
        self.assertEqual(values['manganese100'], '1.2345')
        self.assertEqual(values['folateDfe100'], '123.4500')
        self.assertEqual(values['vitaminE100'], '0.00100')
        self.assertEqual(values['omega3100']['qualification'], 'trace')
        self.assertNotIn('vitaminK1100', values)
        raw = {r['Component Identifier']: r for r in self.records(db, 'UnabridgedDataFT')}
        self.assertEqual(raw['MN']['Value'], '1234.5000')
        self.assertEqual(raw['MN']['Unit Code'], 'µg')

    def test_amino_acids_use_food_weight_basis_and_preserve_source_profiles(self):
        with (self.files / 'UnabridgedCodes').open('a') as stream:
            stream.write('HISN~Histidine per nitrogen~mg~N\n')
        self.nutrients += [
            ['Q1', 'HIS_G', '0.0012300', 'g', 'W', '', '', '', '', ''],
            ['Q1', 'HISN', '999.99', 'mg', 'N', '', '', '', '', ''],
            ['Q1', 'CYS_G', '0.00', 'g', 'W', '', '', '', '', ''],
        ]
        self.write_nutrients()
        db, _ = self.build()
        values = json.loads(db.execute('SELECT nutrition FROM food').fetchone()[0])
        self.assertEqual(values['histidine100'], '0.0012300')
        self.assertEqual(values['cystine100'], '0.00')
        self.assertNotIn('cysteine100', values)
        self.assertNotIn('glutamine100', values)
        raw = {r['Component Identifier']: r for r in self.records(db, 'UnabridgedDataFT')}
        self.assertEqual(raw['HISN']['Value'], '999.99')
        self.assertEqual(raw['HISN']['Matrix Unit Code'], 'N')

    def test_qualifications_without_invented_limits(self):
        for code, qualification in [('TR', 'trace'), ('BL', 'belowDetection'),
                                    ('BLX', 'belowDetectionOrQuantification'), ('BQ', 'belowQuantification')]:
            self.assertEqual(importer.project_amount('0.0000', code),
                             {'value': '0' if code == 'TR' else '0.0000',
                              'qualification': qualification, 'limit': None})
        for code in ['LZ', 'BE', 'AV', 'W']:
            self.assertEqual(importer.project_amount('0.00100', code), '0.00100')
        self.nutrients.append(['Q1', 'VITB12', '0', 'µg', 'W', '', 'TR', '', '', ''])
        self.write_nutrients()
        db, _ = self.build()
        values = json.loads(db.execute('SELECT nutrition FROM food').fetchone()[0])
        self.assertEqual(values['vitaminB12100']['qualification'], 'trace')
        self.assertEqual(values['sodium100'], '0.00')

    def test_duplicate_measure_labels_remain_distinct_and_unique_labels_keep_identity(self):
        db, _ = self.build()
        rows = db.execute('SELECT id, label, gram_weight FROM food_portion ORDER BY position').fetchall()
        self.assertEqual([r[2] for r in rows], ['200', '215', '55.00'])
        self.assertNotEqual(rows[0][0], rows[1][0])
        (self.files / 'Csm').write_text((self.files / 'Csm').read_text().replace('55.00', '56.00'))
        db.close()
        changed, _ = self.build()
        self.assertEqual(changed.execute("SELECT id FROM food_portion WHERE label='1 slice'").fetchone()[0], rows[2][0])

    def test_determinism(self):
        db, _ = self.build()
        before = self.output.read_bytes()
        db.close()
        self.build()
        self.assertEqual(self.output.read_bytes(), before)

    def test_wrong_units_and_duplicate_components_fail_without_publishing(self):
        self.output.write_bytes(b'keep')
        self.nutrients[4][3] = 'g'
        self.write_nutrients()
        with self.assertRaisesRegex(ValidationError, 'units or basis differ'):
            self.build()
        self.assertEqual(self.output.read_bytes(), b'keep')
        self.nutrients[4][3] = 'mg'
        self.nutrients.append(self.nutrients[0])
        self.write_nutrients()
        with self.assertRaisesRegex(ValidationError, 'duplicate food component'):
            self.build()
        self.assertEqual(self.output.read_bytes(), b'keep')

    def test_exact_pin_sampling_delimiter_rule_is_lossless_and_does_not_carry_forward(self):
        fixture = Path(__file__).with_name('fixtures') / 'nzfoodfiles_m1144.txt'
        shutil.copyfile(fixture, self.files / 'Names')
        pin = {**self.pin, 'sha256': importer.PIN_2024}
        with database(self.output) as db:
            db.execute("INSERT INTO catalogue_source VALUES ('nzfoodfiles','Fixture','{}','Publisher','https://example.org/','https://example.org/',0)")
            records = SourceRecords(db, 'nzfoodfiles')
            exceptions = []
            rows = list(importer.text_rows(self.files, 'Names', pin, records, exceptions))
            self.assertIn('(~15 mm)', rows[0]['Sampling Details'])
            self.assertEqual(rows[0]['Component Message'], 'Sampled January-July 2010.')
            self.assertEqual(exceptions[0]['original'], fixture.read_text().splitlines()[2])
            db.execute("INSERT INTO food VALUES ('nzfoodfiles:M1144','nzfoodfiles','M1144','en','Fixture','','https://example.org/','{}')")
        before = self.output.read_bytes()
        for changed in ({'sha256': '0' * 64}, {'release': '2024-v2'}):
            with self.subTest(changed=changed), self.assertRaisesRegex(ValidationError, 'malformed row'):
                with database(self.output) as db:
                    db.execute("INSERT INTO catalogue_source VALUES ('nzfoodfiles','Fixture','{}','Publisher','https://example.org/','https://example.org/',0)")
                    list(importer.text_rows(self.files, 'Names', {**pin, **changed}, SourceRecords(db, 'nzfoodfiles'), []))
            self.assertEqual(self.output.read_bytes(), before)

    def test_hash_validation_precedes_extraction(self):
        archive = self.root / 'fixture.msi'
        archive.write_bytes(b'wrong')
        with patch.object(importer.subprocess, 'run') as extract:
            with self.assertRaisesRegex(ValidationError, 'SHA256'):
                importer.build_database(self.lock, {'foodfiles': archive}, self.output)
            extract.assert_not_called()


class NZUpdateTest(unittest.TestCase):
    def test_discovery_ignores_web_only_releases_and_unofficial_urls(self):
        html = '''2026 online search. <a href="/downloads/foodfiles-2024-v1.msi">latest</a>
        <a href="/downloads/foodfiles-2021-v1.msi">archive</a>
        <a href="https://example.org/downloads/foodfiles-2099-v1.msi">fake</a>'''
        self.assertEqual(releases.discover(html)['release'], '2024-v1')
        self.assertEqual(releases.discover(html + '<a href="/downloads/foodfiles-2024-v2.msi">new</a>')['release'], '2024-v2')
        with self.assertRaisesRegex(ValidationError, 'no bulk MSI'):
            releases.discover('2026 online search')

    def test_failed_candidate_retains_both_locks_and_other_database(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lock_path = root / 'nix/food-data/sources/nzfoodfiles/sources.json'
            lock_path.parent.mkdir(parents=True)
            lock_path.write_bytes(Path(importer.__file__).with_name('sources.json').read_bytes())
            (root / 'flake.nix').write_text('{}')
            flake = root / 'flake.lock'
            flake.write_text('{"nodes":{"food-data":{},"nixpkgs":{"rev":"keep"}}}')
            other = root / 'nix/food-data/sources/usda/sources.json'
            other.parent.mkdir()
            other.write_bytes(b'keep USDA')
            before, before_flake = lock_path.read_bytes(), flake.read_bytes()
            refresher = Mock()
            html = '<a href="/downloads/foodfiles-2025-v1.msi">new</a>'
            downloader = lambda url, output: output.write_bytes(b'candidate')
            with patch.object(releases, 'build_database', side_effect=ValidationError('candidate rejected')):
                with self.assertRaisesRegex(ValidationError, 'candidate rejected'):
                    releases.update(root, index_fetcher=lambda: html, downloader=downloader, refresher=refresher)
            self.assertEqual(lock_path.read_bytes(), before)
            self.assertEqual(flake.read_bytes(), before_flake)
            self.assertEqual(other.read_bytes(), b'keep USDA')
            refresher.assert_not_called()
            with patch.object(releases, 'build_database', return_value={'counts': {}}):
                self.assertTrue(releases.update(root, index_fetcher=lambda: html, downloader=downloader, refresher=refresher)['pins_changed'])
            self.assertEqual(json.loads(lock_path.read_text())['sources']['foodfiles']['release'], '2025-v1')
            self.assertEqual(other.read_bytes(), b'keep USDA')
            def fail_refresh(_):
                flake.write_text('interrupted')
                raise RuntimeError('refresh failed')
            with patch.object(releases, 'build_database', return_value={'counts': {}}):
                with self.assertRaisesRegex(RuntimeError, 'refresh failed'):
                    releases.update(root, index_fetcher=lambda: html.replace('2025', '2026'), downloader=downloader, refresher=fail_refresh)
            self.assertEqual(json.loads(lock_path.read_text())['sources']['foodfiles']['release'], '2025-v1')
            self.assertEqual(flake.read_bytes(), before_flake)
            self.assertEqual(other.read_bytes(), b'keep USDA')
