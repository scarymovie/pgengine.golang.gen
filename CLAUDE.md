# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Go code generator for the pGenie ecosystem. The generator creates type-safe Go code for working with PostgreSQL based on SQL queries. It's part of the pgenie-io family of generators (similar to rust.gen, java.gen, haskell.gen).

## Architecture

### Generator Structure

The generator is written in Dhall and follows the pGenie gen-sdk contract:

- **gen/Gen.dhall** - Main entry point implementing the Sdk.module interface
- **gen/Config.dhall** - Configuration schema (Type + default)
- **gen/compile.dhall** - Core compilation logic
- **gen/Deps/** - External dependencies
  - Sdk.dhall - gen-sdk v1.0 (f45f4eca)
  - Project.dhall - Project types from gen-sdk
  - Prelude.dhall - Dhall Prelude v23.1.0
  - Lude.dhall - Utility library v1.0.0
  - CodegenKit.dhall - Name conversion utilities v0.3.0
- **gen/Interpreters/** - Code generation logic
  - Project.dhall - Main interpreter (Project → List Sdk.File)
  - Query.dhall - Query processor (Query → Go methods)
- **gen/types/** - PostgreSQL to Go type mapping logic
- **gen/templates/** - Dhall templates for generating Go code

### Generated Code Structure

The generator produces Go code with this structure:

```
generated/
├── go.mod
├── types/          # Custom types (enums, composites)
├── statements/     # Query functions
└── client.go       # Optional client wrapper
```

## Type Mapping

### PostgreSQL to Go Type Mapping

- **Primitives**: `int4` → `int32`, `int8` → `int64`, `text` → `string`, `bool` → `bool`
- **Nullable fields**: Use `pgtype` types (`pgtype.Text`, `pgtype.Int8`, `pgtype.Timestamp`, etc.)
- **UUID**: `pgtype.UUID` from `github.com/jackc/pgx/v5/pgtype`
- **Timestamps**: `pgtype.Timestamp` for nullable, `time.Time` for NOT NULL
- **JSON/JSONB**: `[]byte` or custom types with pgx codec
- **Arrays**: `[]T` where T is the element type
- **Enums**: Generated as Go string types with constants
- **Composites**: Generated as Go structs with pgx codec registration

### Result Cardinality

- **Optional**: Returns `*Output, error` (can be nil without error)
- **Single**: Returns `*Output, error` (nil only on error, ErrNotFound if no rows)
- **Multiple**: Returns `[]Output, error` (empty slice if no rows)

## Design Decisions - MVP Strategy

### Database Library
- **pgx-only**: Only `github.com/jackc/pgx/v5` - no database/sql, no ORM
- Best PostgreSQL driver with native support for arrays, jsonb, copy, ranges
- Direct pgx types, no compatibility layers

### API Style - Minimal Abstractions
- **Querier interface** - simple, clean API
- Methods accept `ctx` and typed params, return typed results
- No repository pattern, no transaction manager abstractions
- Example:
  ```go
  type Querier interface {
      GetUser(ctx context.Context, params GetUserParams) (User, error)
      ListUsers(ctx context.Context) ([]User, error)
  }
  ```

### SQL-First Approach
- Generate query methods directly from SQL
- No ORM, no query builders
- Just: queries → params → rows → scanners

### Nullable Fields
- Use `pgtype` types (`pgtype.Text`, `pgtype.Int8`, etc.) - native pgx support
- No pointers, no `sql.Null*` types

### Row Mapping
- Use `pgx.CollectRows` with `pgx.RowToStructByName[T]` for multiple rows
- Use `pgx.CollectOneRow` with `pgx.RowToStructByName[T]` for single row
- Structs use `db:"column_name"` tags for mapping

### Error Handling
- Return errors directly from pgx
- `pgx.ErrNoRows` for not found cases

## Development Commands

### Dhall Commands via Docker
```bash
# Helper script (recommended)
./dhall.sh type gen/Gen.dhall
./dhall.sh validate-all

# Direct Docker commands
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall type --file gen/Gen.dhall

# Format Dhall files
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall format --inplace gen/**/*.dhall

