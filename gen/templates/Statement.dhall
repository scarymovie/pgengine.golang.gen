-- Generate Go query execution functions based on cardinality
-- MVP: Querier interface, pgx v5, minimal abstractions

let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall

-- Cardinality types: Optional, Single, Multiple
let Cardinality = < Optional | Single | Multiple >

-- Generate function for Optional cardinality (can return nil without error)
let generateOptionalFunction : Text -> Text -> List Text -> List Text -> Text
    = \(functionName : Text) -> \(sql : Text) -> \(inputFields : List Text) -> \(outputFields : List Text) ->
        let hasInput = Prelude.List.null Text inputFields == False
        let inputParam = if hasInput then ", params ${functionName}Params" else ""
        let queryArgs = if hasInput then ", " ++ Prelude.Text.concatSep ", " (Prelude.List.map Text Text (\(f : Text) -> "params.${f}") inputFields) else ""

        in ''
func (q *Queries) ${functionName}(ctx context.Context${inputParam}) (*${functionName}Row, error) {
	rows, err := q.db.Query(ctx, ${functionName}SQL${queryArgs})
	if err != nil {
		return nil, err
	}

	row, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[${functionName}Row])
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil  // Optional: no row is not an error
		}
		return nil, err
	}

	return &row, nil
}
''

-- Generate function for Single cardinality (must return exactly one row)
let generateSingleFunction : Text -> Text -> List Text -> List Text -> Text
    = \(functionName : Text) -> \(sql : Text) -> \(inputFields : List Text) -> \(outputFields : List Text) ->
        let hasInput = Prelude.List.null Text inputFields == False
        let inputParam = if hasInput then ", params ${functionName}Params" else ""
        let queryArgs = if hasInput then ", " ++ Prelude.Text.concatSep ", " (Prelude.List.map Text Text (\(f : Text) -> "params.${f}") inputFields) else ""

        in ''
func (q *Queries) ${functionName}(ctx context.Context${inputParam}) (${functionName}Row, error) {
	rows, err := q.db.Query(ctx, ${functionName}SQL${queryArgs})
	if err != nil {
		return ${functionName}Row{}, err
	}

	return pgx.CollectOneRow(rows, pgx.RowToStructByName[${functionName}Row])
}
''

-- Generate function for Multiple cardinality (returns slice)
let generateMultipleFunction : Text -> Text -> List Text -> List Text -> Text
    = \(functionName : Text) -> \(sql : Text) -> \(inputFields : List Text) -> \(outputFields : List Text) ->
        let hasInput = Prelude.List.null Text inputFields == False
        let inputParam = if hasInput then ", params ${functionName}Params" else ""
        let queryArgs = if hasInput then ", " ++ Prelude.Text.concatSep ", " (Prelude.List.map Text Text (\(f : Text) -> "params.${f}") inputFields) else ""

        in ''
func (q *Queries) ${functionName}(ctx context.Context${inputParam}) ([]${functionName}Row, error) {
	rows, err := q.db.Query(ctx, ${functionName}SQL${queryArgs})
	if err != nil {
		return nil, err
	}

	return pgx.CollectRows(rows, pgx.RowToStructByName[${functionName}Row])
}
''

in  { Cardinality
    , generateOptionalFunction
    , generateSingleFunction
    , generateMultipleFunction
    }
