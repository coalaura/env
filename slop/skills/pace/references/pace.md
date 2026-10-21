# PACE 1.27.3

PACE 1.27.3 requires exactly Go 1.27.3. Source: [upstream README on the `pace` branch](https://github.com/coalaura/pace/blob/pace/README.md).

This reference covers all nine PACE directives. Stock Go ignores them, so preserve equivalent fallback implementations and architecture-appropriate build constraints. Compiler contracts and optimizations apply only when building with PACE.

## Toolchain and validation

- Invoke `pace` wherever stock Go would use `go`, including `build`, `test`, `list` and `tool`. PACE uses its own compiler and assembler with the matching Go toolchain.
- `pace version` reports `go version go1.27.3 <os>/<arch> (pace)`; `pace env GOVERSION` remains `go1.27.3`.
- Automatic `GOTOOLCHAIN` switching is disabled. PACE does not collect or upload Go telemetry; distinct compiler/assembler tool IDs let it safely share Go's normal build cache.
- Use `pace test ./...` and `pace build ./...` to validate directive behavior. Separately use `go test ./...` and `go build ./...` to validate the stock fallback. Neither substitutes for the other.
- Use this reference to learn PACE behavior; do not inspect or modify GOROOT.

## //go:inline

Place above a function to bypass normal inlining cost/profitability heuristics. Ordinary eligibility restrictions, unsupported-operation checks and recursion safeguards still apply; this cannot make arbitrary functions inlinable. `//go:noinline` takes precedence if both are present.

## //go:align N

Requests minimum function-entry alignment of `N` bytes, a positive power-of-two integer in `8..2048`. Applies to emitted Go functions and methods with bodies, including generic instances; bodyless declarations are rejected. It does not affect callers through inlining and composes with `//go:inline` and `//go:noinline`.

## //go:nobounds

Suppresses runtime index/slice bounds checks originating in the annotated function body, including slice-to-array conversions. Invalid accesses have unsafe/unspecified consequences instead of Go's normal bounds panic. Compile-time bounds errors, nil checks and `checkptr` remain in effect.

The policy follows the original function through inlining and across packages; callees retain their own policy. Composes with `//go:inline`. Prove bounds independently before using it.

## //go:makenozero

Place the argument-free directive immediately above a single-name local short declaration whose initializer is a slice `make`:

```go
//go:makenozero
buffer := make([]byte, 16, 32)
```

The entire backing allocation is uninitialized: all 32 bytes here, including capacity beyond the length. Without explicit capacity, the allocation has the requested length. Initial values are unspecified even if memory happens to contain zeros; initialize every byte or element before relying on its value or exposing it. Stock Go zero-initializes normally.

- Elements must be pointer-free: scalars such as `uint64`, arrays such as `[32]byte`, or structs recursively containing pointer-free fields. Pointers, strings, interfaces, slices, maps, functions, channels and aggregates containing them are rejected. Generic constraints must prove a supported core type.
- Arguments, multiple RHS expressions and other placements are rejected. It may share a contiguous directive block with `//go:muststack` in either order; no blank lines or unrelated comments may separate the directives or declaration.
- Ordinary escape analysis still chooses stack or heap storage; the uninitialized property survives inlining, including across packages. Normal length/capacity checks, signed/unsigned conversions, 32-bit narrowing, byte-size overflow checks and the distinction between length and capacity panics are retained.
- PACE omits stack backing-storage zeroing or uses existing `runtime.mallocgc(size, nil, false)` for the heap; no runtime changes are needed. It deliberately does not reproduce `runtime.maxAlloc`: allocations exceeding that runtime limit are invalid and may fail differently from ordinary `make`, even with representable dimensions and byte size. Arithmetic overflow is still caught first.

## //go:muststack

A compile-time performance assertion that the following local variable and storage directly created by its initializer stay on the stack. Place the argument-free directive immediately above a new single-name local `:=` declaration:

```go
//go:muststack
//go:makenozero
buffer := make([]byte, 4096)
```

The assertion includes slice backing arrays, `new(T)` and `&T{}`. Ordinary escape analysis still decides allocation: later escaping uses, variable-capacity slices, or runtime helpers with heap fallbacks cause compilation to fail at the declaration with the variable name. It neither overrides escape analysis nor guarantees anything about allocations inside called functions.

Arguments, duplicates, multiple names, reassignments and other placements are rejected. `//go:makenozero` is optional in the example; the two directives can appear in either order in one contiguous block, without intervening blank lines or unrelated comments.

## //go:immutable

Makes a variable and its owned storage immutable after initialization. The initializer or implicit zero value is the sole permitted write. Place the argument-free directive immediately above a single-name package/local `var` declaration or a new single-name local `:=` declaration:

```go
//go:immutable
var table = [4]uint64{10, 20, 30, 40}
```

### Declarations and ownership

- No intervening blank lines or comments. Individual declarations in `var (...)` may be annotated, but not the whole group. Arguments, duplicates, blank identifiers, multiple names, `//go:embed`, `//go:linkname` on the variable, and combinations with `//go:muststack` or `//go:makenozero` are rejected.
- Supported values are booleans, numbers, and arrays/structs recursively containing only those types. Generic constraints must establish a supported core type. Strings, pointers, maps, interfaces, functions, channels and other reference-containing aggregates are rejected.
- Slices of supported pointer-free elements require a fresh slice literal, builtin `make`, `nil`, or an implicit nil initializer. Existing slices, function results and conversions are rejected because exclusive ownership cannot be established.

### Permitted uses

- PACE rejects reassignment, compound assignment, increment/decrement, field/element writes, assignment through `range`/`select`, address-taking, slicing, and implicit pointer-receiver calls or method values. Independent copies of pointer-free values may be passed or modified normally.
- Immutable slices permit element reads, `len`, `cap`, `range`, comparison with `nil`, `copy` with the immutable slice as source, conversion to string where Go allows it, and blank assignment (`_ = data`).
- Immutable slices cannot be returned, assigned to another variable, interface-boxed, channel-sent, sliced, appended to, cleared, or passed to arbitrary functions/methods. Even harmless but unproven aliases are rejected. `//go:readonly` parameters do not relax this: they still permit retention and mutation through other aliases.
- Checks cover closures, other files and importing packages, and run before inlining/generic instantiation, even for uninstantiated generic functions. Exported contracts survive package boundaries. The guarantee covers PACE-compiled, type-safe Go; fabricated unsafe pointers and external assembly cannot be checked. Stock Go does not enforce it.

### Storage and optimization

Wholly static package initializers, including implicit zero values and eligible fresh slice backing arrays, use readonly symbols and the linker's `.rodata` or equivalent. Runtime-written initializers, including partially static composites, retain writable storage. Locals use normal escape analysis and stack/heap allocation; there is no runtime memory-protection transition.

Existing SSA optimizations may fold/eliminate loads under their usual safety conditions; constant-index loads from eligible local-package readonly globals can become immediates, including across calls. Loop hoisting, removal of every redundant load and folding of imported data are not guaranteed. No new optimizer pass or runtime support is required.

## //go:readonly src, table

On a bodyless function, promises no writes through the listed named input parameters or references reachable from them:

```go
//go:readonly source
//go:noescape
func checksum(source []byte) uint64
```

`//go:readonly` is independent of `//go:noescape`: references may still be retained beyond the call, and memory may still be modified through an unannotated alias parameter or global state. Combine the directives only when both contracts hold. Existing escape-analysis summaries let callers benefit, including across packages. This is a function contract, not a declaration of immutable storage.

## //go:linkinternal import/path.Function

Lets a function inherit the target's compiler intrinsic identity while keeping an ordinary Go fallback:

```go
import "sync/atomic"

//go:linkinternal internal/runtime/atomic.Cas64
func compareAndSwap64(address *uint64, oldValue, newValue uint64) bool {
	return atomic.CompareAndSwapUint64(address, oldValue, newValue)
}
```

Specify exactly one target; its final `.` separates package path and function name. Intrinsic lookup uses that identity under normal architecture, race-detector and other applicability rules. If no intrinsic applies, PACE uses the fallback body. The author must match the intrinsic's signature and semantics; the identity survives package boundaries.

This does not import the target package, bypass internal-package visibility, alias linker symbols, behave like `//go:linkname`, or create a call/jump to the target.

## //go:abiinternal

Lets stock-compatible Plan 9 assembly implement a bodyless function using ABIInternal with explicit body register mappings. Callers retain Go's normal calling convention. Every parameter and result must be named and mapped exactly once, with exactly one `->` separating inputs from results:

```go
//go:abiinternal addr=DX new=BX width=CX signed=DI -> old=AX
func SwapIfLessInteger(addr *uint64, new uint64, width uint8, signed bool) (old uint64)
```

Targets must be distinct within each side of `->`. Unknown/duplicate names, missing mappings and unnamed values are errors. Textual mapping order does not change the natural ABI assignment, which comes from the signature and target architecture.

### Assembly and value restrictions

- Only scalars assigned to exactly one integer ABI register: integers, booleans, pointers and pointer-sized values. Aggregates, floats/SIMD, stack-assigned arguments/results, methods, `init`, Go bodies, and combinations with `//go:linkname` or `//go:cgo_unsafe_args` are rejected.
- Keep ordinary ABI0 argument size and named `FP` loads/stores in the assembly. For the example, use `$0-32`; `addr+0(FP)` maps to `DX`, and `old+24(FP)` to `AX`. Names/offsets must match whole declared values; use appropriate instruction widths. Address-taking and subfield access through mapped `FP` operands are unsupported.
- Stock Go uses ABI0 assembly and its usual wrapper. PACE emits ABIInternal, rewrites named `FP` operands to mapped registers, removes mapped identity integer moves, and inserts entry/return parallel copies between natural and mapped registers. It omits identities and breaks cycles using the reserved scratch register. Mappings are package-local, passed to the assembler in a work-directory sidecar, and not exported.
- Mapped inputs are live register aliases, not persistent stack slots: later `FP` reads observe any register clobbers. Results must be in their mapped registers at every `RET`.
- Assembly must be zero-frame `NOSPLIT` leaf code: no calls, tail calls, explicit stack operations or stack operands; branches must target local labels. Normal argument information and stack maps are retained. Explicit `<ABIInternal>` selectors remain restricted to privileged packages.
- Preserve fixed-register invariants, including link registers and amd64's `R14` (goroutine) and zeroed `X15`. There is no ABI0 wrapper to restore them.

### Architectures and registers

Only these canonical target names are accepted; aliases and reserved adaptation scratch registers are unavailable as mapping targets:

| Architecture | Allowed targets | Adaptation scratch | Integer copy |
| --- | --- | --- | --- |
| amd64 | `AX BX CX DX DI SI R8 R9 R10 R11 R13` | `R12` | `MOVQ` |
| arm64 | `R0-R15 R17 R19-R26` | `R16` | `MOVD` |
| loong64 | `R4-R19 R21 R23-R28` | `R20` | `MOVV` |
| ppc64 / ppc64le | `R3-R12 R14-R29` | `R31` | `MOVD` |
| riscv64 | `X5-X26 X28-X30` | `X31` | `MOV` |
| s390x | `R2-R9` | `R1` | `MOVD` |

Stack, frame, link, goroutine, platform-reserved, assembler-temporary, other fixed ABI, floating-point and vector registers excluded by the table are unavailable. Targets without integer ABIInternal parameter registers in Go 1.27.3 (`386`, `arm`, `mips`, `mipsle`, `mips64`, `mips64le`, `wasm`) reject the directive.

### Choosing mappings

PACE adapts the author's mapping; it does not optimize the choice. Prefer identity mappings where compatible with the body's instruction requirements, and inspect generated code when performance matters.

On amd64, single-register integer arguments use `AX BX CX DI SI R8 R9 R10 R11` in declaration order; results independently start from the same sequence. `DX` is an allowed body target but not a natural argument register.

For `SwapIfLessInteger` above, natural inputs are `addr=AX new=BX width=CX signed=DI` and the result is `old=AX`. Mapping only `addr` to `DX` needs just `MOVQ AX, DX` on entry and no return shuffle. This frees `AX` for `CMPXCHG`'s implicit accumulator while keeping the other values in place. Choose mapping and body together so redundant loads disappear rather than adding avoidable moves inside the body.
