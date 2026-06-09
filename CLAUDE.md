# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Go code generator for the pGenie ecosystem. It produces type-safe Go code for
working with PostgreSQL from SQL queries, alongside the other generators
(rust.gen, java.gen, haskell.gen). The generator itself is written in Dhall and
follows the gen-sdk contract.

## Architecture

The generator is written in Dhall:

- **gen/Gen.dhall** — entry point, implements `Sdk.module`.
- **gen/Config.dhall** — configuration schema (`Type` + `default`).
- **gen/compile.dhall** — builds the interpreter config and runs the Project interpreter.
- **gen/Algebras/Interpreter.dhall** — wraps an interpreter `run` into the
  `Sdk.Compiled.Type` the SDK expects (`{ Input, Output, Result, Run, run }`).
- **gen/Deps/** — pinned dependencies (`package.dhall` re-exports them):
  - `Sdk.dhall` — gen-sdk `f45f4eca`
  - `Prelude.dhall` — v23.1.0
  - `Lude.dhall` — v1.0.0
  - `CodegenKit.dhall` — v0.3.0 (name conversion: `Name.toTextInPascal/Snake/...`)
- **gen/Interpreters/**
  - `Project.dhall` — `Project → List Sdk.File` (emits `go.mod`, `db.go`, queries).
  - `Query.dhall` — one `Query → Go file` (SQL const, Params struct, Row struct, method).
  - `Primitive.dhall` — the PostgreSQL→Go type table.
  - `GoType.dhall` — shared Member/Value → Go type mapping (arrays,
    nullability, unsupported-type errors). Tests: `tests/GoType.test.dhall`.
  - `CustomType.dhall` — enum/composite/domain → Go type for `models.go`.

The reference for the desired output is **tests/expected/** (golden files). The
generator output is diffed against it.

### gen-sdk model notes

- `Sdk.Project.Name` is a structure of characters, NOT a string. Convert with
  `Deps.CodegenKit.Name.toTextInPascal name` / `toTextInSnake name`.
- `Sdk.Project.Query.result : Optional ResultRows` (merge `None`/`Some`).
- `ResultRows.cardinality : < Optional | Single | Multiple >`,
  `ResultRows.columns : NonEmpty Member`.
- `Member = { isNullable : Bool, name : Name, pgName : Text, value : { scalar, arraySettings } }`.
- `Scalar = < Primitive : Primitive | Custom : Name >`.
- An interpreter `run` must return `Sdk.Compiled.Type Output`; wrap plain values
  with `Sdk.Compiled.applicative.pure`.

## Generated Code Structure

Flat package (matches tests/expected/):

```
generated/
├── go.mod
├── db.go            # DBTX interface, Queries struct, New(), WithTx()
├── models.go        # custom types (enum/composite/domain) + RegisterTypes; omitted if none
└── queries.sql.go   # per-query: SQL const, Params/Row structs, method
```

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

**Go 1.27 stdlib `uuid` (planned):** golang/go#62026 is accepted (April 2026):
stdlib gets a top-level `uuid` package with `type UUID [16]byte` (release not
confirmed yet; milestone 1.27). Plan: add a `goVersion : Text` option to
`Config.dhall` (default `"1.26"`); when `>= 1.27`, map `Uuid → uuid.UUID`
(import flag `needsUuid`, like `needsTime`) instead of viaString — pgx scans
`[16]byte`-based types directly, so uuid drops out of the viaString machinery
(numeric/inet/interval/... keep it). Switching the default to 1.27 is a separate
breaking release later. Do not implement until the 1.27 release is confirmed.

`Primitive.dhall` returns `{ notNull, nullable, needsTime, viaString, supported }`
for each type. Unsupported types (`supported = False`) should make the generator
report an error.

## Result Cardinality

- **Single** → `(Row, error)`; `pgx.CollectOneRow(rows, pgx.RowToStructByName[Row])`.
- **Optional** → `(*Row, error)`; `CollectOneRow`, return `nil, nil` on `pgx.ErrNoRows`.
- **Multiple** → `([]Row, error)`; `pgx.CollectRows(rows, pgx.RowToStructByName[Row])`.
- **No result rows** (`result = None`) → `error`; `q.db.Exec(...)`.

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

```bash
# Type-check (Docker; no local dhall needed)
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall type --file gen/Gen.dhall

# Format
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall format --inplace gen/Gen.dhall

# Generate the demo (gen-sdk music_catalogue fixture) into a directory tree
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall to-directory-tree --file tests/Demo.dhall --output tests/output --allow-path-separators
# Inspect tests/output/queries.sql.go (different schema than tests/expected/, so no byte diff)
```

## Status

Generator works end-to-end. `gen/Gen.dhall` type-checks; running the demo against
the gen-sdk fixture produces `go.mod`, `db.go`, `queries.sql.go` for all
cardinalities (Single/Optional/Multiple/exec), with nullable→pointer mapping and
computed imports.

- ✅ gen-sdk integration; `gen/Gen.dhall` type-checks.
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
- ⏳ Cosmetics: gofmt alignment, blank lines between queries.

**Note on `tests/expected/`:** it is a hand-written style reference on a simple
`users` schema. The demo runs on the gen-sdk `music_catalogue` fixture (different
schema), so `diff -r tests/expected/ tests/output/` will NOT match byte-for-byte —
`expected/` documents the desired style, not a byte target for the demo.

## Reference Implementations

- rust.gen: https://github.com/pgenie-io/rust.gen
- java.gen: https://github.com/pgenie-io/java.gen
- haskell.gen: https://github.com/pgenie-io/haskell.gen
- gen-sdk: https://github.com/pgenie-io/gen-sdk
