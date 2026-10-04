# Pinned USDA catalogue

This standalone generator imports published data from official USDA FoodData Central CSV ZIP archives.

## Sources and reviewed repairs

CSV remains the primary format: a multi-year comparison found it the most
complete option for published foods, nutrient precision and metadata. Bulk JSON
also has omissions and conflicting associations. We can continue to review this moving forward.

`source_fixes.py` contains reviewed USDA source fixes guarded by dataset, release and exact CSV SHA256, so they never apply automatically to new releases.

## Update

```sh
nix run .#update-food-data
```

The updater reads USDA's official index, chooses the latest listed CSV release
for each source, downloads candidates to the ignored `.nix-cache/food-data/`
directory, computes SHA256s, then runs the same importer and validation used by
normal builds.

## Build

```sh
nix build .#food-database
```

This generates the pinned USDA catalogue at `result/food-data.sqlite`. 

To inspect it with a local `sqlite3` CLI:

```sh
sqlite3 -readonly result/food-data.sqlite '.schema'
sqlite3 -readonly result/food-data.sqlite \
  'SELECT dataset, count(*) FROM food GROUP BY dataset;'
sqlite3 -readonly result/food-data.sqlite \
  "SELECT fdc_id, description FROM food_search WHERE food_search MATCH 'apple pie*' LIMIT 20;"
sqlite3 -readonly result/food-data.sqlite \
  'SELECT * FROM source_count ORDER BY dataset, table_name;'
sqlite3 -readonly result/food-data.sqlite \
  'SELECT * FROM metadata;'
```

## Validate

```sh
nix flake check -L
```

This validates the importer and confirms byte-for-byte database determinism.

For direct fixture diagnostics using any Python with SQLite FTS5 inside the nix shell:

```sh
python3 -m unittest discover -s nix/food-data/tests -v
```

Data attribution: U.S. Department of Agriculture, Agricultural Research Service,
FoodData Central, https://fdc.nal.usda.gov/.
