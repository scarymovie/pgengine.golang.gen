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

let forValue = GoType.forValue False

let forValueGoogle = GoType.forValue True

let notNullText =
      assert : (forValue (value P.Text noArr) False).goType === "string"

let nullableText =
      assert : (forValue (value P.Text noArr) True).goType === "*string"

let textArray =
        assert
      : (forValue (value P.Text (dim 1 False)) False).goType === "[]string"

let nullableArrayIsStillSlice =
        assert
      : (forValue (value P.Int4 (dim 2 False)) True).goType === "[][]int32"

let nullableElement =
        assert
      : (forValue (value P.Text (dim 1 True)) False).goType === "[]*string"

let unsupportedReportsErr =
        assert
      :     (forValue (value P.Tsvector noArr) False).err
        ===  Some "unsupported PostgreSQL type \"tsvector\""

let supportedHasNoErr =
      assert : (forValue (value P.Text noArr) False).err === None Text

let ltreeIsViaString =
      assert : (forValue (value P.Ltree noArr) False).goType === "string"

let dateNeedsTime =
      assert : (forValue (value P.Date noArr) False).needsTime === True

let inetNeedsTextFormat =
      assert : (forValue (value P.Inet noArr) False).needsTextFormat === True

let intervalArrayNeedsTextFormat =
        assert
      :     (forValue (value P.Interval (dim 1 False)) False).needsTextFormat
        ===  True

let uuidScansDirectly =
      assert : (forValue (value P.Uuid noArr) False).needsTextFormat === False

let uuidDefaultsToString =
      assert : (forValue (value P.Uuid noArr) False).goType === "string"

let uuidDefaultNeedsNoImport =
      assert : (forValue (value P.Uuid noArr) False).needsUuid === False

let googleUuidNotNull =
        assert
      : (forValueGoogle (value P.Uuid noArr) False).goType === "uuid.UUID"

let googleUuidNullable =
        assert
      : (forValueGoogle (value P.Uuid noArr) True).goType === "*uuid.UUID"

let googleUuidArray =
        assert
      :     (forValueGoogle (value P.Uuid (dim 1 False)) False).goType
        ===  "[]uuid.UUID"

let googleUuidNullableElement =
        assert
      :     (forValueGoogle (value P.Uuid (dim 1 True)) False).goType
        ===  "[]*uuid.UUID"

let googleUuidNeedsImport =
      assert : (forValueGoogle (value P.Uuid noArr) False).needsUuid === True

let googleUuidScansDirectly =
        assert
      : (forValueGoogle (value P.Uuid noArr) False).needsTextFormat === False

let googleModeLeavesNumericAlone =
        assert
      : (forValueGoogle (value P.Numeric noArr) False).goType === "string"

let googleModeLeavesNumericImportFree =
        assert
      : (forValueGoogle (value P.Numeric noArr) False).needsUuid === False

in  "ok"
