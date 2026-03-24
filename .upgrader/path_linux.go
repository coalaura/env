//go:build linux

package main

import (
	"os"
	"path/filepath"
)

func GetGoBinaryPath() string {
	return "/usr/local/go/bin/go"
}

func GetZigBinaryPath() string {
	return "/usr/local/zig/zig"
}

func GetBunBinaryPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "bun"
	}

	return filepath.Join(home, ".bun", "bin", "bun")
}

func GetLocalBinaryPath(name string) string {
	return filepath.Join("/usr/local/bin", name)
}
