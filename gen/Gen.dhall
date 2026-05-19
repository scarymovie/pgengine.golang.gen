-- Main entry point for the Go generator
-- Implements the gen-sdk module interface
-- MVP: pgx-only, SQL-first, minimal abstractions

let Sdk = https://raw.githubusercontent.com/pgenie-io/gen-sdk/master/dhall/package.dhall

let Config = ./Config.dhall
let compile = ./compile.dhall

-- Generator version following gen-sdk contract
-- major = 1, minor = 0 means we implement gen-sdk v1.0 contract
in Sdk.module
  { major = 1, minor = 0 }
  Config
  compile
