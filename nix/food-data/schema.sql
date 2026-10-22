PRAGMA page_size = 4096;
PRAGMA encoding = 'UTF-8';
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = DELETE;
PRAGMA user_version = 2;

CREATE TABLE catalogue_source (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    releases TEXT NOT NULL,
    attribution TEXT NOT NULL,
    website TEXT NOT NULL,
    terms_url TEXT NOT NULL,
    terms_required INTEGER NOT NULL CHECK (terms_required IN (0, 1))
) WITHOUT ROWID;

-- Source-native records retain all imported columns, decimal spellings,
-- nutrient definitions and provenance, independently of the app projection.
CREATE TABLE source_table (
    source TEXT NOT NULL REFERENCES catalogue_source(id),
    table_name TEXT NOT NULL,
    columns TEXT NOT NULL CHECK (json_valid(columns)),
    PRIMARY KEY (source, table_name)
) WITHOUT ROWID;

CREATE TABLE source_record (
    source TEXT NOT NULL REFERENCES catalogue_source(id),
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    payload TEXT NOT NULL CHECK (json_valid(payload)),
    PRIMARY KEY (source, table_name, record_id),
    FOREIGN KEY (source, table_name) REFERENCES source_table(source, table_name)
) WITHOUT ROWID;

CREATE TABLE food (
    code TEXT PRIMARY KEY,
    source TEXT NOT NULL REFERENCES catalogue_source(id),
    source_id TEXT NOT NULL,
    locale TEXT NOT NULL,
    name TEXT NOT NULL,
    aliases TEXT NOT NULL,
    url TEXT NOT NULL,
    nutrition TEXT NOT NULL CHECK (json_valid(nutrition)),
    UNIQUE (source, source_id),
    CHECK (code = source || ':' || source_id)
) WITHOUT ROWID;

CREATE TABLE food_portion (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL REFERENCES food(code),
    position INTEGER NOT NULL,
    label TEXT NOT NULL,
    gram_weight TEXT NOT NULL
) WITHOUT ROWID;
CREATE INDEX food_portion_food ON food_portion(code, position, id);

CREATE VIRTUAL TABLE food_search USING fts5(
    code UNINDEXED,
    source UNINDEXED,
    locale UNINDEXED,
    name,
    aliases,
    tokenize = 'unicode61 remove_diacritics 2',
    prefix = '2 3 4'
);
