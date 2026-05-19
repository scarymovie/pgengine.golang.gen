-- Project interpreter - main entry point for code generation
-- Processes Project.Project type from gen-sdk and generates Go files

let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Project = Deps.Project

let Input = Project.Project

let Output = List Sdk.File.Type

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        -- TODO: Process queries and custom types
        -- For now, return empty list wrapped in Compiled
        Sdk.Compiled.applicative.pure
          (List Sdk.File.Type)
          ([] : List Sdk.File.Type)

in  Algebra.module Input Output run
