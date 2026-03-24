package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
)

func InstallSingleBinaryFromTarGz(url, binName, dstPath string) error {
	path, err := DownloadTempFile(url, ".tar.gz")
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

	src, err := FindFile(dir, binName)
	if err != nil {
		return err
	}

	err = CopyFile(src, dstPath)
	if err != nil {
		return err
	}

	return os.Chmod(dstPath, 0755)
}

func InstallSingleBinaryFromZip(url, binName, dstPath string) error {
	path, err := DownloadTempFile(url, ".zip")
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

	src, err := FindFile(dir, binName)
	if err != nil {
		return err
	}

	return CopyFile(src, dstPath)
}

func CopyFile(src, dst string) error {
	in, err := OpenFileForReading(src)
	if err != nil {
		return err
	}

	defer in.Close()

	out, err := OpenFileForWriting(dst)
	if err != nil {
		return err
	}

	_, err = io.Copy(out, in)

	closeErr := out.Close()

	if err != nil {
		return err
	}

	if closeErr != nil {
		return closeErr
	}

	return nil
}

func GetLinuxBinDir() string {
	return "/usr/local/bin"
}

func GetWindowsBinDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	return filepath.Join(home, ".bin"), nil
}

func GetZigAssetName(ver *SemVer) string {
	switch runtime.GOOS {
	case "windows":
		return fmt.Sprintf("zig-windows-x86_64-%s.zip", ver.String())
	default:
		return fmt.Sprintf("zig-linux-x86_64-%s.tar.xz", ver.String())
	}
}