# Freeze imports (pin versions)
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall freeze --inplace gen/Gen.dhall
```

### Testing
```bash
# Run generator tests
dhall --file tests/Demo.dhall

# Compare generated output with expected
diff -r tests/expected/ tests/output/
```

## Key Dependencies

### Dhall Dependencies (gen/Deps/)
- **gen-sdk f45f4eca**: https://github.com/pgenie-io/gen-sdk - Core SDK with contract and API
- **Prelude v23.1.0**: Standard Dhall library
- **Lude v1.0.0**: Utility library for gen-sdk
- **CodegenKit v0.3.0**: Name conversion utilities (toTextInSnake, toTextInPascal, etc.)

### Generated Code Dependencies
- `github.com/jackc/pgx/v5` - PostgreSQL driver (core only, no pool/transaction manager)
- `github.com/jackc/pgx/v5/pgtype` - PostgreSQL types (for nullable fields)

## Reference Implementations

Study these existing generators for patterns and conventions:
- **rust.gen**: https://github.com/pgenie-io/rust.gen
- **java.gen**: https://github.com/pgenie-io/java.gen
- **haskell.gen**: https://github.com/pgenie-io/haskell.gen

## Configuration Options

The generator supports these configuration options in Config.dhall:

- `packageName`: Custom package name for generated code (default: derived from project)
- `generateTests`: Generate test files for queries (default: false)

## Implementation Phases

### Current Status: Phase 1 (WIP)

1. **✅ MVP Structure** - Project setup, documentation, examples
2. **🚧 gen-sdk Integration** - Deps/, Interpreters/ structure created
   - ❌ Sdk.module type mismatch (needs fixing)
   - ⏳ Project.dhall interpreter (placeholder)
   - ⏳ Query.dhall processor (placeholder)
3. **⏳ Type Mapping** - PostgreSQL to Go type conversion using pgtype
4. **⏳ Querier Interface** - Generate interface with query methods
5. **⏳ Query Implementation** - Implement methods using `CollectRows`/`CollectOneRow`
6. **⏳ Cardinality Handling** - Optional/Single/Multiple result patterns
7. **⏳ Testing** - Fixtures, integration tests, compilation verification

### Next Steps
1. Fix Sdk.module integration (understand expected return type)
2. Implement Project.dhall interpreter (process queries and custom types)
3. Create test fixtures (tests/Demo.dhall)
4. Generate first working Go code

## Generated Code Patterns

### Querier Interface
```go
type Querier interface {
    GetUser(ctx context.Context, params GetUserParams) (User, error)
    ListUsers(ctx context.Context) ([]User, error)
    CreateUser(ctx context.Context, params CreateUserParams) (User, error)
}
```

### Implementation
```go
type Queries struct {
    db DBTX
}

func New(db DBTX) *Queries {
    return &Queries{db: db}
}

func (q *Queries) GetUser(ctx context.Context, params GetUserParams) (User, error) {
    rows, err := q.db.Query(ctx, getUserSQL, params.ID)
    if err != nil {
        return User{}, err
    }
    return pgx.CollectOneRow(rows, pgx.RowToStructByName[User])
}
```

### DBTX Interface
```go
type DBTX interface {
    Query(ctx context.Context, sql string, args ...interface{}) (pgx.Rows, error)
    QueryRow(ctx context.Context, sql string, args ...interface{}) pgx.Row
    Exec(ctx context.Context, sql string, args ...interface{}) (pgconn.CommandTag, error)
}
```

### Struct with pgtype
```go
type User struct {
    ID        int64            `db:"id"`
    Name      string           `db:"name"`
    Email     string           `db:"email"`
    Bio       pgtype.Text      `db:"bio"`        // nullable
    DeletedAt pgtype.Timestamp `db:"deleted_at"` // nullable
}
```
