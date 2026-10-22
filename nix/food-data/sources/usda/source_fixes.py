"""Reviewed repairs for exact USDA primary pins; never infer fixes by release alone."""

import copy
import json
import sys
from decimal import Decimal, InvalidOperation
from zipfile import ZipFile

# Evidence: the 2021–2026 CSV/JSON comparison found CSV retained more foods,
# nutrient precision and metadata. April 2026 has 273 orphan portions. Matching
# April JSON resolves 266; December 2025 resolves two more. Their union agrees
# on owner, unit, amount, weight and sequence. Five IDs remain absent in both.
# Nutrient 2066 is Vitamin A (333, mg, rank 7420) in matching JSON (27 rows)
# and reviewed API observations (six exact rows in foods 2758990–2758992).
# All 33 have no amount in CSV or API. Skip only those exact empty rows while
# the definition is absent: zero and any populated metadata must still fail.
# At each adopted release compare food/nutrient/portion coverage with matching
# JSON, recheck these defects, then explicitly register or retire repairs.
# Never carry this registration to another hash. API repairs require captured,
# reviewed evidence; ordinary builds must never make live API calls.
# Auxiliary archives are complete pinned evidence, not replacement datasets.

AUXILIARY = {
    "foundation_json_2025-12-18": {
        "format": "json.zip",
        "release": "2025-12-18",
        "sha256": "7ff2828e23ae9e7d5027ffa762117ffdfd0749f7851bcda82d7668f40eb14bbf",
        "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2025-12-18.zip"
    },
    "foundation_json_2026-04-30": {
        "format": "json.zip",
        "release": "2026-04-30",
        "sha256": "186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a",
        "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip"
    }
}

REGISTRATIONS = {
    (
        "foundation",
        "2026-04-30",
        "70457ee9d9342f43bda2010318c85f04210c689fdeb9cd2da4c513b0e8dbc655",
    ): {
        "auxiliary": ("foundation_json_2025-12-18", "foundation_json_2026-04-30"),
        "nutrients": {
            27790249: 2257044,
            27790255: 2257045,
            27790261: 2257046,
            27793269: 2259792,
            27793276: 2259793,
            27793284: 2259794,
            27793292: 2259795,
            27793300: 2259796,
            28912754: 2346384,
            28912759: 2346385,
            28912764: 2346386,
            28912769: 2346387,
            33291134: 321360,
            33296838: 2647437,
            33296845: 2647438,
            33296852: 2647439,
            33296859: 2647440,
            33296866: 2647441,
            33296873: 2647442,
            33296880: 2647443,
            33829272: 2684440,
            33829278: 2684441,
            33829284: 2684442,
            33829290: 2684443,
            33829296: 2684444,
            33829302: 2684445,
            33829308: 2684446,
            35088565: 2758990,
            35088566: 2758990,
            35088573: 2758991,
            35088574: 2758991,
            35088579: 2758992,
            35088580: 2758992,
        },
        "portion_ids": set(range(312552, 312825)),
        "unresolved": {
            312565: "114.0",
            312629: "30.0",
            312635: "30.0",
            312725: "85.0",
            312747: "125.0",
        },
    },
}


def registration(dataset, pin):
    return REGISTRATIONS.get((dataset, pin["release"], pin["sha256"]))


def required_auxiliary(lock):
    names = set()
    for dataset, pin in lock["sources"].items():
        fix = registration(dataset, pin)
        if fix:
            names.update(fix["auxiliary"])
    return {name: copy.deepcopy(AUXILIARY[name]) for name in sorted(names)}


