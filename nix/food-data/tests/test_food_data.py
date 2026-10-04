import copy
import csv
import io
import json
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import Mock, patch
from zipfile import ZIP_DEFLATED, ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import importer
import updater
import source_fixes

FIXTURE = Path(__file__).with_name("fixtures") / "catalogue.json"


class FixtureCase(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.tables = json.loads(FIXTURE.read_text())
        self.lock = importer.load_lock(Path(importer.__file__).with_name("sources.json"))
        self.lock.pop("auxiliary", None)
        self.paths = {}
        self.fixture_registrations = {}
        self.registration_patch = patch.object(source_fixes, "REGISTRATIONS", self.fixture_registrations)
        self.registration_patch.start()
        self.addCleanup(self.registration_patch.stop)
        self.write_archives()

    def write_archives(self, *, reverse=False):
        for key, fixture in self.tables.items():
            tables = copy.deepcopy(fixture["tables"])
            for name in fixture.get("own_lookups", []):
                tables[name] = copy.deepcopy(self.tables["supporting"]["tables"][name])
            path = self.root / f"{key}.zip"
            with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
                for name, rows in sorted(tables.items(), reverse=reverse):
                    stream = io.StringIO(newline="")
                    writer = csv.writer(stream)
                    writer.writerow(rows[0])
                    writer.writerows(reversed(rows[1:]) if reverse else rows[1:])
                    # Supporting data has no directory; the others do.
                    member = f"{name}.csv" if key == "supporting" else f"usda/{name}.csv"
                    archive.writestr(member, stream.getvalue())
                # Unrelated CSVs must never be parsed or extracted.
                archive.writestr("unused.csv", '"malformed,unrelated\n')
            self.paths[key] = path
            self.lock["sources"][key]["sha256"] = importer.sha256(path)
        pin = self.lock["sources"]["foundation"]
        self.fixture_registrations.clear()
        self.fixture_registrations[("foundation", pin["release"], pin["sha256"])] = {
            "nutrients": {10: 101}, "portion_ids": set(), "unresolved": {}, "auxiliary": (),
        }

    def build(self, name="catalogue.sqlite"):
        path = self.root / name
        result = importer.build_database(self.lock, self.paths, path)
        db = sqlite3.connect(path)
        self.addCleanup(db.close)
        return db, result


class CatalogueTest(FixtureCase):
    def test_contract(self):
        db, result = self.build()
        self.assertEqual(result["foods"], {"foundation": 2, "sr_legacy": 1, "survey": 1})
        self.assertEqual(result["food_nutrients"], 12)
        self.assertEqual(result["import_exceptions"], [{
            "dataset": "foundation",
            "nutrient_id": 2066,
            "reason": "missing nutrient definition with empty amount and metadata",
            "excluded_records": 1,
        }])
        self.assertEqual(json.loads(db.execute(
            "SELECT value FROM metadata WHERE key='import_exceptions'").fetchone()[0]),
            result["import_exceptions"])
        self.assertEqual(db.execute(
            "SELECT total, included, excluded FROM source_count "
            "WHERE dataset='foundation' AND table_name='food_nutrient'").fetchone(), (10, 6, 4))
        self.assertEqual(result["portions"], 4)
        self.assertEqual(db.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(db.execute("PRAGMA integrity_check").fetchall(), [("ok",)])
        self.assertEqual(db.execute("SELECT amount FROM food_nutrient WHERE dataset='foundation' AND id=1").fetchone(), ("0.0",))
        self.assertEqual(db.execute("SELECT amount FROM food_nutrient WHERE dataset='foundation' AND id=6").fetchone(), (None,))
        self.assertEqual(db.execute("SELECT amount FROM food_nutrient WHERE dataset='survey' AND id=31").fetchone(), ("0",))
        energies = db.execute(
            """SELECT n.id, n.unit_name, fn.amount FROM food_nutrient fn JOIN nutrient n
               ON fn.dataset=n.dataset AND fn.nutrient_id=n.id
               WHERE fn.fdc_id=100 AND n.name LIKE 'Energy%' ORDER BY n.id""")
        self.assertEqual(energies.fetchall(), [(1008, "KCAL", "123.450"), (1062, "KJ", "516"), (2047, "KCAL", "120"), (2048, "KCAL", "121")])
        self.assertEqual(db.execute("SELECT nutrient_id, source_nutrient_id FROM food_nutrient WHERE dataset='survey' AND id=32").fetchone(), (1008, "208"))
        self.assertEqual(db.execute("SELECT lookup_source FROM nutrient WHERE dataset='sr_legacy' AND id=1003").fetchone(), ("supporting",))
        self.assertEqual(db.execute("SELECT lookup_source FROM nutrient WHERE dataset='foundation' AND id=1003").fetchone(), ("foundation",))
        self.assertEqual(db.execute("SELECT source_id, lookup_source FROM nutrient_derivation WHERE dataset='foundation' AND id=1").fetchone(), (1, "supporting"))
        self.assertEqual(db.execute("SELECT standard_error, data_points, footnote, extra_fields FROM food_nutrient WHERE dataset='foundation' AND id=1").fetchone(), ("0.00", 2, "Reported zero", '{"future_metadata":"retained"}'))
        self.assertEqual(db.execute("SELECT seq_num, amount, measure_unit_id, portion_description, modifier, gram_weight FROM food_portion WHERE id=11").fetchone(), (2, "1.0", 1000, "loosely packed", "diced", "123.40"))
        self.assertEqual(db.execute("SELECT amount, portion_description, modifier, gram_weight FROM food_portion WHERE id=35").fetchone(), (None, "Quantity not specified", "90000", "0.0"))
        self.assertEqual(db.execute("SELECT category_kind, category_id FROM food WHERE fdc_id=300").fetchone(), ("wweia", 1004))
        self.assertEqual(db.execute("SELECT subtype_fields FROM food WHERE fdc_id=101").fetchone(), ("{}",))
        self.assertEqual(db.execute("SELECT count(*) FROM food_nutrient WHERE fdc_id=101").fetchone(), (0,))
        self.assertEqual(db.execute("SELECT total, included, excluded FROM source_count WHERE dataset='foundation' AND table_name='food'").fetchone(), (7, 2, 5))
        self.assertEqual(json.loads(db.execute("SELECT value FROM metadata WHERE key='source_lock'").fetchone()[0]), self.lock)
        self.assertEqual(db.execute("SELECT value FROM metadata WHERE key='catalogue_fingerprint'").fetchone()[0], importer.fingerprint(db))

    def test_fts(self):
        db, _ = self.build()
        def search(query):
            return [row[0] for row in db.execute("SELECT fdc_id FROM food_search WHERE food_search MATCH ? ORDER BY fdc_id", (query,))]
        self.assertEqual(search("CREME APPLE"), [100])
        self.assertEqual(search("crème apple"), [100])
        self.assertEqual(search("ap* pi*"), [100, 200])
        self.assertEqual(search("app*"), [100, 101, 200, 300])
        self.assertEqual(search("appl*"), [100, 101, 200, 300])
        self.assertEqual(search("without nutrition"), [101])

    def test_byte_determinism_and_stable_order(self):
        _, first = self.build("first.sqlite")
        before = (self.root / "first.sqlite").read_bytes()
        # ZIP headers/order and CSV row ordering change source hashes, so retain
        # the logical pin metadata for the insertion-order comparison below.
        _, second = self.build("second.sqlite")
        self.assertEqual(before, (self.root / "second.sqlite").read_bytes())
        self.assertEqual(first, second)
        self.write_archives(reverse=True)
        db, _ = self.build("reordered.sqlite")
        original = sqlite3.connect(self.root / "first.sqlite")
        self.addCleanup(original.close)
        for table in importer.CATALOGUE_TABLES:
            if table != "source":
                self.assertEqual(original.execute(f"SELECT * FROM {table}").fetchall(), db.execute(f"SELECT * FROM {table}").fetchall())

    def test_documented_food_code_relationship(self):
        self.lock["sources"]["survey"]["food_reference"] = "food_code"
        for table in ("food_nutrient", "food_portion"):
            for row in self.tables["survey"]["tables"][table][1:]:
                row[1] = "11100000"
        self.write_archives()
        db, _ = self.build()
        self.assertEqual(db.execute("SELECT DISTINCT fdc_id FROM food_nutrient WHERE dataset='survey'").fetchall(), [(300,)])

    def test_invalid_references_and_values_fail_without_replacing_output(self):
        scenarios = (
            ("food_nutrient", 1, 2, "99999"),
            ("food_nutrient", 1, 1, "99999"),
            ("food_nutrient", 1, 3, "NaN"),
            ("food_nutrient", 1, 5, "99999"),
            ("food_portion", 1, 4, "99999"),
        )
        original_tables = copy.deepcopy(self.tables)
        for table, row, column, value in scenarios:
            with self.subTest(table=table, column=column):
                self.tables = copy.deepcopy(original_tables)
                self.tables["foundation"]["tables"][table][row][column] = value
                self.write_archives()
                output = self.root / "protected.sqlite"
                output.write_bytes(b"existing output")
                with self.assertRaises((importer.ValidationError, sqlite3.IntegrityError)):
                    importer.build_database(self.lock, self.paths, output)
                self.assertEqual(output.read_bytes(), b"existing output")

    def test_ambiguous_nutrient_number_fails(self):
        self.tables["supporting"]["tables"]["nutrient"].append(["9999", "Duplicate energy", "KCAL", "208", "300"])
        self.write_archives()
        with self.assertRaisesRegex(importer.ValidationError, "ambiguous nutrient number"):
            self.build()

    def test_foundation_2066_with_any_amount_or_metadata_fails(self):
        original_tables = copy.deepcopy(self.tables)
        header = self.tables["foundation"]["tables"]["food_nutrient"][0]
        scenarios = [("amount", value) for value in ("0", "0.0", "1.2")]
        scenarios += [(field, "1") for field in header[4:]]
        for field, value in scenarios:
            with self.subTest(field=field, value=value):
                self.tables = copy.deepcopy(original_tables)
                self.tables["foundation"]["tables"]["food_nutrient"][-1][header.index(field)] = value
                self.write_archives()
                output = self.root / "protected.sqlite"
                output.write_bytes(b"existing output")
                with self.assertRaisesRegex(importer.ValidationError, "unresolved nutrient ID 2066"):
                    importer.build_database(self.lock, self.paths, output)
                self.assertEqual(output.read_bytes(), b"existing output")

    def test_other_empty_unresolved_nutrient_fails(self):
        self.tables["foundation"]["tables"]["food_nutrient"][-1][2] = "2067"
        self.write_archives()
        with self.assertRaisesRegex(importer.ValidationError, "unresolved nutrient ID 2067"):
            self.build()

    def test_2066_exception_does_not_apply_to_other_datasets(self):
        original_tables = copy.deepcopy(self.tables)
        for dataset, food_id in (("sr_legacy", "200"), ("survey", "300")):
            with self.subTest(dataset=dataset):
                self.tables = copy.deepcopy(original_tables)
                self.tables[dataset]["tables"]["food_nutrient"].append(["40", food_id, "2066", "", ""])
                self.write_archives()
                with self.assertRaisesRegex(importer.ValidationError, "unresolved.*2066"):
                    self.build()

    def test_resolved_2066_records_are_preserved(self):
        self.tables["supporting"]["tables"]["nutrient"].append(["2066", "Vitamin A", "MG", "333", "7420"])
        self.write_archives()
        db, result = self.build()
        self.assertEqual(result["food_nutrients"], 13)
        self.assertEqual(result["import_exceptions"], [])
        self.assertEqual(db.execute(
            "SELECT amount FROM food_nutrient WHERE dataset='foundation' AND id=10").fetchone(), (None,))

    def test_resolved_2066_zero_is_preserved(self):
        self.tables['supporting']['tables']['nutrient'].append(
            ['2066', 'Vitamin A', 'MG', '333', '7420'])
        self.tables['foundation']['tables']['food_nutrient'][-1][3] = '0.0'
        self.write_archives()
        db, result = self.build()
        self.assertEqual(result['source_fixes'][0]['skipped_nutrients'], 0)
        self.assertEqual(db.execute(
            "SELECT amount FROM food_nutrient WHERE dataset='foundation' AND id=10").fetchone(), ('0.0',))

    def test_excluded_2066_records_still_require_valid_unique_ids(self):
        original_tables = copy.deepcopy(self.tables)
        for record_id in ("invalid", "1", "10"):
            with self.subTest(record_id=record_id):
                self.tables = copy.deepcopy(original_tables)
                table = self.tables["foundation"]["tables"]["food_nutrient"]
                if record_id == "10":
                    table.append(copy.deepcopy(table[-1]))
                else:
                    table[-1][0] = record_id
                self.write_archives()
                with self.assertRaisesRegex(importer.ValidationError, "Invalid id|duplicate food-nutrient ID"):
                    self.build()

    def test_duplicate_ids_and_hash_mismatch_fail(self):
        self.lock["sources"]["foundation"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(importer.ValidationError, "SHA256 mismatch"):
            self.build()
        self.tables["foundation"]["tables"]["food"].append(self.tables["foundation"]["tables"]["food"][1])
        self.write_archives()
        with self.assertRaisesRegex(importer.ValidationError, "Duplicate fdc_id"):
            self.build()

    def test_duplicate_csv_member_fails(self):
        with ZipFile(self.paths["foundation"], "a") as archive:
            archive.writestr("other/food.csv", "fdc_id\n100\n")
        self.lock["sources"]["foundation"]["sha256"] = importer.sha256(self.paths["foundation"])
        with self.assertRaisesRegex(importer.ValidationError, "Ambiguous CSV member"):
            self.build()


class UpdaterTest(FixtureCase):
    def setUp(self):
        super().setUp()
        self.lock_path = self.root / "nix/food-data/sources.json"
        self.lock_path.parent.mkdir(parents=True)
        self.lock_path.write_text(json.dumps(self.lock, indent=2) + "\n")
        (self.root / "flake.nix").write_text("{}")
        self.flake_path = self.root / "flake.lock"
        self.flake_path.write_text(json.dumps({"version": 7, "root": "root", "nodes": {"food-data": {"locked": {"path": "./nix/food-data"}}, "nixpkgs": {"locked": {"rev": "keep"}}}}))
        self.original = self.lock_path.read_bytes()
        self.original_flake = self.flake_path.read_bytes()
        self.refresher = Mock()
        self.html = "".join(f'<a href="{pin["url"]}">CSV</a>' for pin in self.lock["sources"].values())

    def downloaded_fixture(self, url, output):
        key = next(key for key, pin in self.lock["sources"].items() if pin["url"] == url)
        shutil.copyfile(self.paths[key], output)

    def update(self, downloader=None, progress=None):
        return updater.update(self.root, index_fetcher=lambda: self.html,
                              downloader=downloader or self.downloaded_fixture,
                              refresher=self.refresher, progress=progress)

    def assert_unchanged(self):
        self.assertEqual(self.lock_path.read_bytes(), self.original)
        self.assertEqual(self.flake_path.read_bytes(), self.original_flake)

    def test_unchanged_releases(self):
        result = self.update()
        self.assertFalse(result["pins_changed"])
        self.assertEqual(result["foods"]["foundation"], 2)
        self.assertEqual(result["import_exceptions"][0]["excluded_records"], 1)
        self.refresher.assert_not_called()
        self.assert_unchanged()

    def test_download_failure(self):
        with self.assertRaises(OSError):
            self.update(downloader=Mock(side_effect=OSError("download failed")))
        self.assert_unchanged()
        self.refresher.assert_not_called()

    def test_download_cancellation_preserves_locks_and_cleans_candidates(self):
        progress = Mock()
        with self.assertRaises(KeyboardInterrupt):
            self.update(downloader=Mock(side_effect=KeyboardInterrupt), progress=progress)
        self.assert_unchanged()
        self.refresher.assert_not_called()
        self.assertEqual(list((self.root / ".nix-cache/food-data").iterdir()), [])
        self.assertIn("Downloading foundation", progress.call_args.args[0])

    def test_progress_reports_stages_and_source_releases(self):
        progress = Mock()
        self.update(progress=progress)
        messages = [call.args[0] for call in progress.call_args_list]
        self.assertIn("release index", messages[0])
        for key, pin in self.lock["sources"].items():
            self.assertIn(f"Downloading {key} {pin['release']}...", messages)
        self.assertIn("Generating and validating the candidate catalogue...", messages)
        self.assertIn("source pins are unchanged", messages[-1])

    def test_cli_cancellation_exits_without_traceback(self):
        stderr = io.StringIO()
        with patch.object(sys, "argv", ["updater.py", "--root", str(self.root)]), \
                patch.object(updater, "update", side_effect=KeyboardInterrupt), \
                redirect_stderr(stderr), self.assertRaises(SystemExit) as exit_result:
            updater.main()
        self.assertEqual(exit_result.exception.code, 130)
        self.assertEqual(stderr.getvalue(), "Food-data update cancelled.\n")

    def test_cli_progress_keeps_stdout_json(self):
        stdout = io.StringIO()
        stderr = io.StringIO()
        run_update = updater.update
        def fixture_update(root, *, progress):
            return run_update(root, index_fetcher=lambda: self.html,
                              downloader=self.downloaded_fixture,
                              refresher=self.refresher, progress=progress)
        with patch.object(sys, "argv", ["updater.py", "--root", str(self.root)]), \
                patch.object(updater, "update", side_effect=fixture_update), \
                redirect_stderr(stderr), redirect_stdout(stdout):
            updater.main()
        self.assertFalse(json.loads(stdout.getvalue())["pins_changed"])
        self.assertIn("Downloading foundation", stderr.getvalue())
        self.assertNotIn("Downloading", stdout.getvalue())

    def test_invalid_candidate(self):
        self.tables["foundation"]["tables"]["food_nutrient"][1][2] = "2066"
        self.write_archives()
        with self.assertRaisesRegex(importer.ValidationError, "unresolved nutrient ID"):
            self.update()
        self.assert_unchanged()
        self.refresher.assert_not_called()

    def changed_candidate(self):
        self.tables["foundation"]["tables"]["food"][1][2] = "Updated apple pie"
        self.write_archives()

    def test_valid_changed_candidate(self):
        self.changed_candidate()
        result = self.update()
        self.assertTrue(result["pins_changed"])
        self.assertEqual(importer.load_lock(self.lock_path), self.lock)
        self.refresher.assert_called_once_with(self.root)
        self.assertEqual(self.flake_path.read_bytes(), self.original_flake)

    def test_refresh_failure_rolls_back_both_locks(self):
        self.changed_candidate()
        def fail(root):
            self.flake_path.write_text("broken lock")
            raise subprocess.CalledProcessError(1, ["nix", "flake", "update", "food-data"])
        self.refresher.side_effect = fail
        with self.assertRaises(subprocess.CalledProcessError):
            self.update()
        self.assert_unchanged()

    def test_refresh_cancellation_rolls_back_both_locks(self):
        self.changed_candidate()
        def cancel(root):
            self.flake_path.write_text("interrupted refresh")
            raise KeyboardInterrupt
        self.refresher.side_effect = cancel
        with self.assertRaises(KeyboardInterrupt):
            self.update()
        self.assert_unchanged()

    def test_unrelated_flake_update_rolls_back(self):
        self.changed_candidate()
        def wrong_update(root):
            lock = json.loads(self.flake_path.read_text())
            lock["nodes"]["nixpkgs"]["locked"]["rev"] = "changed"
            self.flake_path.write_text(json.dumps(lock))
        self.refresher.side_effect = wrong_update
        with self.assertRaisesRegex(importer.ValidationError, "other than food-data"):
            self.update()
        self.assert_unchanged()

    def test_discovery_is_official_and_selects_latest(self):
        html = self.html + '<a href="/fdc-datasets/FoodData_Central_foundation_food_csv_2027-04-30.zip">new</a>'
        html += '<a href="https://example.com/fdc-datasets/FoodData_Central_foundation_food_csv_2099-04-30.zip">unofficial</a>'
        html += '<a href="/fdc-datasets/FoodData_Central_foundation_food_json_2099-04-30.zip">JSON</a>'
        self.assertEqual(updater.discover(html)["foundation"]["release"], "2027-04-30")
        with self.assertRaisesRegex(importer.ValidationError, "no CSV release"):
            updater.discover("<html>unavailable</html>")

class SourceFixTest(FixtureCase):
    def setUp(self):
        super().setUp()
        self.fix = next(iter(self.fixture_registrations.values()))
        self.fix.update(portion_ids={312552, 312553, 312565, 312629, 312635, 312725, 312747},
                        unresolved={312565: '114.0', 312629: '30.0', 312635: '30.0',
                                    312725: '85.0', 312747: '125.0'},
                        auxiliary=('test_april', 'test_december'))
        self.auxiliary_patch = patch.dict(source_fixes.AUXILIARY, {}, clear=True)
        self.auxiliary_patch.start()
        self.addCleanup(self.auxiliary_patch.stop)
        self.documents = {
            'test_april': {'FoundationFoods': [None, self.food(312552)]},
            'test_december': {'FoundationFoods': [self.food(312552), self.food(312553)]},
        }
        self.write_json()

    @staticmethod
    def food(identity):
        return {'fdcId': 100, 'foodPortions': [{'id': identity, 'amount': 1.0,
                'gramWeight': 30.0, 'sequenceNumber': 1, 'measureUnit': {'id': 1000}}]}

    def write_json(self):
        for name, document in self.documents.items():
            path = self.root / f'{name}.zip'
            with ZipFile(path, 'w') as archive:
                archive.writestr('foundation.json', json.dumps(document))
            source_fixes.AUXILIARY[name] = {
                'release': '2026-04-30', 'format': 'json.zip',
                'url': f'https://fdc.nal.usda.gov/fdc-datasets/{name}.zip',
                'sha256': importer.sha256(path),
            }
            self.paths[name] = path
        self.lock['auxiliary'] = source_fixes.required_auxiliary(self.lock)

    def fixes(self):
        return source_fixes.SourceFixes('foundation', self.lock['sources']['foundation'],
                                      self.paths, importer.ValidationError)

    @staticmethod
    def portion(identity=312552, **fields):
        return dict(id=str(identity), fdc_id='', measure_unit_id='', amount='1.0',
                    gram_weight='30.0', seq_num='1', modifier='keep', **fields)

    def test_repair_preserves_csv_and_provenance(self):
        fixes = self.fixes()
        row = self.portion()
        repaired = fixes.portion(row, {100}, {1000})
        self.assertEqual(row['fdc_id'], '')
        self.assertEqual(repaired, {**row, 'fdc_id': '100', 'measure_unit_id': '1000'})
        self.assertEqual(fixes.summary()['repairs'], [{
            'id': 312552, 'filled': {'fdc_id': 100, 'measure_unit_id': 1000},
            'auxiliary_sources': ['test_april', 'test_december']}])
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            fixes.log()
        self.assertIn('foundation', stderr.getvalue())
        self.assertIn('Repaired 1 portion records', stderr.getvalue())

    def test_quantity_conflicts_missing_targets_and_partial_ids(self):
        for field, value, pattern in (
            ('amount', '2', 'quantity mismatch'), ('gram_weight', '31', 'quantity mismatch'),
            ('seq_num', '2', 'quantity mismatch'), ('fdc_id', '101', 'Conflicting CSV'),
            ('measure_unit_id', '1001', 'Conflicting CSV'),
        ):
            with self.subTest(field=field):
                row = self.portion()
                row[field] = value
                with self.assertRaisesRegex(importer.ValidationError, pattern):
                    self.fixes().portion(row, {100}, {1000})
        for foods, units in ((set(), {1000}), ({100}, set())):
            with self.assertRaisesRegex(importer.ValidationError, 'Unresolved JSON'):
                self.fixes().portion(self.portion(), foods, units)
        row = self.portion()
        row['fdc_id'] = '100'
        self.assertEqual(self.fixes().portion(row, {100}, {1000})['fdc_id'], '100')

    def test_json_conflicts_and_missing_evidence(self):
        self.documents['test_april']['FoundationFoods'][1]['fdcId'] = 101
        self.write_json()
        with self.assertRaisesRegex(importer.ValidationError, 'Conflicting JSON'):
            self.fixes()
        self.documents['test_april']['FoundationFoods'] = []
        self.documents['test_december']['FoundationFoods'].pop()
        self.write_json()
        with self.assertRaisesRegex(importer.ValidationError, 'targets differ'):
            self.fixes()

    def test_exact_five_skips_and_guards(self):
        fixes = self.fixes()
        for identity, weight in self.fix['unresolved'].items():
            row = self.portion(identity)
            row['gram_weight'] = weight
            self.assertIsNone(fixes.portion(row, {100}, {1000}))
            for field, value in (('fdc_id', '100'), ('amount', '0'), ('gram_weight', '999'),
                                 ('seq_num', '2'), ('measure_unit_id', '1000')):
                changed = {**row, field: value}
                with self.assertRaisesRegex(importer.ValidationError, 'Unexpected unresolved'):
                    fixes.portion(changed, {100}, {1000})
        self.assertEqual(fixes.summary()['skipped_portions'], 5)
        unknown = self.portion(999)
        self.assertEqual(fixes.portion(unknown, {100}, {1000}), unknown)

    def test_database_repairs_skips_provenance_and_duplicate_ids(self):
        table = self.tables['foundation']['tables']['food_portion']
        header = table[0]
        originals = []
        for identity in sorted(self.fix['portion_ids']):
            row = {key: '' for key in header}
            row.update(self.portion(identity))
            if identity in self.fix['unresolved']:
                row['gram_weight'] = self.fix['unresolved'][identity]
            originals.append([row.get(key, '') for key in header])
        table.extend(originals)
        config = copy.deepcopy(self.fix)
        self.write_archives()
        next(iter(self.fixture_registrations.values())).update(config)
        self.write_json()
        db, result = self.build()
        summary = result['source_fixes'][0]
        self.assertEqual((summary['repaired_portions'], summary['skipped_portions']), (2, 5))
        self.assertEqual(result['portions'], 6)
        self.assertEqual(json.loads(db.execute(
            "SELECT value FROM metadata WHERE key='source_fixes'").fetchone()[0]),
            result['source_fixes'])
        self.assertEqual(db.execute(
            "SELECT fdc_id, measure_unit_id, amount, gram_weight, modifier "
            "FROM food_portion WHERE id=312552").fetchone(), (100, 1000, '1.0', '30.0', 'keep'))
        self.assertEqual(db.execute(
            "SELECT total, included, excluded FROM source_count "
            "WHERE dataset='foundation' AND table_name='food_portion'").fetchone(), (9, 3, 6))
        table.append(originals[-1])
        self.write_archives()
        next(iter(self.fixture_registrations.values())).update(config)
        self.write_json()
        with self.assertRaisesRegex(importer.ValidationError, 'duplicate food-portion ID'):
            self.build('duplicate.sqlite')

    def test_unexpected_missing_food_fails(self):
        table = self.tables['foundation']['tables']['food_portion']
        table[1][table[0].index('fdc_id')] = ''
        config = copy.deepcopy(self.fix)
        self.write_archives()
        next(iter(self.fixture_registrations.values())).update(config)
        self.write_json()
        with self.assertRaisesRegex(importer.ValidationError, 'Invalid fdc_id'):
            self.build()

    def test_auxiliary_hash_and_contract_failures(self):
        self.paths['test_april'].write_bytes(b'corrupt')
        with self.assertRaisesRegex(importer.ValidationError, 'SHA256 mismatch'):
            self.build()
        self.lock['auxiliary']['test_april']['sha256'] = '0' * 64
        with self.assertRaisesRegex(importer.ValidationError, 'Auxiliary pins differ'):
            self.build()

    def test_auxiliary_failure_keeps_updater_locks(self):
        lock_path = self.root / 'nix/food-data/sources.json'
        lock_path.parent.mkdir(parents=True)
        original = json.dumps(self.lock).encode()
        lock_path.write_bytes(original)
        (self.root / 'flake.nix').write_text('{}')
        flake = self.root / 'flake.lock'
        flake.write_bytes(b'{}')
        html = ''.join(f'<a href="{pin["url"]}">CSV</a>' for pin in self.lock['sources'].values())
        def download(url, destination):
            if 'test_' in url:
                raise OSError('auxiliary unavailable')
            key = next(key for key, pin in self.lock['sources'].items() if pin['url'] == url)
            shutil.copyfile(self.paths[key], destination)
        with self.assertRaisesRegex(OSError, 'auxiliary unavailable'):
            updater.update(self.root, index_fetcher=lambda: html, downloader=download)
        self.assertEqual(lock_path.read_bytes(), original)
        self.assertEqual(flake.read_bytes(), b'{}')


class PinSelectionTest(FixtureCase):
    def test_unknown_release_hash_and_record_receive_no_exception(self):
        for change in ('release', 'hash', 'record'):
            with self.subTest(change=change):
                pin = copy.deepcopy(self.lock['sources']['foundation'])
                if change == 'release':
                    pin['release'] = '2099-04-30'
                elif change == 'hash':
                    pin['sha256'] = '0' * 64
                row = {'id': '10' if change != 'record' else '999', 'fdc_id': '101',
                       'nutrient_id': '2066', 'amount': ''}
                fixes = source_fixes.SourceFixes('foundation', pin, {}, importer.ValidationError)
                self.assertFalse(fixes.skip_nutrient(row))

    def test_build_cli_stdout_and_stderr(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        args = ['importer.py', '--lock', str(self.root / 'lock.json'),
                '--output', str(self.root / 'out.sqlite')]
        (self.root / 'lock.json').write_text(json.dumps(self.lock))
        for key, path in self.paths.items():
            args.extend(['--archive', f'{key}={path}'])
        with patch.object(sys, 'argv', args), redirect_stdout(stdout), redirect_stderr(stderr):
            importer.main()
        self.assertEqual(json.loads(stdout.getvalue())['source_fixes'][0]['skipped_nutrients'], 1)
        self.assertIn('Skipped 1 empty nutrient records', stderr.getvalue())
        self.assertIn('Skipped 0 portion records', stderr.getvalue())

    def test_new_pin_retires_auxiliary(self):
        lock = copy.deepcopy(self.lock)
        lock['sources']['foundation']['sha256'] = '0' * 64
        self.assertEqual(source_fixes.required_auxiliary(lock), {})


if __name__ == "__main__":
    unittest.main()
