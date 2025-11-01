//go:build !windows

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

func InstallBiome(ver *SemVer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	uri := fmt.Sprintf("https://github.com/biomejs/biome/releases/download/%%40biomejs%%2Fbiome%%40%s/biome-linux-x64", ver.String())
	path := filepath.Join(home, ".bin", "biome")

	err = DownloadFileTo(uri, path)
	if err != nil {
		return err
	}

	return os.Chmod(path, 0755)
}
