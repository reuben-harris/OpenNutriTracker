"""Build a food-level catalogue from pinned USDA CSV ZIP archives."""

import argparse
import contextlib
import csv
import hashlib
import io
import json
import re
import sqlite3
import tempfile
from decimal import Decimal, InvalidOperation
from pathlib import Path
from urllib.parse import urlparse
from zipfile import BadZipFile, ZipFile

from source_fixes import SourceFixes, required_auxiliary

SCHEMA_VERSION = 1
DATASETS = {
    "foundation": "foundation_food",
    "sr_legacy": "sr_legacy_food",
    "survey": "survey_fndds_food",
}
CATALOGUE_TABLES = (
    "source", "category", "nutrient", "nutrient_source", "nutrient_derivation",
    "measure_unit", "food", "food_name", "food_nutrient", "food_portion", "source_count",
)


class ValidationError(ValueError):
    pass


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_lock(path):
    lock = json.loads(Path(path).read_text(encoding="utf-8"))
    validate_lock(lock)
    return lock


def validate_lock(lock):
    if lock.get("lock_version") != 1 or set(lock.get("sources", {})) != {*DATASETS, "supporting"}:
        raise ValidationError("Expected lock_version 1 and the three datasets plus supporting")
    auxiliary = lock.get("auxiliary", {})
    if auxiliary != required_auxiliary(lock):
        raise ValidationError("Auxiliary pins differ from exact-pin repair requirements")
    for key, pin in {**lock["sources"], **auxiliary}.items():
        url = urlparse(pin["url"])
        if (url.scheme != "https" or url.netloc != "fdc.nal.usda.gov"
                or not url.path.startswith("/fdc-datasets/") or not url.path.endswith(".zip")
                or url.query or url.fragment):
            raise ValidationError(f"{key}: expected an official USDA archive URL")
        if pin["format"] != ("json.zip" if key in auxiliary else "csv.zip") or not re.fullmatch(r"[0-9a-f]{64}", pin["sha256"]):
            raise ValidationError(f"{key}: invalid archive format or SHA256")
        if not re.fullmatch(r"\d{4}-\d{2}(?:-\d{2})?", pin["release"]):
            raise ValidationError(f"{key}: invalid release")
        if key in DATASETS:
            if (pin["data_type"] != DATASETS[key] or pin["supporting_source"] != "supporting"
                    or pin["nutrient_reference"] not in ("id", "nutrient_nbr")
                    or pin["food_reference"] not in ("fdc_id", "food_code")
                    or (key != "survey" and pin["food_reference"] != "fdc_id")):
                raise ValidationError(f"{key}: unsupported identifier contract")


def text_value(row, key):
    value = row.get(key, "")
    return value if value != "" else None


def integer(row, key, required=False):
    value = text_value(row, key)
    if value is None and not required:
        return None
    if value is None or not re.fullmatch(r"[0-9]+", value):
        raise ValidationError(f"Invalid {key}: {value!r}")
    return int(value)


def decimal_text(row, key):
    value = text_value(row, key)
    if value is not None:
        try:
            if not Decimal(value).is_finite():
                raise InvalidOperation
        except InvalidOperation as error:
            raise ValidationError(f"Invalid decimal {key}: {value!r}") from error
    return value


def extras(row, known):
    return canonical({key: value for key, value in row.items() if key not in known})


class Archive:
    def __init__(self, path):
        try:
            self.zip = ZipFile(path)
        except BadZipFile as error:
            raise ValidationError(f"Invalid ZIP archive: {Path(path).name}") from error
        self.members = {}
        for member in self.zip.infolist():
            if not member.is_dir() and member.filename.endswith(".csv"):
                name = Path(member.filename).name.removesuffix(".csv")
                if name in self.members:
                    self.zip.close()
                    raise ValidationError(f"Ambiguous CSV member: {name}")
                self.members[name] = member

    def close(self):
        self.zip.close()

    def rows(self, table, required_columns):
        if table not in self.members:
            raise ValidationError(f"Missing CSV member: {table}")
        with self.zip.open(self.members[table]) as raw:
            reader = csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8-sig", newline=""), strict=True)
            columns = reader.fieldnames or []
            if len(set(columns)) != len(columns) or not set(required_columns) <= set(columns):
                raise ValidationError(f"{table}: missing or duplicate CSV columns")
            for row in reader:
                if None in row or None in row.values():
                    raise ValidationError(f"{table}: malformed row {reader.line_num}")
                yield row


