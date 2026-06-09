# v0.2.0

- `useGoogleUuid` config option: opt-in mapping of uuid columns to `uuid.UUID`
  from github.com/google/uuid (pointer when nullable, slices for arrays)
  instead of the default canonical-text `string`.

# v0.1.0

Initial release.

- gen-sdk v0.10.2 (contract 3.0) integration, consumed by pgn >= 0.6.
- PostgreSQL → native Go type table: public API uses only stdlib types
  (nullable → pointer, arrays → slices), no third-party deps in signatures.
- Generated code targets pgx v5 (`Queries` struct over a `DBTX` interface,
  `pgx.RowToStructByName` row mapping).
- Result cardinality: Single / Optional / Multiple / RowsAffected / Void.
- Custom types (enums, composites, domains) emitted into `models.go` with a
  `RegisterTypes(ctx, conn)` helper.
- Types without a native Go equivalent (uuid, numeric, inet, ...) exposed as
  canonical text `string`; inet/cidr/interval result columns fetched in text
  format automatically.
- Config options: `packageName`, `emitGoMod`.
- Unsupported PostgreSQL types produce a generation error instead of broken code.
- E2E-tested through the real pgn CLI against pgenie-io/demo and a live
  PostgreSQL 18.
