# Engineering preferences

Repository-local instructions and established project conventions take precedence over these defaults.

## Code

- Match the existing style, structure, naming and conventions before introducing new patterns.
- Let the code breathe. Prefer clear, readable, maintainable code over dense or clever code.
- Use descriptive identifiers that quickly communicate purpose. Avoid one-/two-letter names for variables, functions, types and structs.
- Keep changes focused. Avoid unrelated rewrites or opportunistic refactors unless asked to.
- Split code into files by coherent responsibility. Keep related behavior together rather than splitting by arbitrary size.
- Prefer simple, explicit designs over unnecessary abstraction.

## Go

- Write modern, idiomatic Go using features supported by the project's declared Go version.
- Write mechanically sympathetic, allocation-conscious code. Avoid needless allocations and abstractions without sacrificing clarity for speculative micro-optimizations.
- Prefer named types over inline or anonymous structs for application data.
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
- If ambiguity materially affects behavior, architecture, APIs, security or data, ask rather than inventing requirements. Infer minor implementation details from the existing code when safe.

## Dependencies

- Ask before adding or upgrading dependencies.