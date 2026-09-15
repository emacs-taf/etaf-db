# Changelog

## Unreleased

### Changed

- The package entry is now `etaf-db`, matching the repository and its role as
  ETAF's database backend package. SQLite is the only implemented backend.
  Replace `(require 'etaf-sqlite)` with `(require 'etaf-db)` and use `etaf-db`
  in package dependencies and installation recipes. SQLite-specific
  `etaf-sqlite-*` constructors and errors keep their existing contracts.
  The old `etaf-sqlite.el` entry is removed; no compatibility loader is provided.
