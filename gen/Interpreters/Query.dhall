-- Query interpreter: renders one SQL query into a Go body fragment
-- (SQL const + Params struct + Row struct + method) plus the import flags the
-- containing file needs. The file header/imports are assembled by Project.dhall.
let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Prelude = Deps.Prelude

let GoType = ./GoType.dhall

let Lude = Deps.Lude

let Input = Sdk.Project.Query

let Output =
      { body : Text
      , needsTime : Bool
      , needsUuid : Bool
      , needsErrors : Bool
      , needsPgx : Bool
      , needsTextFormats : Bool
      }

let anyNeedsTime =
      \(g : Bool) ->
      \(members : List Sdk.Project.Member) ->
        Prelude.List.any
          Sdk.Project.Member
          (\(m : Sdk.Project.Member) -> (GoType.forMember g m).needsTime)
          members

let anyNeedsUuid =
      \(g : Bool) ->
      \(members : List Sdk.Project.Member) ->
        Prelude.List.any
          Sdk.Project.Member
          (\(m : Sdk.Project.Member) -> (GoType.forMember g m).needsUuid)
          members

let memberErrors =
      \(g : Bool) ->
      \(label : Text) ->
      \(members : List Sdk.Project.Member) ->
        Prelude.List.unpackOptionals
          Text
          ( Prelude.List.map
              Sdk.Project.Member
              (Optional Text)
              ( \(m : Sdk.Project.Member) ->
                  merge
                    { None = None Text
                    , Some =
                        \(e : Text) -> Some "${label} \"${m.pgName}\": ${e}"
                    }
                    (GoType.forMember g m).err
              )
              members
          )

let buildSQL =
      \(fragments : Sdk.Project.QueryFragments) ->
        Prelude.Text.concatMap
          Sdk.Project.QueryFragment
          ( \(f : Sdk.Project.QueryFragment) ->
              merge
                { Sql = \(s : Text) -> s
                , Var =
                    \(v : Sdk.Project.Var) ->
                      "\$" ++ Natural/show (v.paramIndex + 1)
                }
                f
          )
          fragments