class SourceFixes:
    def __init__(self, dataset, pin, paths, error):
        self.fix = registration(dataset, pin)
        self.error = error
        self.dataset = dataset
        self.release = pin["release"]
        self.skipped_nutrients = []
        self.skipped_portions = []
        self.repaired = []
        self.portions = {}
        if not self.fix:
            return
        for name in sorted(self.fix["auxiliary"]):
            with ZipFile(paths[name]) as archive:
                members = [n for n in archive.namelist() if n.endswith(".json")]
                if len(members) != 1:
                    raise error(f"{name}: expected one JSON member")
                document = json.loads(archive.read(members[0]), parse_float=Decimal)
            for food in document["FoundationFoods"]:
                if food is None:
                    continue
                for portion in food.get("foodPortions", []):
                    identity = portion["id"]
                    if identity not in self.fix["portion_ids"]:
                        continue
                    evidence = (food["fdcId"], portion["measureUnit"]["id"],
                                Decimal(str(portion["amount"])), Decimal(str(portion["gramWeight"])),
                                portion["sequenceNumber"])
                    if identity in self.portions:
                        previous, names = self.portions[identity]
                        if previous != evidence:
                            raise error(f"Conflicting JSON portion association: {identity}")
                        names.append(name)
                    else:
                        self.portions[identity] = (evidence, [name])
        expected = self.fix["portion_ids"] - self.fix["unresolved"].keys()
        if set(self.portions) != expected:
            raise error("JSON portion repair targets differ from reviewed IDs")

    def skip_nutrient(self, row):
        if (self.fix and self.fix["nutrients"].get(int(row["id"])) == int(row["fdc_id"])
                and row["nutrient_id"] == "2066"
                and all(value == "" for key, value in row.items()
                        if key not in {"id", "fdc_id", "nutrient_id"})):
            self.skipped_nutrients.append(int(row["id"]))
            return True
        return False

    def portion(self, row, foods, units):
        try:
            return self._portion(row, foods, units)
        except self.error:
            raise
        except (InvalidOperation, ValueError, TypeError) as error:
            raise self.error(f"Invalid portion repair fields: {row['id']}") from error

    def _portion(self, row, foods, units):
        if not self.fix or (row["fdc_id"] and row["measure_unit_id"]):
            return row
        identity = int(row["id"])
        if identity in self.fix["unresolved"]:
            if (row["fdc_id"] != "" or row["measure_unit_id"] != ""
                    or Decimal(row["amount"]) != 1 or row["seq_num"] != "1"
                    or Decimal(row["gram_weight"]) != Decimal(self.fix["unresolved"][identity])):
                raise self.error(f"Unexpected unresolved portion fields: {identity}")
            self.skipped_portions.append(identity)
            return None
        if identity not in self.portions:
            return row  # Normal importer validation rejects unexpected missing IDs.
        (food, unit, amount, weight, sequence), names = self.portions[identity]
        if (Decimal(row["amount"]) != amount or Decimal(row["gram_weight"]) != weight
                or int(row["seq_num"]) != sequence):
            raise self.error(f"JSON portion quantity mismatch: {identity}")
        if food not in foods or unit not in units:
            raise self.error(f"Unresolved JSON portion target: {identity}")
        repaired = dict(row)
        changes = {}
        for field, target in (("fdc_id", food), ("measure_unit_id", unit)):
            if row[field] and int(row[field]) != target:
                raise self.error(f"Conflicting CSV portion association: {identity}")
            if not row[field]:
                repaired[field] = str(target)
                changes[field] = target
        self.repaired.append({"id": identity, "filled": changes, "auxiliary_sources": sorted(names)})
        return repaired

    def summary(self):
        return {"dataset": self.dataset, "release": self.release,
                "repaired_portions": len(self.repaired),
                "skipped_portions": len(self.skipped_portions),
                "skipped_nutrients": len(self.skipped_nutrients),
                "repairs": sorted(self.repaired, key=lambda row: row["id"]),
                "skipped_portion_ids": sorted(self.skipped_portions),
                "skipped_nutrient_ids": sorted(self.skipped_nutrients)}

    def log(self):
        prefix = f"{self.dataset} {self.release}: "
        for message in (
            f"Repaired {len(self.repaired)} portion records using pinned USDA JSON.",
            f"Skipped {len(self.skipped_portions)} portion records with missing food IDs.",
            f"Skipped {len(self.skipped_nutrients)} empty nutrient records referencing undefined nutrient 2066.",
        ):
            print(prefix + message, file=sys.stderr, flush=True)
