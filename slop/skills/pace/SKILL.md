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

Stock Go ignores PACE's `//go:` directives. When compatibility matters, it can be useful to additionally build or test with stock `go` to verify the fallback path.

Do not modify or inspect GOROOT as part of normal PACE usage.

## Principles

PACE directives are opt-in. Do not add one merely because PACE is available.

Preserve a valid stock-Go fallback unless the user explicitly does not require stock compatibility.

Treat PACE features as compiler mechanisms, not portable language guarantees. Follow all constraints from the versioned reference exactly.

For `//go:abiinternal`, never invent register names, ABI assignments, supported architectures, or relaxed assembly restrictions. Consult the reference.