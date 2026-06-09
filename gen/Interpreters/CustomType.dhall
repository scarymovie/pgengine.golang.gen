-- CustomType interpreter: renders one PostgreSQL custom type (enum,
-- composite or domain) into a Go type definition for models.go.
--
--   enum      -> type X string + a const block with one constant per variant
--   composite -> type X struct { ... } with db tags (scanned via the codec
--                registered by RegisterTypes in models.go)
--   domain    -> type X = <underlying Go type> (transparent alias)
let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Prelude = Deps.Prelude

let GoType = ./GoType.dhall

let Lude = Deps.Lude

let Input = Sdk.Project.CustomType

let Output =
      { body : Text
      , needsTime : Bool
      , pgFullName : Text
      , pgArrayFullName : Text
      }

let memberErrors =
      \(members : List Sdk.Project.Member) ->
        Prelude.List.unpackOptionals
          Text
          ( Prelude.List.map
              Sdk.Project.Member
              (Optional Text)
              ( \(m : Sdk.Project.Member) ->
                  merge
                    { None = None Text
                    , Some = \(e : Text) -> Some "field \"${m.pgName}\": ${e}"
                    }
                    (GoType.forMember m).err
              )
              members
          )

let anyNeedsTime =
      \(members : List Sdk.Project.Member) ->
        Prelude.List.any
          Sdk.Project.Member
          (\(m : Sdk.Project.Member) -> (GoType.forMember m).needsTime)
          members

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let typeName = input.name.inPascalCase

        let pgFullName = "${input.pgSchema}.${input.pgName}"

        let pgArrayFullName = "${input.pgSchema}._${input.pgName}"

        let rendered =
              merge
                { Enum =
                    \(variants : List Sdk.Project.EnumVariant) ->
                      let constants =
                            Prelude.Text.concatMapSep
                              "\n"
                              Sdk.Project.EnumVariant
                              ( \(v : Sdk.Project.EnumVariant) ->
                                  "\t${typeName}${v.name.inPascalCase} ${typeName} = \"${v.pgName}\""
                              )
                              variants

                      in  { body =
                              ''
                              type ${typeName} string

                              const (
                              ${constants}
                              )
                              ''
                          , needsTime = False
                          , errors = [] : List Text
                          }
                , Composite =
                    \(members : List Sdk.Project.Member) ->
                      let fields =
                            Prelude.Text.concatMapSep
                              "\n"
                              Sdk.Project.Member
                              GoType.field
                              members

                      in  { body =
                              ''
                              type ${typeName} struct {
                              ${fields}
                              }
                              ''
                          , needsTime = anyNeedsTime members
                          , errors = memberErrors members
                          }
                , Domain =
                    \(value : Sdk.Project.Value) ->
                      let info = GoType.forValue value False

                      in  { body =
                              ''
                              type ${typeName} = ${info.goType}
                              ''
                          , needsTime = info.needsTime
                          , errors =
                              merge
                                { None = [] : List Text
                                , Some = \(e : Text) -> [ e ]
                                }
                                info.err
                          }
                }
                input.definition

        in  if    Prelude.List.null Text rendered.errors
            then  Lude.Compiled.applicative.pure
                    Output
                    { body = rendered.body
                    , needsTime = rendered.needsTime
                    , pgFullName
                    , pgArrayFullName
                    }
            else  Lude.Compiled.err
                    Output
                    [ pgFullName ]
                    (Prelude.Text.concatSep "; " rendered.errors)

in  Algebra.module Input Output run
