//go:build linux

package main

import (
	"fmt"
	"os"
	"path/filepath"
)

func InstallGo(ver *SemVer) error {
	uri := fmt.Sprintf("https://go.dev/dl/go%s.linux-amd64.tar.gz", ver.String())

	path, err := DownloadTempFile(uri, ".tar.gz")
	if err != nil {
		return err
	}

	defer os.Remove(path)

	err = RunCommandOrError("rm", "-rf", "/usr/local/go")
	if err != nil {
		return err
	}

	return RunCommandOrError("tar", "-C", "/usr/local", "-xzf", path)
}

func InstallZig(ver *SemVer) error {
	uri := fmt.Sprintf("https://ziglang.org/download/%s/zig-x86_64-linux-%s.tar.xz", ver.String(), ver.String())

	path, err := DownloadTempFile(uri, ".tar.xz")
	if err != nil {
		return err
	}

	defer os.Remove(path)

	return RunCommandOrError("sh", "-c", fmt.Sprintf("rm -rf /usr/local/zig && mkdir -p /usr/local/zig && tar -C /usr/local/zig --strip-components=1 -xf %q", path))
}

func InstallUPX(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/upx/upx/releases/download/v%s/upx-%s-amd64_linux.tar.xz", ver.String(), ver.String())

	path, err := DownloadTempFile(uri, ".tar.xz")
	if err != nil {
		return err
	}

	defer os.Remove(path)

	return RunCommandOrError("sh", "-c", fmt.Sprintf("tmpdir=$(mktemp -d) && tar -C \"$tmpdir\" -xf %q && install \"$tmpdir\"/*/upx /usr/local/bin/upx", path))
}

func InstallStarship(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/starship/starship/releases/download/v%s/starship-x86_64-unknown-linux-gnu.tar.gz", ver.String())

	return InstallSingleBinaryFromTarGz(uri, "starship", "/usr/local/bin/starship")
}

func InstallBun(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/oven-sh/bun/releases/download/bun-v%s/bun-linux-x64.zip", ver.String())

	path, err := DownloadTempFile(uri, ".zip")
	if err != nil {
		return err
	}

	defer os.Remove(path)

	dir, err := os.MkdirTemp("", "upgrader-*")
	if err != nil {
		return err
	}

	defer os.RemoveAll(dir)

	err = ExtractZipFile(path, dir)
	if err != nil {
		return err
	}

	src := filepath.Join(dir, "bun-linux-x64", "bun")
	dst := GetBunBinaryPath()

	err = CopyFile(src, dst)
	if err != nil {
		return err
	}

	return os.Chmod(dst, 0755)
}

func InstallBiome(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/biomejs/biome/releases/download/%%40biomejs%%2Fbiome%%40%s/biome-linux-x64", ver.String())

	err := DownloadFileTo(uri, "/usr/local/bin/biome")
	if err != nil {
		return err
	}

	return os.Chmod("/usr/local/bin/biome", 0755)
}

func InstallTime(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/coalaura/time/releases/download/v%s/time_v%s_linux_amd64", ver.String(), ver.String())

	err := DownloadFileTo(uri, "/usr/local/bin/time")
	if err != nil {
		return err
	}

	return os.Chmod("/usr/local/bin/time", 0755)
}

func InstallWtf(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/coalaura/wtf/releases/download/v%s/wtf_v%s_linux_amd64", ver.String(), ver.String())

	err := DownloadFileTo(uri, "/usr/local/bin/wtf")
	if err != nil {
		return err
	}

	return os.Chmod("/usr/local/bin/wtf", 0755)
}

func InstallCoreutils(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/uutils/coreutils/releases/download/%s/coreutils-%s-x86_64-unknown-linux-gnu.tar.gz", ver.String(), ver.String())

	path, err := DownloadTempFile(uri, ".tar.gz")
	if err != nil {
		return err
	}

	defer os.Remove(path)

	dir, err := os.MkdirTemp("", "upgrader-*")
	if err != nil {
		return err
	}

	defer os.RemoveAll(dir)

	err = ExtractTarGzFile(path, dir)
	if err != nil {
		return err
	}

	src := filepath.Join(dir, fmt.Sprintf("coreutils-%s-x86_64-unknown-linux-gnu", ver.String()), "coreutils")
	dst := "/usr/local/bin/coreutils"

	err = CopyFile(src, dst)
	if err != nil {
		return err
	}

	return os.Chmod(dst, 0755)
}
