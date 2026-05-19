-- Generate Go template for go.mod file

let generateGoMod : Text -> Text -> List Text -> Text
    = \(moduleName : Text) -> \(goVersion : Text) -> \(dependencies : List Text) ->
        let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall

        let depsBlock =
            if Prelude.List.null Text dependencies
            then ""
            else ''

require (
	${Prelude.Text.concatSep "\n\t" dependencies}
)
''

        in ''
module ${moduleName}

go ${goVersion}
${depsBlock}
''

-- Default dependencies for pgx v5 (minimal, MVP)
let defaultDependencies : List Text
    = [ "github.com/jackc/pgx/v5 v5.5.5"
      ]

in  { generateGoMod
    , defaultDependencies
    }
