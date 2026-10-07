# ETAF DB manual

## Integration contract

Load `(require 'etaf-db)` from the repository root. This package provides
database backends for ETAF; SQLite is the only implemented backend. Its
`etaf-sqlite-*` API is documented in the [package entry](../etaf-db.el).

Consumers create an
`etaf-data-source` for an ETAF Data Controller; the controller owns reactive state
and lifecycle. The SQLite backend owns schema validation, SQL, transactions and short-lived
connections. Use public constructors and capabilities; do not call private SQL helpers.

Call `etaf-data-stop` when the controller is no longer used. No database
connection is held by the descriptor or by the source between operations.
Database backends use the existing source capabilities rather than a separate
controller protocol; this package does not add an ORM.

1. Build columns with `etaf-sqlite-column` and a table with `etaf-sqlite-table`.
2. Create a database descriptor with `etaf-sqlite-database`, then call
   `etaf-sqlite-initialize` to create the declared table if needed.
3. Pass `(etaf-sqlite-source database)` to `etaf-data-controller`.

The source accepts equality plist/alist queries and paginated loads. It supports
`insert`, `replace`, `update`, `upsert` and `delete`; mutation results include the
operation, affected row count and inserted identity when applicable. `upsert`
inserts a row or updates the existing row with the same primary key, while
`replace` and `update` signal when the identity is missing. The source exposes
its primary key as the Data Controller `:item-key` capability, so selection
identity needs no extra callback. Every operation uses a short-lived connection. Function docstrings specify constructor arguments.

The source also exposes `:mutate-batch': ETAF's `etaf-data-mutate-many` sends
the whole `(OPERATION PAYLOAD)` list to one SQLite transaction, receives one
result per operation, and reconciles the Controller once, so a bulk import no
longer pays a reload per row.  A signaled operation rolls the whole batch
back; an unknown commit outcome signals `etaf-sqlite-commit-unknown'.

`etaf-sqlite-initialize` reconciles an existing table with its descriptor:
missing nullable columns are added in place, while a missing primary or
declared non-nullable column signals `etaf-sqlite-schema-error' so schema
evolution stays deliberate instead of running against a half-matching table.

The default source exposes `:mutate`. Explicit `:mutate-v2 t` adds commit-certainty
results and an opaque reconciliation token. A known rollback is distinct from an
unknown outcome: commit, rollback or connection-close uncertainty must not be treated
as proof that a mutation failed. Consumers must use the Data Controller's reconciliation
contract rather than retrying an uncertain write blindly. Schema errors and unsupported
operations are signaled to the caller; no fallback storage engine is selected.

## Runnable example and verification

See the complete [README example](../README.md). Run `make test` to check schema,
queries, mutations, rollback/uncertainty and controller integration in
`tests/etaf-sqlite-tests.el`. The provider capability contract belongs to
[ETAF's manual](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf/src/branch/main/docs/manual.md).
