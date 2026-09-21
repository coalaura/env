# PACE 1.27.1

PACE 1.27.1 is based on Go 1.27.1.

PACE adds three source-compatible compiler directives:

- `//go:inline`
- `//go:linkinternal`
- `//go:abiinternal`

Stock Go ignores these unknown `//go:` directives, so the same source can retain ordinary fallback behavior.

## Toolchain behavior

Use `pace` in place of `go` when PACE behavior is required:

```sh
pace build ./...
pace test ./...
pace run .
````

PACE uses its own compiler and assembler while otherwise using the matching Go toolchain.

`pace version` reports:

```text
go version go1.27.1 <os>/<arch> (pace)
```

`pace env GOVERSION` remains:

```text
go1.27.1
```

PACE 1.27.1 requires exactly Go 1.27.1.

Automatic `GOTOOLCHAIN` switching is disabled under `pace`; PACE must not silently switch into a stock Go toolchain.

PACE does not collect or upload Go telemetry.

PACE compiler and assembler tool IDs differ from stock Go, so both may safely use the normal Go build cache.

Do not inspect GOROOT to discover PACE behavior. The remainder of this document is the source of truth for this skill.

# //go:inline

Syntax:

```go
//go:inline
func function(...) ...
```

`//go:inline` forces an otherwise eligible function past normal inlining cost/profitability heuristics.

It does not make fundamentally unsupported functions inlinable.

The compiler must still enforce normal semantic restrictions such as unsupported operations and recursion safeguards.

If both are present:

```go
//go:inline
//go:noinline
func function() {}
```

`//go:noinline` takes precedence.

Use `//go:inline` when the caller deliberately wants a function inlined regardless of the compiler's normal cost decision.

Do not describe it as an unconditional guarantee that arbitrary functions can be inlined.

# //go:linkinternal

Syntax:

```go
//go:linkinternal import/path.Function
func function(...) ... {
    // stock-Go fallback
}
```

Example:

```go
import "sync/atomic"

//go:linkinternal internal/runtime/atomic.Cas64
func cas64(ptr *uint64, old, new uint64) bool {
    return atomic.CompareAndSwapUint64(ptr, old, new)
}
```

`//go:linkinternal` changes the compiler intrinsic identity of the annotated function.

When checking whether the annotated function has an intrinsic, PACE performs the lookup as though it were the named target function.

It does not:

* import an internal package,
* bypass Go's internal-package visibility rules,
* alias linker symbols,
* behave like `//go:linkname`,
* create a call or jump to the target.

Existing compiler intrinsic policy still applies, including architecture, race-detector and other applicability rules.

If the target does not have an applicable intrinsic, the annotated function's ordinary Go body is used.

The fallback body therefore remains meaningful and should normally implement equivalent semantics.

The target format is exactly one:

```text
import/path.Function
```

The package path may contain dots; the final `.` separates the function name.

The author is responsible for ensuring the annotated function's signature and semantics are appropriate for the intrinsic being inherited.

The intrinsic identity is preserved across packages, so callers of an exported annotated function can receive the intrinsic behavior too.

# //go:abiinternal

`//go:abiinternal` lets ordinary stock-compatible Plan 9 assembly implement a function directly using Go's ABIInternal register ABI, with an explicit body register mapping.

Call sites still use Go's normal ABIInternal convention.

The directive does not create a custom calling convention for callers.

## Syntax

Every parameter and result must be named and mapped exactly once:

```go
//go:abiinternal addr=DX new=BX width=CX signed=DI -> old=AX
func SwapIfLessInteger(
    addr *uint64,
    new uint64,
    width uint8,
    signed bool,
) (old uint64)
```

There must be exactly one `->`.

Mappings before `->` are parameters.

Mappings after `->` are results.

Every named parameter and result must appear exactly once.

Unknown names, duplicate names, missing mappings and duplicate simultaneous target registers are errors.

Unnamed parameters/results are unsupported.

## Source compatibility

The assembly remains ordinary stock-compatible Plan 9 assembly using ABI0-style named `FP` operands:

```asm
TEXT ·SwapIfLessInteger(SB), NOSPLIT, $0-32
    MOVQ addr+0(FP), DX
    MOVQ new+8(FP), BX

    // body...

    MOVQ AX, old+24(FP)
    RET
```

Under stock Go:

* the directive is ignored,
* the assembly remains ABI0,
* Go generates/uses its ordinary ABI wrapper.

