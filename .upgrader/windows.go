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

func InstallBiome(ver *SemVer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	uri := fmt.Sprintf("https://github.com/biomejs/biome/releases/download/%%40biomejs%%2Fbiome%%40%s/biome-win32-x64.exe", ver.String())
	path := filepath.Join(home, ".bin", "biome.exe")

	return DownloadFileTo(uri, path)
}