def indexed(rows, key):
    result = {}
    for row in rows:
        identity = integer(row, key, required=True)
        if identity in result:
            raise ValidationError(f"Duplicate {key}: {identity}")
        result[identity] = row
    return result


def insert(db, table, rows):
    if rows:
        # Source CSV ordering does not affect layout or the fingerprint.
        columns = db.execute(f"PRAGMA table_info({table})").fetchall()
        keys = [column[0] for column in sorted(columns, key=lambda column: column[5]) if column[5]]
        rows.sort(key=lambda row: tuple(row[key] for key in keys))
        db.executemany(f"INSERT INTO {table} VALUES ({','.join('?' for _ in rows[0])})", rows)


def lookup(archives, dataset, table, columns):
    source = dataset if table in archives[dataset].members else "supporting"
    return source, list(archives[source].rows(table, columns))


def import_lookups(db, archives, dataset):
    source, rows = lookup(archives, dataset, "nutrient", ("id", "name", "unit_name", "nutrient_nbr"))
    nutrients = indexed(rows, "id")
    insert(db, "nutrient", [
        (dataset, identity, row["name"], row["unit_name"], text_value(row, "nutrient_nbr"),
         decimal_text(row, "rank"), source, extras(row, {"id", "name", "unit_name", "nutrient_nbr", "rank"}))
        for identity, row in nutrients.items()
    ])
    numbers = {}
    for identity, row in nutrients.items():
        numbers.setdefault(row["nutrient_nbr"], []).append(identity)

    for csv_table, sql_table, has_source in (
        ("food_nutrient_source", "nutrient_source", False),
        ("food_nutrient_derivation", "nutrient_derivation", True),
    ):
        source, rows = lookup(archives, dataset, csv_table, ("id", "code", "description"))
        rows = indexed(rows, "id")
        values = []
        for identity, row in rows.items():
            value = (dataset, identity, text_value(row, "code"), row["description"])
            if has_source:
                value += (integer(row, "source_id"),)
            values.append(value + (source, extras(row, {"id", "code", "description", "source_id"})))
        insert(db, sql_table, values)

    source, rows = lookup(archives, dataset, "measure_unit", ("id", "name"))
    insert(db, "measure_unit", [
        (dataset, identity, row["name"], text_value(row, "abbreviation"), source,
         extras(row, {"id", "name", "abbreviation"}))
        for identity, row in indexed(rows, "id").items()
    ])
    if dataset == "survey":
        source, rows = lookup(archives, dataset, "wweia_food_category",
                              ("wweia_food_category", "wweia_food_category_description"))
        insert(db, "category", [
            (dataset, "wweia", identity, str(identity), row["wweia_food_category_description"], source,
             extras(row, {"wweia_food_category", "wweia_food_category_description"}))
            for identity, row in indexed(rows, "wweia_food_category").items()
        ])
    else:
        source, rows = lookup(archives, dataset, "food_category", ("id", "code", "description"))
        insert(db, "category", [
            (dataset, "food", identity, text_value(row, "code"), row["description"], source,
             extras(row, {"id", "code", "description"}))
            for identity, row in indexed(rows, "id").items()
        ])
    return nutrients, numbers


