# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Go code generator for the pGenie ecosystem. It produces type-safe Go code for
working with PostgreSQL from SQL queries, alongside the other generators
(rust.gen, java.gen, haskell.gen). The generator itself is written in Dhall and
follows the gen-sdk contract.

## Architecture

The generator is written in Dhall:

- **gen/Gen.dhall** — entry point, implements `Sdk.module` (contract 3.0,
  consumed by pgn >= 0.6).
- **gen/Config.dhall** — configuration schema. All fields are `Optional` so a
  partial `config:` from project1.pgn.yaml decodes; defaults live in compile.dhall.
- **gen/compile.dhall** — applies config defaults and runs the Project interpreter.
- **gen/Algebras/Interpreter.dhall** — wraps an interpreter `run` into
  `Lude.Compiled.Type` (`{ Input, Output, Result, Run, run }`).
- **gen/Deps/** — pinned dependencies (`package.dhall` re-exports them):
  - `Sdk.dhall` — gen-sdk **v0.10.2** (contract 3.0). Imports `Project.dhall`
    and `module.dhall` directly, bypassing the SDK's package.dhall: its
    Fixtures need the `Text/equal` builtin, which released dhall (<= 1.42.2)
    lacks (pgn itself runs a patched dhall fork, so loading via pgn is fine).
  - `Prelude.dhall` — v23.1.0
  - `Lude.dhall` — v4.0.0 (provides `Compiled`, `File`/`Files`)
- **gen/Interpreters/**
  - `Project.dhall` — `Project → List Sdk.File` (emits `go.mod`, `db.go`, queries).
  - `Query.dhall` — one `Query → Go file` (SQL const, Params struct, Row struct, method).
  - `Primitive.dhall` — the PostgreSQL→Go type table.
  - `GoType.dhall` — shared Member/Value → Go type mapping (arrays,
    nullability, unsupported-type errors). Tests: `tests/GoType.test.dhall`.
  - `CustomType.dhall` — enum/composite/domain → Go type for `models.go`.

The reference for the desired output is **tests/expected/** (golden files). The
generator output is diffed against it. The local test fixture (new-model
Project value) lives in **tests/Fixtures/Demo.dhall**.

### gen-sdk model notes (contract 3.0)

- `Sdk.Project.Name` is a record of pre-rendered case forms:
  `name.inPascalCase`, `name.inCamelCase`, `name.inSnakeCase`, ...
- `Sdk.Project.Query.result : < Void | RowsAffected | Rows : ResultRows >`:
  Void → `error`; RowsAffected → `(int64, error)` via `tag.RowsAffected()`;
  Rows → per cardinality (see Result Cardinality below).
- `ResultRows.cardinality : < Optional | Single | Multiple >`,
  `ResultRows.columns : NonEmpty Member`.
- `Member = { isNullable : Bool, name : Name, pgName : Text, value : { scalar, arraySettings } }`.
- `Scalar = < Primitive : Primitive | Custom : Name >`.
- `Query` also carries `identity : Bool` (currently unused by this generator).
- An interpreter `run` must return `Lude.Compiled.Type Output`; wrap plain
  values with `Lude.Compiled.applicative.pure`, report errors with
  `Lude.Compiled.err Output path message`.

## Generated Code Structure

Flat package (matches tests/expected/):

```
generated/
├── go.mod           # optional (config emitGoMod, default true)
├── db.go            # DBTX interface, Queries struct, New(), WithTx()
├── models.go        # custom types (enum/composite/domain) + RegisterTypes; omitted if none
└── queries.sql.go   # per-query: SQL const, Params/Row structs, method
```

With `emitGoMod: true` (default) the artifact is a standalone Go module
(consumed via go.work or a replace directive); with `false` only package
sources are emitted, for vendoring into an existing module.

## Type Mapping

Public API (params and results) exposes **only native Go types** — no third-party
dependencies (no `google/uuid`, etc.).

- **NOT NULL** → native type (`string`, `int64`, `time.Time`, ...).
- **Nullable** → pointer (`*string`, `*int64`, `*time.Time`, ...). Slices like
  `[]byte` are already nilable, so nullable == NOT NULL.
- **Arrays** (`value.arraySettings`) → slices, `[]T` per dimension. Nullable
  element → pointer element (`[]*string`); a nullable array is just the slice
  (already nilable).

Generated code does not use `pgtype` at all: viaString types are read and
written in their canonical text form directly through pgx (see below).

| PostgreSQL | NOT NULL | Nullable | Notes |
|------------|----------|----------|-------|
| `bool` | `bool` | `*bool` | |
| `int2/int4/int8` | `int16/int32/int64` | `*int16/...` | |
| `float4/float8` | `float32/float64` | `*float32/...` | |
| `text/varchar/bpchar/citext/name` | `string` | `*string` | |
| `oid` | `uint32` | `*uint32` | |
| `date/time/timestamp/timestamptz` | `time.Time` | `*time.Time` | needs `time` import |
| `bytea` | `[]byte` | `[]byte` | |
| `json/jsonb` | `[]byte` | `[]byte` | |
| `uuid/numeric/inet/cidr/interval/macaddr/timetz/ltree` | `string` | `*string` | **viaString**: canonical text form, scanned/encoded as `string` directly |
| `uuid` with `useGoogleUuid: true` | `uuid.UUID` | `*uuid.UUID` | github.com/google/uuid; pgx handles `[16]byte`-based types natively (verified vs PG 18: scan, NULL, arrays, encode) |
| everything else | — | — | unsupported → compile error |

**viaString rationale:** Go has no stdlib type for `uuid`/`numeric`/etc. Other
generators pull libraries (Java `UUID`/`BigDecimal`, Rust `uuid`/`rust_decimal`,
Haskell `UUID`/`Scientific`). To keep the public API dependency-free we expose a
canonical `string`. pgx v5 encodes string params and scans most of these types
into `string` directly; the three whose **binary** codec cannot scan into
string — `inet`, `cidr`, `interval` — are requested in **text format**: queries
with such result columns pass a generated `forceTextFormats`
(`pgx.QueryResultFormatsByOID`) option as the first `Query` argument. Verified
empirically against pgx v5.9.2 + PostgreSQL 16 (scan, NULL, arrays, encode).

**`useGoogleUuid` (implemented):** opt-in Bool config (default False; a Bool
rather than a Text enum because released dhall lacks the `Text/equal` builtin,
and it matches java.gen's `useOptional` convention). When True, `Uuid` maps to
`uuid.UUID`/`*uuid.UUID` via the `needsUuid` import flag (plumbed like
`needsTime` through Primitive/GoType/Query/CustomType; `GoType` entry points
take `useGoogleUuid : Bool` first). go.mod then requires
`github.com/google/uuid v1.6.0`. `tests/DemoGoogleUuid.dhall` (run by
`make demo`) compiles the variant from the same fixture.

**Go 1.27 stdlib `uuid` (planned):** golang/go#62026 is accepted (April 2026):
stdlib gets a top-level `uuid` package with `type UUID [16]byte` (release not
confirmed yet; milestone 1.27). Plan: add a `goVersion : Text` option to
`Config.dhall` (default `"1.26"`); when `>= 1.27`, map `Uuid → uuid.UUID`
from stdlib, reusing the `needsUuid` machinery — uuid drops out of viaString
(numeric/inet/interval/... keep it). Switching the default to 1.27 is a separate
breaking release later. Do not implement until the 1.27 release is confirmed.

`Primitive.dhall` returns
`{ notNull, nullable, needsTime, needsUuid, viaString, needsTextFormat, supported }`
for each type; `run` takes `useGoogleUuid : Bool` first. Unsupported types
(`supported = False`) should make the generator report an error.

## Result Cardinality

- **Single** → `(Row, error)`; `pgx.CollectOneRow(rows, pgx.RowToStructByName[Row])`.
- **Optional** → `(*Row, error)`; `CollectOneRow`, return `nil, nil` on `pgx.ErrNoRows`.
- **Multiple** → `([]Row, error)`; `pgx.CollectRows(rows, pgx.RowToStructByName[Row])`.
- **RowsAffected** → `(int64, error)`; `q.db.Exec(...)` + `tag.RowsAffected()`.
- **Void** → `error`; `q.db.Exec(...)`.

## Design Decisions — MVP

- **pgx-only**: `github.com/jackc/pgx/v5` (+ `pgtype`, `pgconn`). No database/sql, no ORM.
- **SQL-first**: queries → params → rows → scanners. No query builder.
- **Minimal abstractions**: `Queries` struct over a `DBTX` interface; no repository pattern.
- **Native public types**: see Type Mapping above.
- **Row mapping**: `pgx.RowToStructByName[T]` with `db:"column_name"` tags.
- **Go 1.26** in generated `go.mod`; pgx `v5.9.2`.

## Generated Code Patterns

```go
type DBTX interface {
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
    Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

type Queries struct{ db DBTX }
func New(db DBTX) *Queries { return &Queries{db: db} }

type GetUserParams struct{ ID int64 }

func (q *Queries) GetUser(ctx context.Context, params GetUserParams) (User, error) {
    rows, err := q.db.Query(ctx, getUserSQL, params.ID)
    if err != nil {
        return User{}, err
    }
    return pgx.CollectOneRow(rows, pgx.RowToStructByName[User])
}
```

## Development Commands

Requirements: docker, go, git (dhall and pgn run in containers).

```bash
make check   # dhall type-check gen/Gen.dhall + tests/GoType.test.dhall asserts
make demo    # generate tests/output (default config) + tests/output-google
             # (useGoogleUuid) from tests/Fixtures/Demo.dhall, go vet both
make e2e     # full pipeline: e2e/run.sh — real pgn CLI (e2e/pgn.Dockerfile)
             # + pgenie-io/demo project + live PostgreSQL 18; compiles the
             # artifact and runs e2e/testdata/artifact_test.go against the DB
make fmt     # dhall format --inplace over all Dhall sources
# gofmt -w on generated output aligns struct fields (pure Dhall can't)
```

## Status

Generator works end-to-end **through the real pGenie pipeline**: `make e2e`
runs pgn v0.6.2 on the official pgenie-io/demo project, the artifact compiles
(`go vet`) and its queries pass against a live PostgreSQL 18 (composites via
RegisterTypes, enums, ltree, RowsAffected, Optional→nil).

- ✅ gen-sdk **v0.10.2 / contract 3.0** integration (pgn >= 0.6); `Result`
  Void/RowsAffected/Rows, pre-rendered `Name`, `Lude.Compiled`.
- ✅ Partial config decoding (`config: { emitGoMod: false }`) — Config fields
  are Optional, defaults in compile.dhall; `emitGoMod` toggles go.mod.
- ✅ Type table (`Primitive.dhall`) — native-only public mapping.
- ✅ `Query.dhall` rendering (SQL const, Params/Row structs, method, import flags).
- ✅ `Project.dhall` assembling `go.mod` + `db.go` + single `queries.sql.go`.

Phase 2 (not done — see the plan for details):

- ✅ Unsupported types (`supported = False`, e.g. `tsvector`) report a
  generation error (`Sdk.Compiled.err`, path = query srcPath) instead of
  emitting an empty Go type. `ltree` is supported via viaString.
- ✅ Arrays — `value.arraySettings` maps to slices (`[]T` per dimension,
  nullable element → `[]*T`). Shared mapping lives in
  `gen/Interpreters/GoType.dhall` (unit tests: `tests/GoType.test.dhall`).
- ✅ Custom types → `models.go` (`gen/Interpreters/CustomType.dhall`):
  enum → `type X string` + consts; composite → struct with db tags;
  domain → type alias. Plus a `RegisterTypes(ctx, conn)` helper that
  `conn.LoadType`s every type (and its `_array` form) with a retry loop, so
  declaration order doesn't matter for composites referencing composites.
- ✅ viaString — no conversion machinery needed: pgx scans/encodes `string`
  directly; inet/cidr/interval result columns get `forceTextFormats`
  (`needsTextFormat` in `Primitive.dhall`). E2E-verified against PostgreSQL 16.
- ✅ `useGoogleUuid` — opt-in uuid → github.com/google/uuid mapping
  (see Type Mapping above).
- ✅ Cosmetics: exactly one blank line between queries. Struct-field alignment
  is left to `gofmt -w` as a post-generation step (pure Dhall cannot measure
  text length); the output is otherwise gofmt-clean.

**Note on `tests/expected/`:** it is a hand-written style reference on a simple
`users` schema. The demo runs on the local `tests/Fixtures/Demo.dhall` fixture
(different schema), so `diff -r tests/expected/ tests/output/` will NOT match
byte-for-byte — `expected/` documents the desired style, not a byte target.

## Reference Implementations

- rust.gen: https://github.com/pgenie-io/rust.gen
- java.gen: https://github.com/pgenie-io/java.gen
- haskell.gen: https://github.com/pgenie-io/haskell.gen
- gen-sdk: https://github.com/pgenie-io/gen-sdk
