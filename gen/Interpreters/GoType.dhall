-- Maps a Member's Value to its Go type, import needs and a possible
-- unsupported-type error. Shared by Query.dhall (params, result rows) and
-- CustomType.dhall (composite members, domains).
--
-- All entry points take useGoogleUuid first: it selects the uuid mapping
-- (canonical-text string vs github.com/google/uuid) in Primitive.dhall.
let Deps = ../Deps/package.dhall

let Sdk = Deps.Sdk

let PrimMap = ./Primitive.dhall

let Info =
      { goType : Text
      , needsTime : Bool
      , needsUuid : Bool
      , needsTextFormat : Bool
      , err : Optional Text
      }

let scalarInfo =
      \(useGoogleUuid : Bool) ->
      \(scalar : Sdk.Project.Scalar) ->
        merge
          { Primitive =
              \(p : Sdk.Project.Primitive) ->
                    PrimMap.run useGoogleUuid p
                /\  { pgType = Sdk.Project.Primitive/toText p }
          , Custom =
              \(name : Sdk.Project.Name) ->
                { notNull = name.inPascalCase
                , nullable = "*${name.inPascalCase}"
                , needsTime = False
                , needsUuid = False
                , viaString = False
                , needsTextFormat = False
                , supported = True
                , pgType = ""
                }
          }
          scalar

let forValue
    : Bool -> Sdk.Project.Value -> Bool -> Info
    = \(useGoogleUuid : Bool) ->
      \(value : Sdk.Project.Value) ->
      \(isNullable : Bool) ->
        let s = scalarInfo useGoogleUuid value.scalar

        let goType =
              merge
                { None = if isNullable then s.nullable else s.notNull
                , Some =
                    \(arr : Sdk.Project.ArraySettings) ->
                      let element =
                            if    arr.elementIsNullable
                            then  s.nullable
                            else  s.notNull

                      in  Natural/fold
                            arr.dimensionality
                            Text
                            (\(t : Text) -> "[]${t}")
                            element
                }
                value.arraySettings

        in  { goType
            , needsTime = s.needsTime
            , needsUuid = s.needsUuid
            , needsTextFormat = s.needsTextFormat
            , err =
                if    s.supported
                then  None Text
                else  Some "unsupported PostgreSQL type \"${s.pgType}\""
            }

let forMember
    : Bool -> Sdk.Project.Member -> Info
    = \(useGoogleUuid : Bool) ->
      \(m : Sdk.Project.Member) ->
        forValue useGoogleUuid m.value m.isNullable

let field =
      \(useGoogleUuid : Bool) ->
      \(m : Sdk.Project.Member) ->
        "\t${m.name.inPascalCase} ${( forMember useGoogleUuid m
                                    ).goType} `db:\"${m.pgName}\"`"

in  { Info, forValue, forMember, field }
