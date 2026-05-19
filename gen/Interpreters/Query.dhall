-- Query interpreter - processes individual SQL queries
-- Converts Project.Query to Go query methods

let Deps = ../Deps/package.dhall

let Prelude = Deps.Prelude

let Lude = Deps.Lude

let Project = Deps.Project

let Config =
      { rootModuleName : Text
      , packageName : Optional Text
      , generateTests : Bool
      }

let Input = Project.Query

let Output =
      { queryName : Text
      , queryPath : Text
      , queryContent : Text
      }

let run =
      \(config : Config) ->
      \(input : Input) ->
        let queryName = Lude.Name.toTextInSnake input.name

        let queryPath = "queries/${queryName}.go"

        let queryContent = "// TODO: Generate query method for ${queryName}"

        in  Lude.Compiled.pure
              Output
              { queryName, queryPath, queryContent }

in  { Config, Input, Output, run }
