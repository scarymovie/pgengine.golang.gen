-- Main compilation logic that ties everything together
-- Processes Project from gen-sdk and generates Go code
let Deps = ./Deps/package.dhall

let Prelude = Deps.Prelude

let Config = ./Config.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

let field =
      \(A : Type) ->
      \(get : Config.Type -> Optional A) ->
      \(def : A) ->
      \(config : Optional Config.Type) ->
        merge
          { None = def
          , Some =
              \(c : Config.Type) ->
                merge { None = def, Some = \(v : A) -> v } (get c)
          }
          config

in  \(config : Optional Config.Type) ->
    \(project : Deps.Sdk.Project.Project) ->
      let interpreterConfig =
            { rootModuleName = project.name.inSnakeCase
            , packageName =
                field
                  Text
                  (\(c : Config.Type) -> c.packageName)
                  project.name.inSnakeCase
                  config
            , generateTests =
                field Bool (\(c : Config.Type) -> c.generateTests) False config
            , emitGoMod =
                field Bool (\(c : Config.Type) -> c.emitGoMod) True config
            , useGoogleUuid =
                field Bool (\(c : Config.Type) -> c.useGoogleUuid) False config
            }

      in  ProjectInterpreter.run interpreterConfig project
