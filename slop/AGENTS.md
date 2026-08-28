# Engineering preferences

Repository-local instructions and project conventions take precedence over these defaults.

## Code

- Match existing style, structure, naming and conventions before introducing new patterns.
- Prefer clear, explicit code over dense, clever or over-abstracted code.
- Use descriptive identifiers. Avoid one-/two-letter names for variables, functions, types and fields.
- Let the code breathe: blank lines between control-flow blocks and between setup, iteration and follow-up work. A statement sits directly above a check only if it feeds it.
- Keep changes focused. No unrelated rewrites or opportunistic refactors.
- Split files by coherent responsibility and keep related behavior together.

## Go

- Write modern, idiomatic, mechanically sympathetic, allocation-conscious Go for the
  project's declared Go version.
- One value per statement: assign first, then check. No initializers in `if` or `switch`, no function-local `const` or `type`, no anonymous struct types, no composite literals in `range` position. This holds in `_test.go` files too. Inline comma-ok for map lookups and type assertions is fine (in `if`), as is `struct{}{}`.
- Unless the project follows another convention, organize Go files as: constants -> types -> package variables -> methods -> package-level functions -> helpers.
- Verify with the local `vet.exe`/`vet` tool; it runs go vet, staticcheck and the house rules. Do not run them separately. Never silence a diagnostic with an ignore directive or by restructuring around the check - fix what it points at.

## Correctness

- Never weaken, remove, skip or loosen tests or assertions to make them pass. Fix the underlying cause.
- When an approach stops producing new information, change strategy rather than chasing it indefinitely.
- If ambiguity materially affects behavior, architecture, APIs, security or data, ask rather than inventing requirements. Infer minor details from existing code when safe.
- Do not run the application or start long-lived processes such as servers, watchers or daemons unless explicitly requested. Verify with builds, tests, linters and static checks.
- After completing a task, include a short lowercase commit message covering all uncommitted changes, not just this task's. Do not spend significant effort deriving it.

## Dependencies

- Ask before adding or upgrading dependencies.