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

- Write modern, idiomatic Go for the project's declared Go version.
- One value per statement: assign first, then check. No initializers in `if` or `switch`, no function-local `const` or `type`, no anonymous struct types, no composite literals in `range` position. This holds in `_test.go` files too. Inline comma-ok for map lookups and type assertions is fine (in `if`), as is `struct{}{}`.
- Organize Go files strictly top to bottom as: constants -> types -> package variables -> methods -> package-level functions -> helpers. Apply this to every file you create or edit, and re-check the ordering before finishing. Only deviate if the project already follows a different convention.
- Verify with `vet.exe`/`vet`; it is always on PATH - never search for or try to install it. It runs go vet, staticcheck and the house rules; do not run them separately. If a rule is unclear, run `vet --explain [rule]` (e.g. `vet --explain breathe`). Never silence a diagnostic with an ignore directive or by restructuring around the check - fix what it points at.
- Vet takes optional `--os [windows/linux/darwin]` and `--arch [amd64/arm64]` flags (defaulting to the host) and `--cgo` if the project needs cgo (off by default). If the project has OS/arch-specific build constraints (`//go:build windows` etc.), vet every relevant target; otherwise plain `vet` suffices.

## Performance

Allocation and copy discipline is the default, not a later optimization pass. Aim for zero allocations on hot paths and steady-state loops; elsewhere, avoid any allocation that is free to avoid. Never trade correctness or readability for it, and state the tradeoff on non-obvious choices.

- Design data structures and APIs so allocations do not happen, rather than removing them afterwards. Pre-size everything with a known bound: `make([]T, 0, n)`, `make(map[K]V, n)`, `strings.Builder.Grow`.
- Prefer append-to-caller APIs (`func AppendFoo(dst []T, ...) []T`, like `strconv.AppendInt`) and caller-supplied buffers over functions that return fresh slices.
- Reuse buffers across iterations: declare once outside the loop, reset with `buf = buf[:0]`. `sync.Pool` only when profiling justifies it.
- Format into the destination: `fmt.Fprintf(w, ...)`, `strings.Builder`/`bytes.Buffer`, `strconv.Append*` over `fmt.Sprintf`. Never `+=` strings in a loop, never `buf.WriteString(fmt.Sprintf(...))`.
- Convert `[]byte`<->`string` once, not per iteration or per map lookup.
- Iterate instead of collecting: `iter.Seq`, `strings.SplitSeq`/`FieldsSeq`, `bytes.Cut`, or index-based scanning over `strings.Split`/`Fields` when the result is walked once.
- Keep values on the stack: do not return or store pointers to locals unnecessarily, do not box into `any` or capture in closures on hot paths, do not `defer` in tight loops. Verify with `go build -gcflags=-m` when it matters.
- Small structs by value, large by pointer. Do not pointer-ize small values "to save copies"; do not copy large elements by ranging over a slice by value - use the index or a pointer.
- Avoid `reflect`, `unsafe`, `regexp` and `fmt`-based parsing on hot paths; explicit `strconv`/`bytes` code is usually both clearer and allocation-free.
- Comment every non-obvious mechanical trick (buffer reuse, BCE hint, field-order layout) so the next reader knows why it exists.
- Benchmarks use `for b.Loop()` with `b.ReportAllocs()`; compare `allocs/op` before and after.

## Correctness

- Never weaken, remove, skip or loosen tests or assertions to make them pass. Fix the underlying cause.
- When an approach stops producing new information, change strategy rather than chasing it indefinitely.
- If ambiguity materially affects behavior, architecture, APIs, security or data, ask rather than inventing requirements. Infer minor details from existing code when safe.
- Do not run the application or start long-lived processes such as servers, watchers or daemons unless explicitly requested. Verify with builds, tests, linters and static checks.
- After completing a task, include a short lowercase commit message covering all uncommitted changes, not just this task's. Do not spend significant effort deriving it. Skip the commit message entirely if there are no uncommitted changes or if you are running as a subagent (e.g. exploring, planning, etc).

## Dependencies

- Ask before adding or upgrading dependencies.