def import_dataset(db, archives, dataset, pin, fixes):
    nutrients, numbers = import_lookups(db, archives, dataset)
    archive = archives[dataset]
    foods = indexed(archive.rows("food", ("fdc_id", "data_type", "description", "publication_date")), "fdc_id")
    subtype = indexed(archive.rows(pin["data_type"], ("fdc_id",)), "fdc_id")
    for identity in subtype:
        if identity not in foods or foods[identity]["data_type"] != pin["data_type"]:
            raise ValidationError(f"{dataset}: subtype {identity} has no corresponding food")
    selected = {
        identity: row for identity, row in foods.items()
        if row["data_type"] == pin["data_type"] and row["publication_date"]
    }
    if not selected:
        raise ValidationError(f"{dataset}: no published foods")
    values = []
    for identity, row in selected.items():
        subtype_row = subtype.get(identity, {})
        category = integer(row, "food_category_id")
        kind = "wweia" if dataset == "survey" else "food"
        if dataset == "survey":
            survey_category = integer(subtype_row, "wweia_category_number")
            if category is not None and survey_category is not None and category != survey_category:
                raise ValidationError(f"{dataset}: conflicting category for {identity}")
            category = survey_category if survey_category is not None else category
        values.append((identity, dataset, pin["data_type"], row["publication_date"],
                       kind if category is not None else None, category,
                       canonical(row), canonical(subtype_row)))
    insert(db, "food", values)
    insert(db, "food_name", [(identity, "en", row["description"]) for identity, row in selected.items()])

    codes = {}
    if pin["food_reference"] == "food_code":
        for identity, row in subtype.items():
            codes.setdefault(row.get("food_code"), []).append(identity)

    def resolve_food(row):
        if pin["food_reference"] == "food_code":
            matches = codes.get(row["fdc_id"], [])
            if len(matches) != 1:
                raise ValidationError(f"{dataset}: unresolved or ambiguous food code {row['fdc_id']}")
            identity = matches[0]
        else:
            identity = integer(row, "fdc_id", required=True)
        if identity not in foods:
            raise ValidationError(f"{dataset}: unresolved food {identity}")
        return identity

    counts = [(dataset, "food", len(foods), len(selected), len(foods) - len(selected))]
    values = []
    total = 0
    seen = set()
    excluded_empty_2066 = 0
    known = {"id", "fdc_id", "nutrient_id", "amount", "data_points", "derivation_id",
             "standard_error", "min", "max", "median", "footnote", "min_year_acquired"}
    for row in archive.rows("food_nutrient", ("id", "fdc_id", "nutrient_id", "amount")):
        total += 1
        identity = resolve_food(row)
        if identity not in selected:
            continue
        record_id = integer(row, "id", required=True)
        if record_id in seen:
            raise ValidationError(f"{dataset}: duplicate food-nutrient ID {record_id}")
        seen.add(record_id)
        if pin["nutrient_reference"] == "nutrient_nbr":
            matches = numbers.get(row["nutrient_id"], [])
            if len(matches) != 1:
                raise ValidationError(f"{dataset}: unresolved or ambiguous nutrient number {row['nutrient_id']}")
            nutrient = matches[0]
        else:
            nutrient = integer(row, "nutrient_id", required=True)
            if nutrient not in nutrients:
                if fixes.skip_nutrient(row):
                    excluded_empty_2066 += 1
                    continue
                raise ValidationError(f"{dataset}: unresolved nutrient ID {nutrient}")
        values.append((dataset, record_id, identity, nutrient, row["nutrient_id"],
                       decimal_text(row, "amount"), integer(row, "data_points"), integer(row, "derivation_id"),
                       decimal_text(row, "standard_error"), decimal_text(row, "min"), decimal_text(row, "max"),
                       decimal_text(row, "median"), text_value(row, "footnote"), integer(row, "min_year_acquired"),
                       extras(row, known)))
    counts.append((dataset, "food_nutrient", total, len(values), total - len(values)))
    insert(db, "food_nutrient", values)

    values = []
    total = 0
    known = {"id", "fdc_id", "seq_num", "amount", "measure_unit_id", "portion_description",
             "modifier", "gram_weight", "data_points", "footnote", "min_year_acquired"}
    seen = set()
    units = {row[0] for row in db.execute("SELECT id FROM measure_unit WHERE dataset=?", (dataset,))}
    for row in archive.rows("food_portion", ("id", "fdc_id", "seq_num", "amount", "measure_unit_id", "gram_weight")):
        total += 1
        record_id = integer(row, "id", required=True)
        if record_id in seen:
            raise ValidationError(f"{dataset}: duplicate food-portion ID {record_id}")
        seen.add(record_id)
        row = fixes.portion(row, foods, units)
        if row is None:
            continue
        identity = resolve_food(row)
        if identity not in selected:
            continue
        values.append((dataset, record_id, identity, integer(row, "seq_num"),
                       decimal_text(row, "amount"), integer(row, "measure_unit_id"),
                       text_value(row, "portion_description"), text_value(row, "modifier"),
                       decimal_text(row, "gram_weight"), integer(row, "data_points"), text_value(row, "footnote"),
                       integer(row, "min_year_acquired"), extras(row, known)))
    counts.append((dataset, "food_portion", total, len(values), total - len(values)))
    insert(db, "food_portion", values)
    insert(db, "source_count", counts)
    fixes.log()
    return ([{
        "dataset": dataset,
        "nutrient_id": 2066,
        "reason": "missing nutrient definition with empty amount and metadata",
        "excluded_records": excluded_empty_2066,
    }] if excluded_empty_2066 else [])


