-- Generate error definitions for the generated code
-- MVP: No custom errors, just use pgx.ErrNoRows directly

let generateErrors : Text
    = ''
// No custom errors in MVP
// Use pgx.ErrNoRows directly for not found cases
''

in  { generateErrors
    }
