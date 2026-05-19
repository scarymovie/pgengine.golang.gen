-- Type mapping from PostgreSQL types to Go types
-- Simplified version for MVP

-- Map PostgreSQL primitive types to Go types (NOT NULL)
-- For now, returns a default mapping - will be enhanced with gen-sdk integration
let primitiveToGoType =
    \(pgType : Text) -> "string"  -- Placeholder, will use gen-sdk types

-- Make a type nullable using pgtype types
let makeNullablePgtype =
    \(goType : Text) -> "pgtype.Text"  -- Placeholder

-- Make a type nullable using pointers
let makeNullablePointer =
    \(goType : Text) -> "*${goType}"

-- Get required imports for a Go type
-- Returns common imports for now
let getImportsForType =
    \(goType : Text) ->
        [ "github.com/jackc/pgx/v5/pgtype"
        , "time"
        ]

in  { primitiveToGoType
    , makeNullablePgtype
    , makeNullablePointer
    , getImportsForType
    }
