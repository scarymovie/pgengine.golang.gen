-- Generate Go template for Row structs (query results)
-- MVP: Simple row structs with db tags

let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall

-- Generate Row struct for a query
let generateRowStruct : Text -> List { name : Text, goType : Text } -> Text
    = \(queryName : Text) -> \(columns : List { name : Text, goType : Text }) ->
        let structName = "${queryName}Row"

        let fields =
            Prelude.Text.concatSep "\n\t"
                (Prelude.List.map { name : Text, goType : Text } Text
                    (\(col : { name : Text, goType : Text }) ->
                        "${col.name} ${col.goType} `db:\"${col.name}\"`")
                    columns)

        in ''
type ${structName} struct {
	${fields}
}
''

in  { generateRowStruct
    }
