-- Maps a Member's Value to its Go type, import needs and a possible
-- unsupported-type error. Shared by Query.dhall (params, result rows) and
-- CustomType.dhall (composite members, domains).

let Deps = ../Deps/package.dhall

let Sdk = Deps.Sdk

let PrimMap = ./Primitive.dhall

let toPascal = Deps.CodegenKit.Name.toTextInPascal

let Info = { goType : Text, needsTime : Bool, err : Optional Text }

-- Primitive table entry extended with the pg type name (for error messages).
let scalarInfo =
      \(scalar : Sdk.Project.Scalar) ->
        merge
          { Primitive =
              \(p : Sdk.Project.Primitive) ->
                PrimMap.run p /\ { pgType = Sdk.Project.`Primitive/toText` p }
          , Custom =
              \(name : Sdk.Project.Name) ->
                { notNull = toPascal name
                , nullable = "*${toPascal name}"
                , needsTime = False
                , viaString = False
                , supported = True
                , pgType = ""
                }
          }
          scalar

-- Go type for a Value given outer nullability. Arrays become slices
-- ([]T per dimension); slices are already nilable, so a nullable array maps
-- to the same slice type, while a nullable element maps to a pointer element.
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
            , err =
                if    s.supported
                then  None Text
                else  Some "unsupported PostgreSQL type \"${s.pgType}\""
            }

-- The err message is unprefixed; callers add context (param/column/field name).
let forMember
    : Sdk.Project.Member -> Info
    = \(m : Sdk.Project.Member) -> forValue m.value m.isNullable

-- Struct field line shared by Params/Row/composite structs.
let field =
      \(m : Sdk.Project.Member) ->
        "\t${toPascal m.name} ${(forMember m).goType} `db:\"${m.pgName}\"`"

in  { Info, forValue, forMember, field }