def fingerprint(db):
    digest = hashlib.sha256()
    fixes = db.execute("SELECT value FROM metadata WHERE key = 'source_fixes'").fetchone()
    lock = db.execute("SELECT value FROM metadata WHERE key = 'source_lock'").fetchone()
    exceptions = db.execute("SELECT value FROM metadata WHERE key = 'import_exceptions'").fetchone()
    digest.update(canonical({
        "schema_version": SCHEMA_VERSION,
        "source_fixes": json.loads(fixes[0]) if fixes else [],
        "auxiliary": json.loads(lock[0]).get("auxiliary", {}) if lock else {},
        "import_exceptions": json.loads(exceptions[0]) if exceptions else [],
    }).encode("utf-8") + b"\n")
    for table in CATALOGUE_TABLES:
        digest.update(table.encode("ascii") + b"\n")
        columns = db.execute(f"PRAGMA table_info({table})").fetchall()
        order = ",".join(column[1] for column in sorted(columns, key=lambda column: column[5]) if column[5])
        for row in db.execute(f"SELECT * FROM {table} ORDER BY {order}"):
            digest.update(canonical(row).encode("utf-8") + b"\n")
    return digest.hexdigest()


def validate_database(db, lock):
    if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
        raise ValidationError("SQLite integrity check failed")
    failures = db.execute("PRAGMA foreign_key_check").fetchmany(5)
    if failures:
        raise ValidationError(f"Unresolved references: {failures}")
    if dict(db.execute("SELECT id, pin FROM source")) != {
        key: canonical(pin) for key, pin in lock["sources"].items()
    }:
        raise ValidationError("Source pin coverage differs from the lock")
    if db.execute("PRAGMA user_version").fetchone()[0] != SCHEMA_VERSION:
        raise ValidationError("Schema version differs")
    for dataset in DATASETS:
        if db.execute("SELECT count(*) FROM food WHERE dataset = ?", (dataset,)).fetchone()[0] == 0:
            raise ValidationError(f"{dataset}: empty dataset")
        for table in ("food", "food_nutrient", "food_portion"):
            expected = db.execute("SELECT included FROM source_count WHERE dataset = ? AND table_name = ?",
                                  (dataset, table)).fetchone()
            actual = db.execute(f"SELECT count(*) FROM {table} WHERE dataset = ?", (dataset,)).fetchone()
            if expected != actual:
                raise ValidationError(f"{dataset}: {table} source/output counts differ")
    if db.execute("SELECT count(*) FROM food").fetchone() != db.execute("SELECT count(*) FROM food_name").fetchone():
        raise ValidationError("English name coverage differs")
    if db.execute("SELECT count(*) FROM food_name").fetchone() != db.execute("SELECT count(*) FROM food_search").fetchone():
        raise ValidationError("Search coverage differs")
    if db.execute("""SELECT count(*) FROM (
                     SELECT fdc_id, locale, description FROM food_name EXCEPT
                     SELECT fdc_id, locale, description FROM food_search)""").fetchone()[0]:
        raise ValidationError("Search descriptions differ")
    db.execute("INSERT INTO food_search(food_search) VALUES ('integrity-check')")
    # Verify real catalogue text with case-insensitive, multiword and prefix
    # queries. Fixtures separately exercise accent removal and exact results.
    for identity, description in db.execute("SELECT fdc_id, description FROM food_name ORDER BY fdc_id"):
        words = re.findall(r"[^\W\d_]{2,}", description)
        if len(words) < 2:
            continue
        queries = (f'"{words[0].lower()}" "{words[1].lower()}"',
                   f'"{words[0].upper()}" "{words[1].upper()}"',
                   f'"{words[0][:3]}"*')
        for query in queries:
            if not db.execute("SELECT 1 FROM food_search WHERE food_search MATCH ? AND fdc_id = ?",
                              (query, identity)).fetchone():
                raise ValidationError(f"Search verification failed: {query}")
        break
    else:
        raise ValidationError("No description suitable for search verification")


