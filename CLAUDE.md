# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Go code generator for the pGenie ecosystem. The generator creates type-safe Go code for working with PostgreSQL based on SQL queries. It's part of the pgenie-io family of generators (similar to rust.gen, java.gen, haskell.gen).

## Architecture

### Generator Structure

The generator is written in Dhall and follows the pGenie gen-sdk contract:

- **gen/Gen.dhall** - Main entry point implementing the Sdk.module interface
- **gen/Config.dhall** - Configuration schema for generator options
- **gen/compile.dhall** - Core compilation logic
- **gen/types/** - PostgreSQL to Go type mapping logic
- **gen/statements/** - SQL statement to Go function generation
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

### Dhall Commands
```bash
# Validate Dhall syntax
dhall --file gen/Gen.dhall

# Type check
dhall type --file gen/Gen.dhall

# Format Dhall files
dhall format --inplace gen/**/*.dhall

# Freeze imports (pin versions)
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

### Dhall Dependencies
- **gen-sdk**: https://github.com/pgenie-io/gen-sdk - Core SDK with contract and API
- **Prelude**: https://prelude.dhall-lang.org/v21.1.0/package.dhall - Standard library

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

1. **Type Mapping** - PostgreSQL to Go type conversion using pgtype
2. **Querier Interface** - Generate interface with query methods
3. **Query Implementation** - Implement methods using `CollectRows`/`CollectOneRow`
4. **Cardinality Handling** - Optional/Single/Multiple result patterns
5. **Testing** - Fixtures, integration tests, compilation verification

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
