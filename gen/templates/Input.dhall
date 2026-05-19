-- Generate Go template for Params structs (query parameters)
-- MVP: Simple params structs

let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall

-- Generate Params struct for a query
let generateParamsStruct : Text -> List { name : Text, goType : Text } -> Text
    = \(queryName : Text) -> \(params : List { name : Text, goType : Text }) ->
        if Prelude.List.null { name : Text, goType : Text } params
        then ""  -- No params struct needed if no parameters
        else
            let structName = "${queryName}Params"

            let fields =
                Prelude.Text.concatSep "\n\t"
                    (Prelude.List.map { name : Text, goType : Text } Text
                        (\(param : { name : Text, goType : Text }) ->
                            "${param.name} ${param.goType}")
                        params)

            in ''
type ${structName} struct {
	${fields}
}
''

in  { generateParamsStruct
    }