let buildParamArgs =
      \(params : List Sdk.Project.Member) ->
        Prelude.Text.concatMapSep
          ", "
          Sdk.Project.Member
          (\(m : Sdk.Project.Member) -> "params.${m.name.inPascalCase}")
          params

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let g = config.useGoogleUuid

        let memberField = GoType.field g

        let name = input.name.inPascalCase

        let sqlConst = "${input.name.inCamelCase}SQL"

        let sql = buildSQL input.fragments

        let hasParams =
              Prelude.Bool.not
                (Prelude.List.null Sdk.Project.Member input.params)

        let paramFields =
              Prelude.Text.concatMapSep
                "\n"
                Sdk.Project.Member
                memberField
                input.params

        let paramsStruct =
              if    hasParams
              then  ''
                    type ${name}Params struct {
                    ${paramFields}
                    }

                    ''
              else  ""

        let paramDecl = if hasParams then ", params ${name}Params" else ""

        let paramArgs =
              if hasParams then ", " ++ buildParamArgs input.params else ""

        let paramsNeedTime = anyNeedsTime g input.params

        let resultColumns =
              merge
                { Void = [] : List Sdk.Project.Member
                , RowsAffected = [] : List Sdk.Project.Member
                , Rows =
                    \(rows : Sdk.Project.ResultRows) ->
                      Prelude.NonEmpty.toList Sdk.Project.Member rows.columns
                }
                input.result

        let typeErrors =
                memberErrors g "param" input.params
              # memberErrors g "column" resultColumns

        let needsTextFormats =
              Prelude.List.any
                Sdk.Project.Member
                ( \(m : Sdk.Project.Member) ->
                    (GoType.forMember g m).needsTextFormat
                )
                resultColumns

        let needsUuid = anyNeedsUuid g (input.params # resultColumns)

        let formatsArg = if needsTextFormats then ", forceTextFormats" else ""

        let resultPart =
              merge
                { Void =
                  { method =
                      ''
                      func (q *Queries) ${name}(ctx context.Context${paramDecl}) error {
                      	_, err := q.db.Exec(ctx, ${sqlConst}${paramArgs})
                      	return err
                      }
                      ''
                  , rowStruct = ""
                  , needsTime = False
                  , needsErrors = False
                  , needsPgx = False
                  }
                , RowsAffected =
                  { method =
                      ''
                      func (q *Queries) ${name}(ctx context.Context${paramDecl}) (int64, error) {
                      	tag, err := q.db.Exec(ctx, ${sqlConst}${paramArgs})
                      	if err != nil {
                      		return 0, err
                      	}
                      	return tag.RowsAffected(), nil
                      }
                      ''
                  , rowStruct = ""
                  , needsTime = False
                  , needsErrors = False
                  , needsPgx = False
                  }
                , Rows =
                    \(rows : Sdk.Project.ResultRows) ->
                      let columns =
                            Prelude.NonEmpty.toList
                              Sdk.Project.Member
                              rows.columns

                      let rowFields =
                            Prelude.Text.concatMapSep
                              "\n"
                              Sdk.Project.Member
                              memberField
                              columns

                      let rowStruct =
                            ''
                            type ${name}Row struct {
                            ${rowFields}
                            }

                            ''

                      let method =
                            merge
                              { Single =
                                  ''
                                  func (q *Queries) ${name}(ctx context.Context${paramDecl}) (${name}Row, error) {
                                  	rows, err := q.db.Query(ctx, ${sqlConst}${formatsArg}${paramArgs})
                                  	if err != nil {
                                  		return ${name}Row{}, err
                                  	}
                                  	return pgx.CollectOneRow(rows, pgx.RowToStructByName[${name}Row])
                                  }
                                  ''
                              , Optional =
                                  ''
                                  func (q *Queries) ${name}(ctx context.Context${paramDecl}) (*${name}Row, error) {
                                  	rows, err := q.db.Query(ctx, ${sqlConst}${formatsArg}${paramArgs})
                                  	if err != nil {
                                  		return nil, err
                                  	}
                                  	row, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[${name}Row])
                                  	if errors.Is(err, pgx.ErrNoRows) {
                                  		return nil, nil
                                  	}
                                  	if err != nil {
                                  		return nil, err
                                  	}
                                  	return &row, nil
                                  }
                                  ''
                              , Multiple =
                                  ''
                                  func (q *Queries) ${name}(ctx context.Context${paramDecl}) ([]${name}Row, error) {
                                  	rows, err := q.db.Query(ctx, ${sqlConst}${formatsArg}${paramArgs})
                                  	if err != nil {
                                  		return nil, err
                                  	}
                                  	return pgx.CollectRows(rows, pgx.RowToStructByName[${name}Row])
                                  }
                                  ''
                              }
                              rows.cardinality

                      let isOptional =
                            merge
                              { Optional = True
                              , Single = False
                              , Multiple = False
                              }
                              rows.cardinality

                      in  { method
                          , rowStruct
                          , needsTime = anyNeedsTime g columns
                          , needsErrors = isOptional
                          , needsPgx = True
                          }
                }
                input.result

        let body =
              ''
              const ${sqlConst} = `${sql}`

              ${paramsStruct}${resultPart.rowStruct}${resultPart.method}''

        in  if    Prelude.List.null Text typeErrors
            then  Lude.Compiled.applicative.pure
                    Output
                    { body
                    , needsTime = paramsNeedTime || resultPart.needsTime
                    , needsUuid
                    , needsErrors = resultPart.needsErrors
                    , needsPgx = resultPart.needsPgx
                    , needsTextFormats
                    }
            else  Lude.Compiled.err
                    Output
                    [ input.srcPath ]
                    (Prelude.Text.concatSep "; " typeErrors)

in  Algebra.module Input Output run
