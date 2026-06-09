-- Maps Sdk.Project.Primitive to Go types.
--
-- Public API exposes only native Go types (no third-party deps):
--   * NOT NULL  -> native type        (string, int64, time.Time, ...)
--   * nullable  -> pointer            (*string, *int64, *time.Time, ...)
--     (slices like []byte are already nilable, so nullable == notNull)
--
-- Types without a natural Go equivalent (uuid, numeric, inet, ...) are
-- exposed as `string` (their canonical text form). pgx scans most of them
-- into string directly; the few whose binary codec cannot (inet, cidr,
-- interval) are requested in text format via pgx.QueryResultFormatsByOID
-- (needsTextFormat = True).
--
-- Unsupported types report a compile error via the caller (supported = False).
let Deps = ../Deps/package.dhall

let Input = Deps.Sdk.Project.Primitive

let Output =
      { notNull : Text
      , nullable : Text
      , needsTime : Bool
      , viaString : Bool
      , needsTextFormat : Bool
      , supported : Bool
      }

let native =
      \(t : Text) ->
        { notNull = t
        , nullable = "*${t}"
        , needsTime = False
        , viaString = False
        , needsTextFormat = False
        , supported = True
        }

let timeType =
      { notNull = "time.Time"
      , nullable = "*time.Time"
      , needsTime = True
      , viaString = False
      , needsTextFormat = False
      , supported = True
      }

let slice =
      \(t : Text) ->
        { notNull = t
        , nullable = t
        , needsTime = False
        , viaString = False
        , needsTextFormat = False
        , supported = True
        }

let viaStr =
      { notNull = "string"
      , nullable = "*string"
      , needsTime = False
      , viaString = True
      , needsTextFormat = False
      , supported = True
      }

let viaStrText = viaStr // { needsTextFormat = True }

let unsupported =
      \(name : Text) ->
        { notNull = ""
        , nullable = ""
        , needsTime = False
        , viaString = False
        , needsTextFormat = False
        , supported = False
        }

let run =
      \(input : Input) ->
        merge
          { Bit = unsupported "bit"
          , Bool = native "bool"
          , Box = unsupported "box"
          , Box2D = unsupported "box2d"
          , Box3D = unsupported "box3d"
          , Bpchar = native "string"
          , Bytea = slice "[]byte"
          , Char = unsupported "char"
          , Cidr = viaStrText
          , Circle = unsupported "circle"
          , Citext = native "string"
          , Date = timeType
          , Datemultirange = unsupported "datemultirange"
          , Daterange = unsupported "daterange"
          , Float4 = native "float32"
          , Float8 = native "float64"
          , Geography = unsupported "geography"
          , Geometry = unsupported "geometry"
          , Hstore = unsupported "hstore"
          , Inet = viaStrText
          , Int2 = native "int16"
          , Int4 = native "int32"
          , Int4multirange = unsupported "int4multirange"
          , Int4range = unsupported "int4range"
          , Int8 = native "int64"
          , Int8multirange = unsupported "int8multirange"
          , Int8range = unsupported "int8range"
          , Interval = viaStrText
          , Json = slice "[]byte"
          , Jsonb = slice "[]byte"
          , Line = unsupported "line"
          , Lseg = unsupported "lseg"
          , Ltree = viaStr
          , Macaddr = viaStr
          , Macaddr8 = viaStr
          , Money = unsupported "money"
          , Name = native "string"
          , Numeric = viaStr
          , Nummultirange = unsupported "nummultirange"
          , Numrange = unsupported "numrange"
          , Oid = native "uint32"
          , Path = unsupported "path"
          , PgLsn = unsupported "pg_lsn"
          , PgSnapshot = unsupported "pg_snapshot"
          , Point = unsupported "point"
          , Polygon = unsupported "polygon"
          , Text = native "string"
          , Time = timeType
          , Timestamp = timeType
          , Timestamptz = timeType
          , Timetz = viaStr
          , Tsmultirange = unsupported "tsmultirange"
          , Tsquery = unsupported "tsquery"
          , Tsrange = unsupported "tsrange"
          , Tstzmultirange = unsupported "tstzmultirange"
          , Tstzrange = unsupported "tstzrange"
          , Tsvector = unsupported "tsvector"
          , Uuid = viaStr
          , Varbit = unsupported "varbit"
          , Varchar = native "string"
          , Xml = unsupported "xml"
          }
          input

in  { Input, Output, run }
