---
name: pace
description: Use PACE, the Progressive Augmented Compiler Extensions toolchain for Go. Use when working with the `pace` command, `//go:inline`, `//go:linkinternal`, `//go:abiinternal`, PACE-specific Go code, low-level Go compiler intrinsics or ABIInternal assembly, or when validating code with PACE instead of stock Go.
---

# PACE

PACE is an independent Go compiler/toolchain overlay providing opt-in compiler extensions while keeping source compatible with stock Go.

## Source of truth

Do not inspect GOROOT, files inside the installed Go toolchain, or `$GOROOT/pace/README.md` to learn how PACE works.

Use the documentation bundled with this skill at `references/pace.md`.

## Using the toolchain

PACE is invoked as `pace` wherever stock Go would normally use `go`:

```sh
pace build ./...
pace test ./...
pace run .
pace list ./...
pace tool ...
```

Use `pace`, not `go`, when testing behavior that depends on a PACE directive.

When using Builder, add `--pace` while keeping the `go` language argument, for example `builder test go --pace ./...`. Every other argument and flag works the same; see the `build` skill for CGO and cross-compilation guidance. In GitHub Actions, set `pace: true` on `coalaura/build`; `pace: false` selects stock Go, and all other inputs work the same.

Stock Go ignores PACE's `//go:` directives. When compatibility matters, it can be useful to additionally build or test with stock `go` to verify the fallback path.

Do not modify or inspect GOROOT as part of normal PACE usage.

## Principles

PACE directives are opt-in. Do not add one merely because PACE is available.

Preserve a valid stock-Go fallback unless the user explicitly does not require stock compatibility.

Treat PACE features as compiler mechanisms, not portable language guarantees. Follow all constraints from the versioned reference exactly.

For `//go:abiinternal`, never invent register names, ABI assignments, supported architectures, or relaxed assembly restrictions. Consult the reference.

Choose body register mappings with both Go's natural ABIInternal assignment and the assembly instruction's fixed-register requirements in mind. Mappings determine the required entry and return shuffles; they do not change the caller's convention. Prefer identity mappings where useful and inspect generated code when performance matters. See the amd64 `CMPXCHG` example under "Choosing mappings" in the reference.
