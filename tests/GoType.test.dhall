-- Unit tests for the Member/Value -> Go type mapping.
-- Evaluate with: dhall --file tests/GoType.test.dhall
-- (asserts fail the evaluation on mismatch)
let Deps = ../gen/Deps/package.dhall

let Sdk = Deps.Sdk

let GoType = ../gen/Interpreters/GoType.dhall

let P = Sdk.Project.Primitive

let value =
      \(p : P) ->
      \(arr : Optional Sdk.Project.ArraySettings) ->
        { arraySettings = arr, scalar = Sdk.Project.Scalar.Primitive p }

let noArr = None Sdk.Project.ArraySettings

let dim =
      \(n : Natural) ->
      \(elemNull : Bool) ->
        Some { dimensionality = n, elementIsNullable = elemNull }

let notNullText =
      assert : (GoType.forValue (value P.Text noArr) False).goType === "string"

let nullableText =
      assert : (GoType.forValue (value P.Text noArr) True).goType === "*string"

let textArray =
        assert
      :     (GoType.forValue (value P.Text (dim 1 False)) False).goType
        ===  "[]string"

let nullableArrayIsStillSlice =
        assert
      :     (GoType.forValue (value P.Int4 (dim 2 False)) True).goType
        ===  "[][]int32"

let nullableElement =
        assert
      :     (GoType.forValue (value P.Text (dim 1 True)) False).goType
        ===  "[]*string"

let unsupportedReportsErr =
        assert
      :     (GoType.forValue (value P.Tsvector noArr) False).err
        ===  Some "unsupported PostgreSQL type \"tsvector\""

let supportedHasNoErr =
      assert : (GoType.forValue (value P.Text noArr) False).err === None Text

let ltreeIsViaString =
      assert : (GoType.forValue (value P.Ltree noArr) False).goType === "string"

let dateNeedsTime =
      assert : (GoType.forValue (value P.Date noArr) False).needsTime === True

let inetNeedsTextFormat =
        assert
      : (GoType.forValue (value P.Inet noArr) False).needsTextFormat === True

let intervalArrayNeedsTextFormat =
        assert
      :     ( GoType.forValue (value P.Interval (dim 1 False)) False
            ).needsTextFormat
        ===  True

let uuidScansDirectly =
        assert
      : (GoType.forValue (value P.Uuid noArr) False).needsTextFormat === False

in  "ok"
