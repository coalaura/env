package main

import "os"

var (
	userHomeDir string
)

func UserHomeDir() (string, error) {
	if userHomeDir == "" {
		dir, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}

		userHomeDir = dir
	}

	return userHomeDir, nil
}
