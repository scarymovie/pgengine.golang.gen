-- Import gen-sdk (contract version 3.0).
-- Project and module are imported directly, bypassing the SDK's package.dhall:
-- its Fixtures use the Text/equal builtin, which released dhall versions
-- (<= 1.42.2) do not support yet. The generator itself doesn't need fixtures.
{ Project =
    https://raw.githubusercontent.com/pgenie-io/gen-sdk/v0.10.2/dhall/Project.dhall
, module =
    https://raw.githubusercontent.com/pgenie-io/gen-sdk/v0.10.2/dhall/module.dhall
}
