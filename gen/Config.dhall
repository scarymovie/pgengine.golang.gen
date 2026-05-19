-- Configuration schema for the Go generator
-- MVP: pgx-only, SQL-first, minimal abstractions

{ Type =
    { packageName : Optional Text
    , generateTests : Bool
    }
, default =
    { packageName = None Text
    , generateTests = False
    }
}
