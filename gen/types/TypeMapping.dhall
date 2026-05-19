-- Type mapping from PostgreSQL types to Go types
-- Handles primitive types, nullable types, and imports

let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall

-- Map PostgreSQL primitive types to Go types (NOT NULL)
let primitiveToGoType : Text -> Text
    = \(pgType : Text) ->
        let mapping =
              [ { pg = "bool", go = "bool" }
              , { pg = "int2", go = "int16" }
              , { pg = "int4", go = "int32" }
              , { pg = "int8", go = "int64" }
              , { pg = "float4", go = "float32" }
              , { pg = "float8", go = "float64" }
              , { pg = "text", go = "string" }
              , { pg = "varchar", go = "string" }
              , { pg = "char", go = "string" }
              , { pg = "bytea", go = "[]byte" }
              , { pg = "uuid", go = "pgtype.UUID" }
              , { pg = "date", go = "pgtype.Date" }
              , { pg = "timestamp", go = "time.Time" }
              , { pg = "timestamptz", go = "time.Time" }
              , { pg = "time", go = "pgtype.Time" }
              , { pg = "json", go = "[]byte" }
              , { pg = "jsonb", go = "[]byte" }
              , { pg = "inet", go = "netip.Addr" }
              , { pg = "cidr", go = "netip.Prefix" }
              , { pg = "macaddr", go = "net.HardwareAddr" }
              , { pg = "numeric", go = "pgtype.Numeric" }
              , { pg = "decimal", go = "pgtype.Numeric" }
              ]

        let found = Prelude.List.find { pg : Text, go : Text } (\(x : { pg : Text, go : Text }) -> x.pg == pgType) mapping

        in merge { Some = \(x : { pg : Text, go : Text }) -> x.go, None = "interface{}" } found

-- Make a type nullable using pgtype types
let makeNullablePgtype : Text -> Text
    = \(goType : Text) ->
        let mapping =
              [ { go = "bool", pgtype = "pgtype.Bool" }
              , { go = "int16", pgtype = "pgtype.Int2" }
              , { go = "int32", pgtype = "pgtype.Int4" }
              , { go = "int64", pgtype = "pgtype.Int8" }
              , { go = "float32", pgtype = "pgtype.Float4" }
              , { go = "float64", pgtype = "pgtype.Float8" }
              , { go = "string", pgtype = "pgtype.Text" }
              , { go = "time.Time", pgtype = "pgtype.Timestamp" }
              , { go = "pgtype.Date", pgtype = "pgtype.Date" }
              , { go = "pgtype.Time", pgtype = "pgtype.Time" }
              , { go = "pgtype.UUID", pgtype = "pgtype.UUID" }
              , { go = "pgtype.Numeric", pgtype = "pgtype.Numeric" }
              , { go = "netip.Addr", pgtype = "pgtype.Inet" }
              , { go = "netip.Prefix", pgtype = "pgtype.Cidr" }
              ]

        let found = Prelude.List.find { go : Text, pgtype : Text } (\(x : { go : Text, pgtype : Text }) -> x.go == goType) mapping

        in merge { Some = \(x : { go : Text, pgtype : Text }) -> x.pgtype, None = goType } found

-- Make a type nullable using pointers
let makeNullablePointer : Text -> Text
    = \(goType : Text) ->
        if Prelude.Text.contains "[]" goType
        then goType  -- slices are already nullable (nil)
        else "*${goType}"

-- Get required imports for a Go type
let getImportsForType : Text -> List Text
    = \(goType : Text) ->
        if Prelude.Text.contains "pgtype." goType
        then ["github.com/jackc/pgx/v5/pgtype"]
        else if Prelude.Text.contains "time.Time" goType
        then ["time"]
        else if Prelude.Text.contains "netip." goType
        then ["net/netip"]
        else if Prelude.Text.contains "net.HardwareAddr" goType
        then ["net"]
        else [] : List Text

in  { primitiveToGoType
    , makeNullablePgtype
    , makeNullablePointer
    , getImportsForType
    }
