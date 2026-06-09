-- Hand-written demo Project (gen-sdk contract 3.0 model).
-- Replaces the SDK's built-in fixtures (removed in gen-sdk v0.10; the
-- remaining Exhaustive fixture needs the unreleased Text/equal builtin).
--
-- Covers: all cardinalities (Single/Optional/Multiple) + Void + RowsAffected,
-- nullable -> pointer, arrays, custom types (enum/composite/domain),
-- viaString (uuid) and forced text format (inet/interval).
let Deps = ../../gen/Deps/package.dhall

let P = Deps.Sdk.Project

let name =
      \(snake : Text) ->
      \(pascal : Text) ->
      \(camel : Text) ->
        { inSnakeCase = snake
        , inPascalCase = pascal
        , inCamelCase = camel
        , inKebabCase = snake
        , inTrainCase = pascal
        , inScreamingKebabCase = snake
        , inScreamingSnakeCase = snake
        , inCamelSnakeCase = camel
        }

let scalar =
      \(p : P.Primitive) ->
        { arraySettings = None P.ArraySettings, scalar = P.Scalar.Primitive p }

let array1 =
      \(p : P.Primitive) ->
        { arraySettings = Some { dimensionality = 1, elementIsNullable = False }
        , scalar = P.Scalar.Primitive p
        }

let custom =
      \(n : P.Name) ->
        { arraySettings = None P.ArraySettings, scalar = P.Scalar.Custom n }

let member =
      \(n : P.Name) ->
      \(pgName : Text) ->
      \(isNullable : Bool) ->
      \(value : P.Value) ->
        { name = n, pgName, isNullable, value }

let albumFormatName = name "album_format" "AlbumFormat" "albumFormat"

let trackInfoName = name "track_info" "TrackInfo" "trackInfo"

let scoreName = name "score" "Score" "score"

let idMember = member (name "id" "Id" "id") "id" False (scalar P.Primitive.Int8)

let nameMember =
      member (name "name" "Name" "name") "name" False (scalar P.Primitive.Text)

let releasedMember =
      member
        (name "released" "Released" "released")
        "released"
        True
        (scalar P.Primitive.Date)

let formatMember =
      member
        (name "format" "Format" "format")
        "format"
        True
        (custom albumFormatName)

let ridMember =
      member (name "rid" "Rid" "rid") "rid" False (scalar P.Primitive.Uuid)

let var =
      \(n : P.Name) ->
      \(rawName : Text) ->
      \(paramIndex : Natural) ->
        P.QueryFragment.Var { name = n, rawName, paramIndex }

let sql = P.QueryFragment.Sql

let insertAlbum =
      { name = name "insert_album" "InsertAlbum" "insertAlbum"
      , srcPath = "./queries/insert_album.sql"
      , identity = False
      , idempotent = False
      , params =
        [ nameMember
        , member
            (name "released" "Released" "released")
            "released"
            False
            (scalar P.Primitive.Date)
        , formatMember
        ]
      , result =
          P.Result.Rows
            { cardinality = P.ResultRowsCardinality.Single
            , columns = { head = idMember, tail = [] : List P.Member }
            }
      , fragments =
        [ sql "insert into album (name, released, format) values ("
        , var (name "name" "Name" "name") "name" 0
        , sql ", "
        , var (name "released" "Released" "released") "released" 1
        , sql ", "
        , var (name "format" "Format" "format") "format" 2
        , sql ") returning id"
        ]
      }

let selectAlbums =
      { name = name "select_albums" "SelectAlbums" "selectAlbums"
      , srcPath = "./queries/select_albums.sql"
      , identity = False
      , idempotent = True
      , params =
        [ member
            (name "tags" "Tags" "tags")
            "tags"
            False
            (array1 P.Primitive.Text)
        ]
      , result =
          P.Result.Rows
            { cardinality = P.ResultRowsCardinality.Multiple
            , columns =
              { head = idMember
              , tail =
                [ nameMember
                , releasedMember
                , formatMember
                , ridMember
                , member
                    (name "track" "Track" "track")
                    "track"
                    True
                    (custom trackInfoName)
                ]
              }
            }
      , fragments =
        [ sql
            "select id, name, released, format, rid, track from album where tags && "
        , var (name "tags" "Tags" "tags") "tags" 0
        ]
      }

