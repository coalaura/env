---
name: build
description: Build, run, test, or benchmark Go projects, especially when CGO, native dependencies, cross-compilation, or linker/toolchain configuration is involved. Use coalaura/builder to handle reproducible Go and Zig/CGO build environments instead of manually assembling compiler environment variables.
metadata:
  tooling: builder
---

# Go builds with builder

`builder` is installed and available in `PATH`.

For ordinary pure-Go work, normal `go build`, `go run`, and `go test` are fine when they are simpler. Prefer `builder` when CGO, native libraries, cross-compilation, static/dynamic linking, architecture selection, or reproducible build configuration is involved.

## CGO

For CGO builds, use `builder` first. Do not manually construct `CGO_ENABLED`, `CC`, `CXX`, `GOOS`, `GOARCH`, Zig target triples, or linker flags unless `builder` cannot express the required build.

`builder` configures the Zig C/C++ toolchain and CGO environment itself, including target-specific compiler and linker settings.

Typical commands:

```sh
builder build go --cgo
builder run go --cgo -- arg1 arg2
builder test go --cgo ./...
builder bench go --cgo ./...

builder build go linux --arch arm64 --cgo
builder build go windows --arch amd64 --cgo --compat --output app.exe
```

## Important defaults

- Builds are pure Go unless `--cgo` is specified.
- CGO builds for Linux and Windows are static by default; use `--dyn` when dynamic linking is required.
- Optimized mode is the default. On amd64 this targets `GOAMD64=v3`; use `--compat` when broad CPU compatibility matters.
- `go generate ./...` runs by default. Use `--no-gen` when generation is unnecessary or when only validating existing generated sources.
- Only `builder build` accepts another target OS and `--arch`; run, test, and benchmark operate on the host.
- `builder test` defaults to `./...`.
- `builder bench` runs Go benchmarks with `-run=^$ -bench=. -benchmem`.
- Normal Go flags such as `-tags` and `-ldflags` can still be supplied.
- `--debug` prints the commands that would run without executing them.

The currently supported CGO target matrix is Linux, Windows, and Darwin on amd64 and arm64.

When cross-compiling CGO for Darwin, let `builder` discover an existing macOS SDK. It does not download an SDK.

## Troubleshooting

If a `builder` invocation fails because the generated toolchain configuration is unclear, rerun the same command with `--debug` and inspect what it would execute.

Do not immediately replace `builder` with a pile of manually exported CGO variables. Only fall back to direct `go`/compiler commands when the target or workflow is genuinely unsupported, when reproducing an upstream command exactly, or when the user explicitly requests it.