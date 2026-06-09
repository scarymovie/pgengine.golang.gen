-- Demo: run the generator against the local demo fixture and expose the
-- result as a directory-tree map.
--
-- Generate the output tree with:
--   dhall to-directory-tree --file tests/Demo.dhall --output tests/output --allow-path-separators
let Deps = ../gen/Deps/package.dhall

let Prelude = Deps.Prelude

let Gen = ../gen/Gen.dhall

let File = { path : Text, content : Text }

let Entry = { mapKey : Text, mapValue : Text }

let project = ./Fixtures/Demo.dhall

let compiled = Gen.compile (None Gen.Config) project

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