let getAlbum =
      { name = name "get_album" "GetAlbum" "getAlbum"
      , srcPath = "./queries/get_album.sql"
      , identity = True
      , idempotent = True
      , params = [ idMember ]
      , result =
          P.Result.Rows
            { cardinality = P.ResultRowsCardinality.Optional
            , columns =
              { head = idMember, tail = [ nameMember, releasedMember ] }
            }
      , fragments =
        [ sql "select id, name, released from album where id = "
        , var (name "id" "Id" "id") "id" 0
        ]
      }

let selectNet =
      { name = name "select_net" "SelectNet" "selectNet"
      , srcPath = "./queries/select_net.sql"
      , identity = False
      , idempotent = True
      , params = [] : List P.Member
      , result =
          P.Result.Rows
            { cardinality = P.ResultRowsCardinality.Single
            , columns =
              { head =
                  member
                    (name "addr" "Addr" "addr")
                    "addr"
                    False
                    (scalar P.Primitive.Inet)
              , tail =
                [ member
                    (name "age" "Age" "age")
                    "age"
                    True
                    (scalar P.Primitive.Interval)
                ]
              }
            }
      , fragments = [ sql "select addr, age from host" ]
      }

let deleteAlbums =
      { name = name "delete_albums" "DeleteAlbums" "deleteAlbums"
      , srcPath = "./queries/delete_albums.sql"
      , identity = False
      , idempotent = False
      , params = [ formatMember ]
      , result = P.Result.RowsAffected
      , fragments =
        [ sql "delete from album where format = "
        , var (name "format" "Format" "format") "format" 0
        ]
      }

let touchAlbums =
      { name = name "touch_albums" "TouchAlbums" "touchAlbums"
      , srcPath = "./queries/touch_albums.sql"
      , identity = False
      , idempotent = False
      , params = [] : List P.Member
      , result = P.Result.Void
      , fragments = [ sql "update album set updated_at = now()" ]
      }

in    { space = name "my_space" "MySpace" "mySpace"
      , name = name "music_catalogue" "MusicCatalogue" "musicCatalogue"
      , version = { major = 1, minor = 0, patch = 1 }
      , customTypes =
        [ { name = albumFormatName
          , pgSchema = "public"
          , pgName = "album_format"
          , definition =
              P.CustomTypeDefinition.Enum
                [ { name = name "vinyl" "Vinyl" "vinyl", pgName = "Vinyl" }
                , { name = name "cd" "Cd" "cd", pgName = "CD" }
                ]
          }
        , { name = trackInfoName
          , pgSchema = "public"
          , pgName = "track_info"
          , definition =
              P.CustomTypeDefinition.Composite
                [ member
                    (name "title" "Title" "title")
                    "title"
                    True
                    (scalar P.Primitive.Text)
                , member
                    (name "duration" "Duration" "duration")
                    "duration"
                    True
                    (scalar P.Primitive.Int4)
                , member
                    (name "tags" "Tags" "tags")
                    "tags"
                    True
                    (array1 P.Primitive.Text)
                ]
          }
        , { name = scoreName
          , pgSchema = "public"
          , pgName = "score"
          , definition = P.CustomTypeDefinition.Domain (scalar P.Primitive.Int4)
          }
        ]
      , queries =
        [ insertAlbum
        , selectAlbums
        , getAlbum
        , selectNet
        , deleteAlbums
        , touchAlbums
        ]
      , migrations = [] : List { name : Text, sql : Text }
      }
    : P.Project
