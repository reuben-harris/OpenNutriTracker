import contextlib
import json
import sqlite3
import unittest
import sys
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import catalogue
import updater
from sources.usda import catalogue as usda
from test_food_data import FixtureCase


class ProjectionTest(FixtureCase):
    def test_lossless_records_and_app_selection(self):
        path = self.root / 'projected.sqlite'
        usda.build_database(self.lock, self.paths, path)
        with contextlib.closing(sqlite3.connect(path)) as db:
            data = json.loads(db.execute("SELECT nutrition FROM food WHERE code='usda:100'").fetchone()[0])
            self.assertEqual(data['energyKcal100'], '121')
            self.assertEqual(data['proteins100'], '0.0')
            self.assertIsNone(data['sodium100'])
            original = json.loads(db.execute("SELECT payload FROM source_record WHERE table_name='food_nutrient' AND record_id=?",
                                            ('["foundation",1]',)).fetchone()[0])
            columns = json.loads(db.execute("SELECT columns FROM source_table WHERE source='usda' AND table_name='food_nutrient'").fetchone()[0])
            original = dict(zip(columns, original))
            self.assertEqual(original['standard_error'], '0.00')
            self.assertEqual(json.loads(original['extra_fields']), {'future_metadata': 'retained'})
            self.assertEqual(db.execute('SELECT label, gram_weight FROM food_portion ORDER BY id').fetchall(),
                             [('1 loosely packed', '123.40'), ('2 slices, thin', '50.0'), ('1 cup', '246.0')])
            self.assertEqual(set(data), catalogue.NUTRIENTS)

    def test_energy_fallbacks_and_source_ids(self):
        self.tables['foundation']['tables']['food_nutrient'] = [
            row for row in self.tables['foundation']['tables']['food_nutrient']
            if row[0] not in ('4', '5')]
        self.write_archives()
        path = self.root / 'energy.sqlite'
        usda.build_database(self.lock, self.paths, path)
        with contextlib.closing(sqlite3.connect(path)) as db:
            self.assertEqual(json.loads(db.execute("SELECT nutrition FROM food WHERE code='usda:100'").fetchone()[0])['energyKcal100'], '123.450')
            self.assertEqual(db.execute("SELECT code FROM food WHERE code='usda:300'").fetchone(), ('usda:300',))

    def test_deterministic_merge_and_removal(self):
        first, second = self.root / 'first.sqlite', self.root / 'second.sqlite'
        usda.build_database(self.lock, self.paths, first)
        usda.build_database(self.lock, self.paths, second)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        other = self.root / 'other.sqlite'
        with catalogue.database(other) as db:
            db.execute("INSERT INTO catalogue_source VALUES ('other','Other','{}','Publisher','https://example.org/','https://example.org/',0)")
            db.execute("INSERT INTO food VALUES ('other:100','other','100','en','Crème apple pie','Māori bread','https://example.org/','{}')")
        one, two = self.root / 'one.sqlite', self.root / 'two.sqlite'
        catalogue.merge([first, other], one)
        catalogue.merge([other, first], two)
        self.assertEqual(one.read_bytes(), two.read_bytes())
        with contextlib.closing(sqlite3.connect(one)) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM food WHERE source_id='100'").fetchone()[0], 2)
            self.assertEqual(db.execute("SELECT code FROM food_search WHERE food_search MATCH 'maori'").fetchone()[0], 'other:100')
        catalogue.merge([other], two)
        with contextlib.closing(sqlite3.connect(two)) as db:
            self.assertEqual(db.execute('SELECT id FROM catalogue_source').fetchall(), [('other',)])

    def test_duplicate_sources_fail_without_replacing_output(self):
        source, output = self.root / 'source.sqlite', self.root / 'output.sqlite'
        usda.build_database(self.lock, self.paths, source)
        output.write_bytes(b'keep')
        with self.assertRaises(sqlite3.IntegrityError):
            catalogue.merge([source, source], output)
        self.assertEqual(output.read_bytes(), b'keep')


class UpdateSelectionTest(unittest.TestCase):
    def test_explicit_source_only(self):
        module = Mock()
        module.update.return_value = {'pins_changed': False}
        with patch('sys.argv', ['updater', 'usda']), patch.object(updater.importlib, 'import_module', return_value=module) as load:
            updater.main()
        load.assert_called_once_with('sources.usda.releases')
        module.update.assert_called_once()

    def test_empty_or_unknown_selection_does_not_update(self):
        for arguments in ([], ['unknown'], ['usda', '--all']):
            with self.subTest(arguments=arguments), patch('sys.argv', ['updater', *arguments]), patch.object(updater.importlib, 'import_module') as load:
                with self.assertRaises(SystemExit) as error:
                    updater.main()
                self.assertEqual(error.exception.code, 2)
                load.assert_not_called()