def report(db, output):
    return {
        "releases": {key: json.loads(pin)["release"] for key, pin in db.execute("SELECT id, pin FROM source")},
        "foods": dict(db.execute("SELECT dataset, count(*) FROM food GROUP BY dataset")),
        "nutrient_definitions": db.execute("SELECT count(*) FROM nutrient").fetchone()[0],
        "food_nutrients": db.execute("SELECT count(*) FROM food_nutrient").fetchone()[0],
        "portions": db.execute("SELECT count(*) FROM food_portion").fetchone()[0],
        "import_exceptions": json.loads(db.execute(
            "SELECT value FROM metadata WHERE key = 'import_exceptions'").fetchone()[0]),
        "source_fixes": json.loads(db.execute(
            "SELECT value FROM metadata WHERE key = 'source_fixes'").fetchone()[0]),
        "auxiliary": json.loads(db.execute(
            "SELECT value FROM metadata WHERE key = 'source_lock'").fetchone()[0]).get("auxiliary", {}),
        "source_counts": [dict(zip(("dataset", "table", "total", "included", "excluded"), row))
                          for row in db.execute("SELECT * FROM source_count ORDER BY dataset, table_name")],
        "database_bytes": Path(output).stat().st_size,
        "catalogue_fingerprint": db.execute("SELECT value FROM metadata WHERE key = 'catalogue_fingerprint'").fetchone()[0],
    }


def build_database(lock, paths, output, schema=None):
    validate_lock(lock)
    all_pins = {**lock["sources"], **lock.get("auxiliary", {})}
    if set(paths) != set(all_pins):
        raise ValidationError("Archive arguments must cover every source exactly once")
    for key, pin in all_pins.items():
        if sha256(paths[key]) != pin["sha256"]:
            raise ValidationError(f"{key}: SHA256 mismatch")
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    schema = Path(schema) if schema else Path(__file__).with_name("schema.sql")
    with tempfile.TemporaryDirectory(prefix=".food-data-", dir=output.parent) as temporary:
        candidate = Path(temporary) / "catalogue.sqlite"
        with contextlib.ExitStack() as stack:
            archives = {}
            for key in sorted(lock["sources"]):
                archives[key] = Archive(paths[key])
                stack.callback(archives[key].close)
            db = sqlite3.connect(candidate)
            stack.callback(db.close)
            db.executescript(schema.read_text(encoding="utf-8"))
            # Resolve cross-table references only after all rows are inserted.
            db.execute("PRAGMA defer_foreign_keys = ON")
            insert(db, "source", [(key, canonical(pin)) for key, pin in lock["sources"].items()])
            import_exceptions = []
            summaries = []
            for dataset in sorted(DATASETS):
                fixes = SourceFixes(dataset, lock["sources"][dataset], paths, ValidationError)
                import_exceptions.extend(import_dataset(db, archives, dataset, lock["sources"][dataset], fixes))
                summaries.append(fixes.summary())
            db.execute("""INSERT INTO food_search(fdc_id, locale, description)
                          SELECT fdc_id, locale, description FROM food_name ORDER BY fdc_id, locale""")
            validate_database(db, lock)
            insert(db, "metadata", [
                ("schema_version", str(SCHEMA_VERSION)),
                ("source_lock", canonical(lock)),
                ("import_exceptions", canonical(import_exceptions)),
                ("source_fixes", canonical(summaries)),
            ])
            insert(db, "metadata", [("catalogue_fingerprint", fingerprint(db))])
            db.commit()
            db.execute("VACUUM")
            result = report(db, candidate)
        candidate.replace(output)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--schema", type=Path)
    parser.add_argument("--archive", action="append", default=[], metavar="SOURCE=ZIP")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    paths = {}
    for value in args.archive:
        key, separator, path = value.partition("=")
        if not separator or key in paths:
            parser.error("Each --archive must be a unique SOURCE=ZIP")
        paths[key] = Path(path)
    try:
        print(json.dumps(build_database(load_lock(args.lock), paths, args.output, args.schema), indent=2, sort_keys=True))
    except (sqlite3.Error, csv.Error, OSError, ValueError) as error:
        parser.exit(1, f"Food-data generation failed: {error}\n")


if __name__ == "__main__":
    main()
