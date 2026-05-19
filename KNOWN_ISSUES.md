## Known Issues

### 1. Interpreters are Placeholders

**Status:** TODO  
**Description:** Project.dhall and Query.dhall return empty/placeholder data.

**Solution:** Implement actual code generation logic based on java.gen patterns.

### 2. Templates Not Integrated

**Status:** TODO  
**Description:** gen/templates/ exist but not used by interpreters yet.

**Solution:** Connect templates to interpreters for actual Go code generation.

---

## Development History

- **Session 1 (2026-05-19):** MVP structure, documentation, examples
- **Session 2 (2026-05-19):** gen-sdk integration, studied rust.gen and java.gen
- **Session 3 (2026-05-19):** Fixed Sdk.module type mismatch by adding Algebras/Interpreter.dhall

## Fixed Issues

### Sdk.module Type Mismatch (FIXED)

**Error:**
```
Error: Wrong type of function argument
  - { … : … } (a record type)
  + List …
```

**Cause:** compile.dhall returned `List Sdk.File.Type`, but Sdk.module expected `Sdk.Compiled.Type (List Sdk.File.Type)`.

**Solution:** Created Algebras/Interpreter.dhall module (following java.gen pattern) that wraps the interpreter and handles the Compiled type. Updated Project.dhall to use `Sdk.Compiled.applicative.pure` and return the correct type.

See SESSION_2_SUMMARY.md for detailed session notes.
