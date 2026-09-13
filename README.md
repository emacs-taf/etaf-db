# etaf-sqlite

`etaf-sqlite` is the concrete SQLite storage package for ETAF. It adapts Emacs' built-in SQLite support to the core `etaf-data-source` capability contract. The Data Controller remains in `etaf`; this package owns only schema validation, short-lived connections, pagination queries, and synchronous mutations.

```elisp
(require 'etaf-sqlite)

(let* ((table (etaf-sqlite-table
               'items
               (list (etaf-sqlite-column :id "id" :type 'integer :primary t)
                     (etaf-sqlite-column :name "name" :type 'text))
               :id))
       (database (etaf-sqlite-database "~/items.sqlite" table))
       (source (etaf-sqlite-source database)))
  (etaf-sqlite-initialize database)
(etaf-data-controller source :auto-load t))
```

The source keeps the legacy `:mutate` callback by default.  The additive
commit-certified wrapper is opt-in: use `(etaf-sqlite-source database
:mutate-v2 t)` when a controller needs explicit commit/rollback certainty and
read-only reconciliation.

Other databases, REST services, files, and ORMs should implement the same source capability in their own packages; they do not belong in ETAF core or in a generic `etaf-adapters` layer.

Run `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs` from this directory.

## Development

After cloning, run `make setup-hooks`. Before submitting a change, run `make check`; `make structure-check` is the fast organization gate. The shared rules are in [AGENTS.md](AGENTS.md).

[Integration contract](docs/manual.md).

`make check` runs structure checks, compilation and the public acceptance scenarios listed in [scripts/acceptance.json](scripts/acceptance.json). `make test` runs the broader regression suite; GUI and performance checks remain explicit targets. The acceptance inventory is selected by user-visible contracts, not by current pass/fail status.
