//go:build !windows

package main

import (
	"fmt"
	"os"
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
	uri := fmt.Sprintf("https://github.com/biomejs/biome/releases/download/%%40biomejs%%2Fbiome%%40%s/biome-linux-x64", ver.String())

	err := DownloadFileTo(uri, "/usr/local/bin/biome")
	if err != nil {
		return err
	}

	return os.Chmod("/usr/local/bin/biome", 0755)
}
