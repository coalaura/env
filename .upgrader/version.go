package main

import (
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

var (
	strictVersionRgx = regexp.MustCompile(`^[0-9]+\.[0-9]+(?:\.[0-9]+)?$`)
	outputVersionRgx = regexp.MustCompile(`[0-9]+\.[0-9]+(?:\.[0-9]+)?`)
)

type SemVer struct {
	Major    int64
	Minor    int64
	Patch    int64
	HasPatch bool
}

func NewEmptySemVer() *SemVer {
	return &SemVer{
		Major:    0,
		Minor:    0,
		Patch:    0,
		HasPatch: true,
	}
}

func ParseSemVer(str string, allowSuffix bool) (*SemVer, error) {
	str = strings.TrimSpace(str)

	if allowSuffix {
		str = outputVersionRgx.FindString(str)
	} else if !strictVersionRgx.MatchString(str) {
		return nil, fmt.Errorf("invalid version %q", str)
	}

	if str == "" {
		return nil, errors.New("version not found")
	}

	parts := strings.Split(str, ".")

	major, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return nil, err
	}

	minor, err := strconv.ParseInt(parts[1], 10, 64)
	if err != nil {
		return nil, err
	}

	var (
		patch    int64
		hasPatch bool
	)

	if len(parts) == 3 {
		patch, err = strconv.ParseInt(parts[2], 10, 64)
		if err != nil {
			return nil, err
		}

		hasPatch = true
	}

	return &SemVer{
		Major:    major,
		Minor:    minor,
		Patch:    patch,
		HasPatch: hasPatch,
	}, nil
}

func ParseVersionTag(tag, prefix string) (*SemVer, error) {
	if !strings.HasPrefix(tag, prefix) {
		return nil, errors.New("tag prefix does not match")
	}

	return ParseSemVer(strings.TrimPrefix(tag, prefix), false)
}

func (s *SemVer) String() string {
	if s.HasPatch {
		return fmt.Sprintf("%d.%d.%d", s.Major, s.Minor, s.Patch)
	}

	return fmt.Sprintf("%d.%d", s.Major, s.Minor)
}

func (s *SemVer) HigherThan(b *SemVer) bool {
	if s.Major != b.Major {
		return s.Major > b.Major
	}

	if s.Minor != b.Minor {
		return s.Minor > b.Minor
	}

	if s.Patch != b.Patch {
		return s.Patch > b.Patch
	}

	return false
}

func (s *SemVer) Equal(b *SemVer) bool {
	return s.Major == b.Major && s.Minor == b.Minor && s.Patch == b.Patch
}
