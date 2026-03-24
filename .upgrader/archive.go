package main

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func ExtractTarGzFile(path, targetDir string) error {
	file, err := OpenFileForReading(path)
	if err != nil {
		return err
	}

	defer file.Close()

	gzr, err := gzip.NewReader(file)
	if err != nil {
		return err
	}

	defer gzr.Close()

	tr := tar.NewReader(gzr)

	for {
		header, err := tr.Next()
		if err != nil {
			if errors.Is(err, io.EOF) {
				return nil
			}

			return err
		}

		name := filepath.Clean(header.Name)
		outPath := filepath.Join(targetDir, name)

		switch header.Typeflag {
		case tar.TypeDir:
			err = os.MkdirAll(outPath, 0755)
			if err != nil {
				return err
			}
		case tar.TypeReg:
			err = os.MkdirAll(filepath.Dir(outPath), 0755)
			if err != nil {
				return err
			}

			out, err := OpenFileForWriting(outPath)
			if err != nil {
				return err
			}

			_, err = io.Copy(out, tr)

			closeErr := out.Close()

			if err != nil {
				return err
			}

			if closeErr != nil {
				return closeErr
			}

			err = os.Chmod(outPath, os.FileMode(header.Mode))
			if err != nil {
				return err
			}
		}
	}
}

func ExtractZipFile(path, targetDir string) error {
	zrd, err := zip.OpenReader(path)
	if err != nil {
		return err
	}

	defer zrd.Close()

	for _, file := range zrd.File {
		name := filepath.Clean(file.Name)
		outPath := filepath.Join(targetDir, name)

		if file.FileInfo().IsDir() {
			err = os.MkdirAll(outPath, 0755)
			if err != nil {
				return err
			}

			continue
		}

		err = os.MkdirAll(filepath.Dir(outPath), 0755)
		if err != nil {
			return err
		}

		in, err := file.Open()
		if err != nil {
			return err
		}

		out, err := OpenFileForWriting(outPath)
		if err != nil {
			in.Close()

			return err
		}

		_, err = io.Copy(out, in)

		closeOutErr := out.Close()
		closeInErr := in.Close()

		if err != nil {
			return err
		}

		if closeOutErr != nil {
			return closeOutErr
		}

		if closeInErr != nil {
			return closeInErr
		}
	}

	return nil
}

func FindFile(root, name string) (string, error) {
	var found string

	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		if strings.EqualFold(info.Name(), name) {
			found = path

			return io.EOF
		}

		return nil
	})

	if err != nil {
		if errors.Is(err, io.EOF) {
			return found, nil
		}

		return "", err
	}

	return "", os.ErrNotExist
}
