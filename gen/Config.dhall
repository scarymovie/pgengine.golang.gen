-- Configuration schema for the Go generator
-- MVP: pgx-only, SQL-first, minimal abstractions

{ Type =
    { -- Custom package name for generated code
      -- Default: None (derived from project name)
      packageName : Optional Text
    , -- Generate test files for queries
      -- Default: False
      generateTests : Bool
    }
, default =
    { packageName = None Text
    , generateTests = False
    }
}
