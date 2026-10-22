# Pinned food catalogues

Official source archives are pinned separately under `sources/<database>/`.
Each source owns its importer, nutrient mappings, release discovery and reviewed
exceptions. Shared code stores full source records and produces the app's
nutrition projection and combined SQLite search catalogue.

USDA CSV remains the primary format: a multi-year comparison found it retained
more published foods, nutrient precision and metadata than bulk JSON.
Reviewed USDA repairs are guarded by dataset, release and exact archive SHA256.
They never apply automatically to another pin.

## Update

```sh
nix run .#update-food-data -- usda
nix run .#update-food-data -- --all
```

Select sources explicitly. Candidates are downloaded into the ignored
`.nix-cache/food-data/` directory and validated before their own pins are
published. Failed updates retain existing pins. Other databases and unrelated
Nix inputs are not upgraded.

## Build

```sh
nix build .#food-data-usda
nix build .#food-database
```

Each source package contains `food-data.sqlite` and links to its unchanged
source archives. The combined package contains the app catalogue. Edit
`registry.json` to select bundled sources. Removing a source from that list
removes it from the combined catalogue without changing other source packages.

The `food` and `food_portion` tables serve the app. `source_record` retains
source-native records (with column names in `source_table`), including unsupported nutrients, original decimal
spellings, metadata and provenance. `catalogue_source` describes releases,
attribution and source links. The `nutrition` JSON field is a separate app
projection; it does not replace published values.

```sh
sqlite3 -readonly result/food-data.sqlite \
  'SELECT source, count(*) FROM food GROUP BY source;'
sqlite3 -readonly result/food-data.sqlite \
  "SELECT code, name FROM food_search WHERE food_search MATCH 'apple pie*' LIMIT 20;"
```

## Validate

```sh
nix flake check -L
python3 -m unittest discover -s nix/food-data/tests -v
```

Checks validate importer behavior and byte-for-byte source and combined catalogue
determinism. Source packages depend only on their own inputs and shared code.

Data attribution: U.S. Department of Agriculture, Agricultural Research Service,
FoodData Central, https://fdc.nal.usda.gov/.