Under PACE:

* the assembly definition becomes ABIInternal,
* named `FP` accesses for mapped values are rewritten to their requested registers,
* redundant mapped identity moves are removed,
* the assembler inserts only the register adaptation needed between Go's natural ABIInternal assignment and the requested body mapping.

For example, on amd64 a function whose natural first argument arrives in `AX` but maps it as:

```text
addr=DX
```

needs an entry adaptation equivalent to:

```asm
MOVQ AX, DX
```

The compiler determines natural ABIInternal register assignments using Go's normal ABI analysis. Do not hardcode the natural calling convention when reasoning about the directive.

## Value restrictions

PACE 1.27.1 supports values that:

* are integers, booleans, pointers or pointer-shaped values, and
* occupy exactly one integer ABIInternal register.

Unsupported values include:

* aggregates requiring multiple registers,
* floating-point values,
* SIMD/vector values,
* stack-assigned arguments/results.

Methods are unsupported.

`init` functions are unsupported.

The declaration must be bodyless and have an assembly definition.

`//go:abiinternal` cannot be combined with:

```text
//go:linkname
//go:cgo_unsafe_args
```

## Assembly restrictions

The assembly implementation must be:

* `NOSPLIT`,
* zero-frame,
* leaf code.

It must not contain:

* calls,
* tail calls,
* explicit stack operations,
* stack operands.

Branches must target labels within the same function.

Named `FP` operands must correspond exactly to the whole declared parameter/result at its expected ABI0 offset.

Do not:

* take the address of a mapped argument,
* address a subfield through the mapped `FP` operand.

Mapped values are live register aliases, not persistent stack slots.

Once the body changes a mapped input register, later references to that mapped `FP` operand observe that register's current value.

At every `RET`, results must be present in their requested mapping registers. PACE adapts those registers back to Go's natural ABIInternal result registers.

Parallel register copies are scheduled correctly, including cycles, using an architecture-specific reserved scratch register.

Explicit assembly `<ABIInternal>` selectors remain restricted exactly as in stock Go; PACE does not expose them to ordinary user assembly.

## Supported architectures

PACE 1.27.1 supports `//go:abiinternal` on:

```text
amd64
arm64
loong64
ppc64
ppc64le
riscv64
s390x
```

It rejects the directive on:

```text
386
arm
mips
mipsle
mips64
mips64le
wasm
```

because those targets do not provide the required integer-register ABIInternal configuration in this Go release.

## Mapping registers

Use only the canonical register names listed here.

Aliases are not accepted.

| Architecture    | Allowed targets                       | Reserved adaptation scratch | Integer copy |
| --------------- | ------------------------------------- | --------------------------- | ------------ |
| amd64           | `AX BX CX DX DI SI R8 R9 R10 R11 R13` | `R12`                       | `MOVQ`       |
| arm64           | `R0-R15 R17 R19-R26`                  | `R16`                       | `MOVD`       |
| loong64         | `R4-R19 R21 R23-R28`                  | `R20`                       | `MOVV`       |
| ppc64 / ppc64le | `R3-R12 R14-R29`                      | `R31`                       | `MOVD`       |
| riscv64         | `X5-X26 X28-X30`                      | `X31`                       | `MOV`        |
| s390x           | `R2-R9`                               | `R1`                        | `MOVD`       |

Stack, frame, link, goroutine, platform-reserved, assembler-temporary, fixed ABI, floating-point and vector registers excluded by the table must not be used as mapping targets.

Architecture-specific fixed-register invariants remain the assembly author's responsibility.

In particular, preserve link registers on link-register architectures.

On amd64, preserve the ABI invariants for `R14` and zeroed `X15`.

## Choosing mappings

PACE does not optimize the mapping chosen by the author.

Prefer mappings that already match Go's natural ABIInternal register assignment where that is useful.

Identity mappings require no adaptation.

Mappings may deliberately choose different registers when that makes the assembly body cleaner or faster; PACE inserts only the required parallel copies.

Do not assume changing mappings automatically improves performance. Inspect generated code when performance matters.

## Validation

When testing PACE-specific code, use:

```sh
pace test ./...
pace build ./...
```

When checking stock compatibility, separately use:

```sh
go test ./...
go build ./...
```

Do not use a successful stock-Go build as evidence that a PACE directive actually took effect: stock Go intentionally ignores these directives.

Likewise, do not use only a PACE build to prove that the intended stock fallback remains valid.