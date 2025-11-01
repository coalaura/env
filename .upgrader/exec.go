package main

import (
	"bytes"
	"errors"
	"fmt"
	"os/exec"
)

func (u *UpgradeConfig) ResolveCurrentVersion() (*SemVer, error) {
	path, err := exec.LookPath(u.Binary)
	if err != nil {
		if errors.Is(err, exec.ErrNotFound) {
			return NewEmptySemVer(), nil
		}

		return nil, err
	}

	cmd := exec.Command(path, u.Args...)

	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, err
	}

	version, err := ParseSemVer(string(out), true)
	if err != nil {
		return nil, err
	}

	return version, nil
}

func RunCommandOrError(bin string, args ...string) error {
	cmd := exec.Command(bin, args...)

	out, err := cmd.CombinedOutput()
	if err != nil {
		out = bytes.TrimSpace(out)

		if len(out) == 0 {
			return err
		}

		return fmt.Errorf("%v: %s", err, string(out))
	}

	return nil
}
