# golang.gen

Go code generator for [pGenie](https://github.com/pgenie-io/pgenie) - generates type-safe Go code for PostgreSQL queries.

## Features

- **pgx-only**: Uses `github.com/jackc/pgx/v5` - the best PostgreSQL driver for Go
- **SQL-first**: Write SQL, get type-safe Go code - no ORM, no query builders
- **Minimal abstractions**: Simple `Querier` interface with clean API
- **Native types**: Public API uses plain Go types and pointers — no third-party deps in signatures
- **Transaction support**: Works with both `pgx.Conn` and `pgx.Tx` via `DBTX` interface

## Installation

```bash
# Install pGenie CLI
npm install -g pgenie

# Add this generator to your project
pgenie add generator golang
```

## Quick Start

### 1. Write SQL queries

Create a `queries.sql` file:

```sql
-- name: GetUser :one
SELECT id, name, email, bio, created_at
FROM users
WHERE id = $1;

-- name: ListUsers :many
SELECT id, name, email
FROM users
ORDER BY id;

-- name: CreateUser :one
INSERT INTO users (name, email)
VALUES ($1, $2)
RETURNING id, name, email, bio, created_at;
```

### 2. Generate Go code

```bash
pgenie generate
```

### 3. Use generated code

```go
package main

import (
    "context"
    "log"

    "github.com/jackc/pgx/v5"
    "your-module/generated/db"
)

func main() {
    ctx := context.Background()
    
    conn, err := pgx.Connect(ctx, "postgres://localhost/mydb")
    if err != nil {
        log.Fatal(err)
    }
    defer conn.Close(ctx)

    queries := db.New(conn)

    // Get a single user
    user, err := queries.GetUser(ctx, db.GetUserParams{ID: 1})
    if err != nil {
        log.Fatal(err)
    }
    log.Printf("User: %+v", user)

    // List all users
    users, err := queries.ListUsers(ctx)
    if err != nil {
        log.Fatal(err)
    }
    log.Printf("Users: %+v", users)

    // Create a user
    newUser, err := queries.CreateUser(ctx, db.CreateUserParams{
        Name:  "Alice",
        Email: "alice@example.com",
    })
    if err != nil {
        log.Fatal(err)
    }
    log.Printf("Created: %+v", newUser)
}
```

## Transaction Support

The generated code works seamlessly with transactions:

```go
func transferMoney(ctx context.Context, conn *pgx.Conn, from, to int64, amount int) error {
    tx, err := conn.Begin(ctx)
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)

    queries := db.New(conn).WithTx(tx)

    // Deduct from sender
    if err := queries.DeductBalance(ctx, db.DeductBalanceParams{
        UserID: from,
        Amount: amount,
    }); err != nil {
        return err
    }

    // Add to receiver
    if err := queries.AddBalance(ctx, db.AddBalanceParams{
        UserID: to,
        Amount: amount,
    }); err != nil {
        return err
    }

    return tx.Commit(ctx)
}
```

## Query Annotations

### Result Cardinality

- `:one` - Returns a single row (error if not found)
- `:many` - Returns a slice of rows (empty slice if none)
- `:exec` - Executes query without returning rows

### Examples

```sql
-- name: GetUser :one
-- Returns: (User, error)
-- Error if no rows found
SELECT * FROM users WHERE id = $1;

-- name: FindUser :one
-- Returns: (*User, error)
-- nil if no rows found (optional)
SELECT * FROM users WHERE email = $1;

-- name: ListUsers :many
-- Returns: ([]User, error)
-- Empty slice if no rows
SELECT * FROM users;

-- name: DeleteUser :exec
-- Returns: error
DELETE FROM users WHERE id = $1;
```

## Type Mapping

The public API uses **only native Go types** — nullable columns become pointers,
and there are no third-party dependencies in generated signatures.

| PostgreSQL Type | NOT NULL | Nullable |
|----------------|----------|----------|
| `bool` | `bool` | `*bool` |
| `int2`, `smallint` | `int16` | `*int16` |
| `int4`, `integer` | `int32` | `*int32` |
| `int8`, `bigint` | `int64` | `*int64` |
| `float4`, `real` | `float32` | `*float32` |
| `float8`, `double precision` | `float64` | `*float64` |
| `text`, `varchar` | `string` | `*string` |
| `oid` | `uint32` | `*uint32` |
| `date`, `time`, `timestamp`, `timestamptz` | `time.Time` | `*time.Time` |
| `bytea` | `[]byte` | `[]byte` |
| `json`, `jsonb` | `[]byte` | `[]byte` |
| `uuid`, `numeric`, `inet`, `cidr`, `interval` | `string` | `*string` |

Types with no native Go equivalent (`uuid`, `numeric`, `inet`, ...) are exposed
as a canonical `string`: scanned into a `pgtype.*` field internally and converted,
so `pgtype` never leaks into a public signature. Other PostgreSQL types are
currently unsupported and produce a generation error.

## Configuration

Create a `pgenie.dhall` file:

```dhall
let Config = https://raw.githubusercontent.com/pgenie-io/golang.gen/main/gen/Config.dhall

in Config::{
  , packageName = Some "db"
  , generateTests = False
}
```

## Generated Code Structure

```
generated/
├── go.mod
├── db.go           # DBTX interface, Queries struct
├── models.go       # Custom types (enums, composites)
└── queries.sql.go  # Generated query methods
```

## Why pgx-only?

- **Best PostgreSQL driver**: Native support for PostgreSQL features
- **Better performance**: No `database/sql` overhead
- **Rich types**: `pgtype` handles all PostgreSQL types internally (kept out of the public API)
- **Modern API**: Context support, better error handling
- **Active development**: Regular updates and improvements

## Comparison with sqlc

This generator is inspired by [sqlc](https://sqlc.dev/) but focuses exclusively on PostgreSQL with pgx:

| Feature | golang.gen | sqlc |
|---------|-----------|------|
| PostgreSQL support | ✅ pgx-only | ✅ Multiple drivers |
| MySQL support | ❌ | ✅ |
| SQLite support | ❌ | ✅ |
| Type safety | ✅ native types + pointers | ✅ sql.Null* |
| Query validation | ✅ pGenie | ✅ Built-in |
| Code generation | ✅ Dhall | ✅ Go |

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

GPL-3.0 - see [LICENSE](LICENSE) for details.

## Related Projects

- [pGenie](https://github.com/pgenie-io/pgenie) - SQL-first code generation framework
- [pgx](https://github.com/jackc/pgx) - PostgreSQL driver for Go
- [rust.gen](https://github.com/pgenie-io/rust.gen) - Rust generator for pGenie
- [java.gen](https://github.com/pgenie-io/java.gen) - Java generator for pGenie
