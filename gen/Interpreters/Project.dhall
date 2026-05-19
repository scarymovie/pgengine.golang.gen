-- Project interpreter - main entry point for code generation
-- Processes Project.Project type from gen-sdk and generates Go files

let Deps = ../Deps/package.dhall

let Sdk = Deps.Sdk

let Project = Deps.Project

let Config =
      { rootModuleName : Text
      , packageName : Optional Text
      , generateTests : Bool
      }

let Input = Project.Project

let Output = List Sdk.File.Type

let run =
      \(config : Config) ->
      \(input : Input) ->
        -- TODO: Process queries and custom types
        -- For now, return empty list
        [] : List Sdk.File.Type

in  { Config, Input, Output, run }
