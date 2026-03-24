//go:build windows

package main

import (
	"fmt"
	"os"
	"path/filepath"
)

func InstallGo(ver *SemVer) error {
	uri := fmt.Sprintf("https://go.dev/dl/go%s.windows-amd64.msi", ver.String())

	path, err := DownloadTempFile(uri, ".msi")
	if err != nil {
		return err
	}

	defer os.Remove(path)

	return RunCommandOrError("msiexec.exe", "/i", path, "/qn", "/norestart")
}

func InstallZig(ver *SemVer) error {
	uri := fmt.Sprintf("https://ziglang.org/download/%s/zig-x86_64-windows-%s.zip", ver.String(), ver.String())

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

	srcDir := filepath.Join(dir, fmt.Sprintf("zig-x86_64-windows-%s", ver.String()))
	dstDir := filepath.Dir(GetZigBinaryPath())

	os.RemoveAll(dstDir)
	os.MkdirAll(dstDir, 0755)

	return filepath.Walk(srcDir, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		rel, err := filepath.Rel(srcDir, p)
		if err != nil {
			return err
		}

		target := filepath.Join(dstDir, rel)

		if info.IsDir() {
			return os.MkdirAll(target, 0755)
		}

		return CopyFile(p, target)
	})
}

func InstallUPX(ver *SemVer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	uri := fmt.Sprintf("https://github.com/upx/upx/releases/download/v%s/upx-%s-win64.zip", ver.String(), ver.String())

	path := filepath.Join(home, ".bin", "upx.exe")

	return InstallSingleBinaryFromZip(uri, "upx.exe", path)
}

func InstallStarship(ver *SemVer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	uri := fmt.Sprintf("https://github.com/starship/starship/releases/download/v%s/starship-x86_64-pc-windows-msvc.zip", ver.String())

	path := filepath.Join(home, ".bin", "starship.exe")

	return InstallSingleBinaryFromZip(uri, "starship.exe", path)
}

func InstallBun(ver *SemVer) error {
	uri := fmt.Sprintf("https://github.com/oven-sh/bun/releases/download/bun-v%s/bun-windows-x64.zip", ver.String())

	return InstallSingleBinaryFromZip(uri, "bun.exe", GetBunBinaryPath())
}

func InstallBiome(ver *SemVer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	uri := fmt.Sprintf("https://github.com/biomejs/biome/releases/download/%%40biomejs%%2Fbiome%%40%s/biome-win32-x64.exe", ver.String())

	path := filepath.Join(home, ".bin", "biome.exe")

	return DownloadFileTo(uri, path)
}

func InstallTime(ver *SemVer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	uri := fmt.Sprintf("https://github.com/coalaura/time/releases/download/%s/time_%s_windows_amd64.exe", ver.String(), ver.String())

	path := filepath.Join(home, ".bin", "time.exe")

	return DownloadFileTo(uri, path)
}

func InstallCoreutils(ver *SemVer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	uri := fmt.Sprintf("https://github.com/uutils/coreutils/releases/download/%s/coreutils-%s-x86_64-pc-windows-msvc.zip", ver.String(), ver.String())

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

	srcDir := filepath.Join(dir, fmt.Sprintf("coreutils-%s-x86_64-pc-windows-msvc", ver.String()))
	dstDir := filepath.Join(home, ".bin")

	os.MkdirAll(dstDir, 0755)

	entries, err := os.ReadDir(srcDir)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".exe" {
			continue
		}

		err = CopyFile(filepath.Join(srcDir, entry.Name()), filepath.Join(dstDir, entry.Name()))
		if err != nil {
			return err
		}
	}

	return nil
}
