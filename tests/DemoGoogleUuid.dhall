-- Demo variant: same fixture as Demo.dhall, but with useGoogleUuid enabled,
-- so uuid columns map to github.com/google/uuid instead of string.
--
-- Generate the output tree with:
--   dhall to-directory-tree --file tests/DemoGoogleUuid.dhall --output tests/output-google --allow-path-separators
let Deps = ../gen/Deps/package.dhall

let Prelude = Deps.Prelude

let Gen = ../gen/Gen.dhall

let Config = ../gen/Config.dhall

let File = { path : Text, content : Text }

let Entry = { mapKey : Text, mapValue : Text }

let project = ./Fixtures/Demo.dhall

let compiled = Gen.compile (Some Config::{ useGoogleUuid = Some True }) project

let files =
      merge
        { Err = \(_ : { message : Text, path : List Text }) -> [] : List File
        , Ok = \(fs : List File) -> fs
        }
        compiled.result

in  Prelude.List.map
      File
      Entry
      (\(f : File) -> { mapKey = f.path, mapValue = f.content })
      files
