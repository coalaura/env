package main

import (
	"crypto/rand"
	"encoding/hex"
	"os"
	"path/filepath"
)

func OpenFileForReading(path string) (*os.File, error) {
	return os.OpenFile(path, os.O_RDONLY, 0)
}

func OpenFileForWriting(path string) (*os.File, error) {
	dir := filepath.Dir(path)

	if _, err := os.Stat(dir); os.IsNotExist(err) {
		err = os.MkdirAll(dir, 0755)
		if err != nil {
			return nil, err
		}
	}

	return os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
}

func GetTempFilePath(ext string) (string, error) {
	b := make([]byte, 16)

	_, err := rand.Read(b)
	if err != nil {
		return "", err
	}

	return filepath.Join(os.TempDir(), hex.EncodeToString(b)+ext), nil
}

func OpenTempFileForWriting(ext string) (*os.File, string, error) {
	path, err := GetTempFilePath(ext)
	if err != nil {
		return nil, "", err
	}

	file, err := OpenFileForWriting(path)
	if err != nil {
		return nil, "", err
	}

	return file, path, nil
}
