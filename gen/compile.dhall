-- Main compilation logic that ties everything together
-- Processes Project from gen-sdk and generates Go code

let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

let Project = Deps.Project

let Config = ./Config.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

in  \(config : Optional Config.Type) ->
    \(project : Project.Project) ->
      let interpreterConfig =
            { rootModuleName = Deps.CodegenKit.Name.toTextInSnake project.name
            , packageName =
                merge
                  { None = None Text
                  , Some = \(c : Config.Type) -> c.packageName
                  }
                  config
            , generateTests =
                merge
                  { None = False
                  , Some = \(c : Config.Type) -> c.generateTests
                  }
                  config
            }

      in  ProjectInterpreter.run interpreterConfig project
