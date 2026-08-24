# Engineering preferences

Repository-local instructions and established project conventions take precedence over these defaults.

## Code

- Match the existing style, structure, naming and conventions before introducing new patterns.
- Let the code breathe. Visually isolate control-flow blocks: use blank lines between consecutive `if`, `for`, `switch`, and similar blocks, and between setup, iteration, and follow-up operations. Keep a statement adjacent only when it directly introduces the check that immediately follows.
- Prefer clear, readable, maintainable code over dense or clever code.
- Use descriptive identifiers that quickly communicate purpose. Avoid one-/two-letter names for variables, functions, types, and structs.
- Keep changes focused. Avoid unrelated rewrites or opportunistic refactors.
- Split code into files by coherent responsibility and keep related behavior together.
- Prefer simple, explicit designs over unnecessary abstraction.

## Go

- Write modern, idiomatic, mechanically sympathetic, allocation-conscious Go using the project's declared Go version.
- Prefer assigning errors before checking them rather than declarations inside `if`. Inline error checks are fine for trivial operations such as `ctx.Err()`.
- Do not use anonymous or function-local struct types, including in tests. Define named structs at package scope, unexported when appropriate and keep them with the other type declarations.
- Unless the project clearly follows another convention organize Go files as:
  1. constants
  2. types and structs
  3. package variables
  4. struct methods
  5. package-level functions
  6. helpers

## Correctness

- Never weaken, remove, skip or loosen tests or assertions to make them pass. Fix the underlying cause.
- When an approach stops producing new information, change strategy rather than chasing it indefinitely.
- If ambiguity materially affects behavior, architecture, APIs, security or data, ask rather than inventing requirements. Infer minor details from existing code when safe.
- Do not run the application or start long-lived processes such as servers, watchers, daemons, or listeners unless explicitly requested. Prefer builds, tests, linters, and static checks for verification.
- After completing a task, include a short lowercase commit message for all currently uncommitted changes unless asked otherwise, alongside the normal response. Do not spend significant extra effort deriving it.

## Dependencies

- Ask before adding or upgrading dependencies.