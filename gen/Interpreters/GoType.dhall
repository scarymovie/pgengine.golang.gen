-- Maps a Member's Value to its Go type, import needs and a possible
-- unsupported-type error. Shared by Query.dhall (params, result rows) and
-- CustomType.dhall (composite members, domains).
let Deps = ../Deps/package.dhall

let Sdk = Deps.Sdk

let PrimMap = ./Primitive.dhall

let Info =
      { goType : Text
      , needsTime : Bool
      , needsTextFormat : Bool
      , err : Optional Text
      }

let scalarInfo =
      \(scalar : Sdk.Project.Scalar) ->
        merge
          { Primitive =
              \(p : Sdk.Project.Primitive) ->
                PrimMap.run p /\ { pgType = Sdk.Project.Primitive/toText p }
          , Custom =
              \(name : Sdk.Project.Name) ->
                { notNull = name.inPascalCase
                , nullable = "*${name.inPascalCase}"
                , needsTime = False
                , viaString = False
                , needsTextFormat = False
                , supported = True
                , pgType = ""
                }
          }
          scalar

let forValue
    : Sdk.Project.Value -> Bool -> Info
    = \(value : Sdk.Project.Value) ->
      \(isNullable : Bool) ->
        let s = scalarInfo value.scalar

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
            , needsTextFormat = s.needsTextFormat
            , err =
                if    s.supported
                then  None Text
                else  Some "unsupported PostgreSQL type \"${s.pgType}\""
            }

let forMember
    : Sdk.Project.Member -> Info
    = \(m : Sdk.Project.Member) -> forValue m.value m.isNullable

let field =
      \(m : Sdk.Project.Member) ->
        "\t${m.name.inPascalCase} ${(forMember m).goType} `db:\"${m.pgName}\"`"

in  { Info, forValue, forMember, field }
