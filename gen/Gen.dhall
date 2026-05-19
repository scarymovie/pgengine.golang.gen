-- Main entry point for the Go generator
-- Implements the gen-sdk module interface
-- MVP: pgx-only, SQL-first, minimal abstractions

let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

let Config = (./Config.dhall).Type

in  Sdk.module { major = 1, minor = 0 } Config ./compile.dhall
