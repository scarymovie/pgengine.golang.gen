-- Main entry point for the Go generator
-- Implements the gen-sdk module interface (contract 3.0)
-- MVP: pgx-only, SQL-first, minimal abstractions
let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

let Config = (./Config.dhall).Type

in  Sdk.module Config ./compile.dhall
