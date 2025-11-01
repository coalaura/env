package main

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
)

func DownloadTempFile(url, ext string) (string, error) {
	path, err := GetTempFilePath(ext)
	if err != nil {
		return "", err
	}

	err = DownloadFileTo(url, path)
	if err != nil {
		return "", err
	}

	return path, nil
}

func DownloadFileTo(url, path string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}

	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return errors.New(resp.Status)
	}

	file, err := OpenFileForWriting(path)
	if err != nil {
		return err
	}

	defer file.Close()

	n, err := io.Copy(file, resp.Body)
	if err != nil {
		defer os.Remove(path)

		return err
	}

	if n < 128 {
		defer os.Remove(path)

		return fmt.Errorf("copied only %d bytes (too small)", n)
	}

	return nil
}
