# golang.gen

Go code generator for [pGenie](https://github.com/pgenie-io/pgenie) - generates type-safe Go code for PostgreSQL queries.

## Features

- **pgx-only**: Uses `github.com/jackc/pgx/v5` - the best PostgreSQL driver for Go
- **SQL-first**: Write SQL, get type-safe Go code - no ORM, no query builders
- **Minimal abstractions**: Simple `Querier` interface with clean API
- **Native types**: Public API uses plain Go types and pointers — no third-party deps in signatures
- **Transaction support**: Works with both `pgx.Conn` and `pgx.Tx` via `DBTX` interface

## Installation

Install the [pGenie CLI (`pgn`)](https://pgenie.io/docs/guides/installation/),
then reference this generator in your project's `project1.pgn.yaml`:

```yaml
space: my_space
name: my_project
version: 1.0.0
postgres: 18

artifacts:
  go: https://github.com/scarymovie/pgengine.golang.gen/releases/download/v0.2.0/resolved.dhall
```

Each release ships `resolved.dhall` — a frozen, self-contained Dhall package
with all imports resolved, so generation needs no extra network fetches. For
the development version use
`https://github.com/scarymovie/pgengine.golang.gen/raw/main/gen/Gen.dhall`
or a local path to `gen/Gen.dhall`.

## Quick Start

### 1. Write SQL

A pGenie project is plain SQL: `migrations/*.sql` for the schema and one
parameterized query per file in `queries/*.sql` (see
[pgenie-io/demo](https://github.com/pgenie-io/demo)):

```sql
-- queries/get_user.sql
select id, name, email, bio, created_at
from users
where id = :id
```

### 2. Generate Go code

```bash
pgn generate
```

pGenie validates the schema and queries against a real PostgreSQL instance,
infers parameter and result types (including nullability and cardinality)
and emits the Go package into `artifacts/go/`.

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

## Result Cardinality

pGenie infers the result shape from the query itself; the generated method
signature follows it:

| Result | Go signature |
|--------|--------------|
| Single row | `(Row, error)` — error if not found |
| Optional row | `(*Row, error)` — `nil` if not found |
| Multiple rows | `([]Row, error)` |
| Rows affected | `(int64, error)` |
| Void | `error` |

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
| `uuid`, `numeric`, `inet`, `cidr`, `interval`, `macaddr`, `timetz`, `ltree` | `string` | `*string` |

Arrays map to slices (`[]T` per dimension, nullable element → `[]*T`).
Types with no native Go equivalent (`uuid`, `numeric`, `inet`, ...) are exposed
as their canonical text form (`string`); pgx scans and encodes them directly,
the few types whose binary codec can't (`inet`/`cidr`/`interval`) are fetched
in text format automatically. Other PostgreSQL types are currently unsupported
and produce a generation error.

With `useGoogleUuid: true` the `uuid` type maps to `uuid.UUID` / `*uuid.UUID`
from [github.com/google/uuid](https://github.com/google/uuid) instead (pgx
handles `[16]byte`-based types natively, arrays included); the other
text-form types are unaffected.

## Configuration

All keys are optional (`config` may be omitted entirely):

```yaml
artifacts:
  go:
    gen: https://github.com/scarymovie/pgengine.golang.gen/releases/download/v0.2.0/resolved.dhall
    config:
      packageName: db    # Go package name (default: project name)
      emitGoMod: true    # emit go.mod, making the artifact a standalone
                         # module (default: true); set false to vendor the
                         # package into an existing module
      useGoogleUuid: false  # map uuid columns to uuid.UUID from
                            # github.com/google/uuid instead of string
                            # (default: false — keeps the public API free
                            # of third-party types)
```

## Generated Code Structure

```
artifacts/go/
├── go.mod          # optional (emitGoMod), standalone module
├── db.go           # DBTX interface, Queries struct
├── models.go       # Custom types (enums, composites, domains) + RegisterTypes
└── queries.sql.go  # Generated query methods
```

If the schema defines custom types, call the generated
`RegisterTypes(ctx, conn)` once per connection (e.g. in `AfterConnect`) so pgx
can encode and scan them.

## Wiring the Artifact into Your Module

With the default `emitGoMod: true` the artifact is a standalone Go module.
Hook it up to your project with a workspace:

```bash
go work init . ./artifacts/go
```

or with a `replace` directive in your `go.mod`:

```
require my_space/my_project v0.0.0
replace my_space/my_project => ./artifacts/go
```

(the module path is `<space>/<packageName>` from your `project1.pgn.yaml`;
the version is arbitrary since the directory replacement overrides it)

With `emitGoMod: false` only package sources are emitted — point the artifact
output into a subdirectory of your module and import it as a regular internal
package.

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

## Testing

Requirements: docker, go, git — everything else runs in containers.

```bash
make check   # dhall type-check + type-mapping unit tests
make demo    # generate from the local fixture, go vet the output
make e2e     # full pipeline: real pgn CLI + pgenie-io/demo project
             # + live PostgreSQL 18; compiles the artifact and runs queries
```

## Contributing

Issues and pull requests are welcome!

## License

MIT - see [LICENSE](LICENSE) for details.

## Related Projects

- [pGenie](https://github.com/pgenie-io/pgenie) - SQL-first code generation framework
- [pgx](https://github.com/jackc/pgx) - PostgreSQL driver for Go
- [rust.gen](https://github.com/pgenie-io/rust.gen) - Rust generator for pGenie
- [java.gen](https://github.com/pgenie-io/java.gen) - Java generator for pGenie
