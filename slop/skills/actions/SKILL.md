---
name: github-build
description: Build and sign Go binaries in GitHub Actions with coalaura/build and coalaura/sign. Use when creating, editing, or reviewing release workflows, cross-compilation, CGO builds, or code signing with coalaura/builder.
metadata:
  tooling: coalaura/build, coalaura/sign
---

# GitHub builds with coalaura/builder

Use `coalaura/build@v1` for builds and `coalaura/sign@v1` for signing.

Use a Linux runner with Docker available. The Builder image supplies Go, Zig, and the build environment; do not add `actions/setup-go`, Zig setup, or manual CGO environment configuration just to use these actions.

## Build

Typical build:

```yaml
- name: Build
  id: build
  uses: coalaura/build@v1
  with:
    os: ${{ matrix.goos }}
    arch: ${{ matrix.goarch }}
    generate: false
    output: dist/${{ env.project_name }}-${{ matrix.goos }}-${{ matrix.goarch }}${{ matrix.goos == 'windows' && '.exe' || '' }}
    go-flags: |
      -ldflags=-X main.Version=${{ github.ref_name }}
```

Important behavior:

- Targets are `linux`, `windows`, or `darwin`; `arch` defaults to `amd64`.
- Builds are pure Go by default. Set `cgo: true` when needed; CGO uses Zig.
- CGO linking is static by default. `link: dynamic` requires CGO.
- `optimization: optimize` is the default and uses `GOAMD64=v3` on amd64; use `compatible` for broad CPU compatibility.
- `go generate ./...` runs by default; set `generate: false` when it should not.
- `package` selects an explicit Go package; `target` selects a project/build target.
- Set `output` whenever another step needs the binary, then use `${{ steps.build.outputs.path }}`.
- `pre` is only for installing packages/tools into the Builder image, not for commands that operate on the checked-out project.
- `version` selects the Builder image and defaults to `latest`.

Do not pass Builder's own defaults again through `go-flags`. Builder already supplies `-trimpath`, `-buildvcs=false`, `-s -w`, and `netgo,osusergo` for pure-Go builds.

Use `go-flags` only for project-specific flags, for example:

```yaml
go-flags: |
  -tags=release
  -ldflags=-X main.Version=${{ github.ref_name }}
```

Builder merges user `-tags` and `-ldflags` with its generated values.

Darwin CGO builds automatically use the matching `-macos` Builder image (includes required SDKs and libraries). Do not append that suffix manually.

## Sign

Sign after building and before checksums, attestations, archives, artifact upload, or release publication.

Unless different credentials or chains are explicitly requested, use:

```yaml
- name: Sign
  id: sign
  uses: coalaura/sign@v1
  with:
    path: ${{ steps.build.outputs.path }}
    key: ${{ secrets.COALAURA_PFX }}
    passphrase: ${{ secrets.COALAURA_PFX_PASSWORD }}
    chain: |
      https://wiese2.org/pki/issuing.pem
      https://wiese2.org/pki/root.pem
```

`key` is a base64-encoded PEM, PFX, or P12. `key-file` may be used instead, but never supply both.

`chain` accepts local certificate files or HTTPS URLs, one per line.

Signing modifies the binary in place. Use `${{ steps.sign.outputs.path }}` afterwards.

Builder detects Windows PE, macOS Mach-O, and Linux ELF binaries automatically, timestamps the signature, and verifies it before succeeding.

`coalaura/sign@v1` has its own `builder-version`, independent of `coalaura/build`'s `version`. Leave both at their defaults unless a specific Builder version is required.