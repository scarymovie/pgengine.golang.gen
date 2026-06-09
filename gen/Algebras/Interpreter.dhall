-- Algebra for interpreter modules
-- Defines the common structure for all interpreters
let Deps = ../Deps/package.dhall

let Config =
      { rootModuleName : Text
      , packageName : Text
      , generateTests : Bool
      , emitGoMod : Bool
      }

let module =
      \(Input : Type) ->
      \(Output : Type) ->
        let Result = Deps.Lude.Compiled.Type Output

        let Run = Config -> Input -> Result

        in  \(run : Run) -> { Input, Output, Result, Run, run }

in  { Config, module }
