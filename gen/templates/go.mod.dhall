-- Generate Go template for go.mod file
-- MVP: pgx-only, no transaction manager

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
-- Minimum Go version: 1.26
let defaultDependencies : List Text
    = [ "github.com/jackc/pgx/v5 v5.9.2"
      ]

let defaultGoVersion : Text = "1.26"

in  { generateGoMod
    , defaultDependencies
    , defaultGoVersion
    }
