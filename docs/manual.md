# SQLite adapter manual

## Integration contract

Provider: `etaf-sqlite` in the `etaf-db` repository. Consumers create an
`etaf-data-source` for an ETAF Data Controller; the controller owns reactive state
and lifecycle. This adapter owns schema validation, SQL, transactions and short-lived
connections. Use public constructors and capabilities; do not call private SQL helpers.

1. Build columns with `etaf-sqlite-column` and a table with `etaf-sqlite-table`.
2. Create a database descriptor with `etaf-sqlite-database`, then call
   `etaf-sqlite-initialize` to create the declared table if needed.
3. Pass `(etaf-sqlite-source database)` to `etaf-data-controller`.

The source accepts equality plist/alist queries and paginated loads. It supports
`insert`, `replace`, `update` and `delete`; mutation results include the operation,
affected row count and inserted identity when applicable. Every operation uses a
short-lived connection. Function docstrings specify constructor arguments.

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
[ETAF's manual](https://gitea.gklazycat.heiyu.space/geekinney/etaf/src/branch/main/docs/manual.md).
