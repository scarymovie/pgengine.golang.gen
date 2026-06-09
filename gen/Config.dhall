-- Configuration schema for the Go generator.
-- All fields are Optional so that a partial config passed by pgn
-- (e.g. `config: { emitGoMod: false }` in project1.pgn.yaml) decodes;
-- defaults are applied in compile.dhall.
{ Type =
    { packageName : Optional Text
    , generateTests : Optional Bool
    , emitGoMod : Optional Bool
    }
, default =
  { packageName = None Text, generateTests = None Bool, emitGoMod = None Bool }
}
