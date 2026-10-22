PRAGMA page_size = 4096;
PRAGMA encoding = 'UTF-8';
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = DELETE;
PRAGMA user_version = 1;

CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE source (
    id TEXT PRIMARY KEY,
    pin TEXT NOT NULL
) WITHOUT ROWID;

-- Lookup identities are local to each dataset; lookup_source identifies the
-- archive that supplied the definition (including supporting-data fallbacks).
CREATE TABLE category (
    dataset TEXT NOT NULL REFERENCES source(id),
    kind TEXT NOT NULL CHECK (kind IN ('food', 'wweia')),
    id INTEGER NOT NULL,
    code TEXT,
    description TEXT NOT NULL,
    lookup_source TEXT NOT NULL REFERENCES source(id),
    extra_fields TEXT NOT NULL,
    PRIMARY KEY (dataset, kind, id)
) WITHOUT ROWID;

CREATE TABLE nutrient (
    dataset TEXT NOT NULL REFERENCES source(id),
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    unit_name TEXT NOT NULL,
    nutrient_nbr TEXT,
    rank TEXT,
    lookup_source TEXT NOT NULL REFERENCES source(id),
    extra_fields TEXT NOT NULL,
    PRIMARY KEY (dataset, id)
) WITHOUT ROWID;

CREATE TABLE nutrient_source (
    dataset TEXT NOT NULL REFERENCES source(id),
    id INTEGER NOT NULL,
    code TEXT,
    description TEXT NOT NULL,
    lookup_source TEXT NOT NULL REFERENCES source(id),
    extra_fields TEXT NOT NULL,
    PRIMARY KEY (dataset, id)
) WITHOUT ROWID;

CREATE TABLE nutrient_derivation (
    dataset TEXT NOT NULL REFERENCES source(id),
    id INTEGER NOT NULL,
    code TEXT,
    description TEXT NOT NULL,
    source_id INTEGER,
    lookup_source TEXT NOT NULL REFERENCES source(id),
    extra_fields TEXT NOT NULL,
    PRIMARY KEY (dataset, id),
    FOREIGN KEY (dataset, source_id) REFERENCES nutrient_source(dataset, id)
) WITHOUT ROWID;

CREATE TABLE measure_unit (
    dataset TEXT NOT NULL REFERENCES source(id),
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    abbreviation TEXT,
    lookup_source TEXT NOT NULL REFERENCES source(id),
    extra_fields TEXT NOT NULL,
    PRIMARY KEY (dataset, id)
) WITHOUT ROWID;

CREATE TABLE food (
    fdc_id INTEGER PRIMARY KEY,
    dataset TEXT NOT NULL REFERENCES source(id),
    data_type TEXT NOT NULL,
    publication_date TEXT NOT NULL,
    category_kind TEXT,
    category_id INTEGER,
    source_fields TEXT NOT NULL,
    subtype_fields TEXT NOT NULL,
    UNIQUE (dataset, fdc_id),
    CHECK ((category_kind IS NULL) = (category_id IS NULL)),
    FOREIGN KEY (dataset, category_kind, category_id) REFERENCES category(dataset, kind, id)
);

CREATE TABLE food_name (
    fdc_id INTEGER NOT NULL REFERENCES food(fdc_id),
    locale TEXT NOT NULL,
    description TEXT NOT NULL,
    PRIMARY KEY (fdc_id, locale)
) WITHOUT ROWID;

-- Numeric quantities retain their published decimal spelling. Empty amounts
-- become SQL NULL; a reported zero remains text such as '0' or '0.0'.
CREATE TABLE food_nutrient (
    dataset TEXT NOT NULL,
    id INTEGER NOT NULL,
    fdc_id INTEGER NOT NULL,
    nutrient_id INTEGER NOT NULL,
    source_nutrient_id TEXT NOT NULL,
    amount TEXT,
    data_points INTEGER,
    derivation_id INTEGER,
    standard_error TEXT,
    min TEXT,
    max TEXT,
    median TEXT,
    footnote TEXT,
    min_year_acquired INTEGER,
    extra_fields TEXT NOT NULL,
    PRIMARY KEY (dataset, id),
    FOREIGN KEY (dataset, fdc_id) REFERENCES food(dataset, fdc_id),
    FOREIGN KEY (dataset, nutrient_id) REFERENCES nutrient(dataset, id),
    FOREIGN KEY (dataset, derivation_id) REFERENCES nutrient_derivation(dataset, id)
) WITHOUT ROWID;
CREATE INDEX food_nutrient_food ON food_nutrient(fdc_id, nutrient_id);

CREATE TABLE food_portion (
    dataset TEXT NOT NULL,
    id INTEGER NOT NULL,
    fdc_id INTEGER NOT NULL,
    seq_num INTEGER,
    amount TEXT,
    measure_unit_id INTEGER,
    portion_description TEXT,
    modifier TEXT,
    gram_weight TEXT,
    data_points INTEGER,
    footnote TEXT,
    min_year_acquired INTEGER,
    extra_fields TEXT NOT NULL,
    PRIMARY KEY (dataset, id),
    FOREIGN KEY (dataset, fdc_id) REFERENCES food(dataset, fdc_id),
    FOREIGN KEY (dataset, measure_unit_id) REFERENCES measure_unit(dataset, id)
) WITHOUT ROWID;
CREATE INDEX food_portion_food ON food_portion(fdc_id, seq_num, id);

CREATE TABLE source_count (
    dataset TEXT NOT NULL REFERENCES source(id),
    table_name TEXT NOT NULL,
    total INTEGER NOT NULL,
    included INTEGER NOT NULL,
    excluded INTEGER NOT NULL,
    CHECK (total = included + excluded),
    PRIMARY KEY (dataset, table_name)
) WITHOUT ROWID;

CREATE VIRTUAL TABLE food_search USING fts5(
    fdc_id UNINDEXED,
    locale UNINDEXED,
    description,
    tokenize = 'unicode61 remove_diacritics 2',
    prefix = '2 3 4'
);
