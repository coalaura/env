package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"time"
)

const (
	VersionCommandTimeout = 30 * time.Second
	InstallCommandTimeout = 15 * time.Minute
)

func (u *UpgradeConfig) ResolveCurrentVersion() (*SemVer, error) {
	path := u.Path

	if path == "" {
		var err error

		path, err = exec.LookPath(u.Binary)
		if err != nil {
			if errors.Is(err, exec.ErrNotFound) {
				return NewEmptySemVer(), nil
			}

			return nil, err
		}
	} else {
		if _, err := os.Stat(path); err != nil {
			if errors.Is(err, os.ErrNotExist) {
				return NewEmptySemVer(), nil
			}

			return nil, err
		}
	}

	return ResolveBinaryVersion(path, u.Args)
}

func ResolveBinaryVersion(path string, args []string) (*SemVer, error) {
	ctx, cancel := context.WithTimeout(context.Background(), VersionCommandTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, path, args...)

	out, err := cmd.CombinedOutput()
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return nil, fmt.Errorf("version command timed out after %s", VersionCommandTimeout)
		}

		return nil, err
	}

	version, err := ParseSemVer(string(out), true)
	if err != nil {
		return nil, err
	}

	return version, nil
}

func ValidateBinary(path string, args []string, expected *SemVer) error {
	version, err := ResolveBinaryVersion(path, args)
	if err != nil {
		return err
	}

	if !version.Equal(expected) {
		return fmt.Errorf("expected version %s, got %s", expected, version)
	}

	return nil
}

func RunCommandOrError(bin string, args ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), InstallCommandTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, bin, args...)

	out, err := cmd.CombinedOutput()
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return fmt.Errorf("%s timed out after %s", bin, InstallCommandTimeout)
		}

		out = bytes.TrimSpace(out)

		if len(out) == 0 {
			return err
		}

		return fmt.Errorf("%v: %s", err, string(out))
	}

	return nil
}
