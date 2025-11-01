package main

import (
	"fmt"
	"strconv"
	"strings"
)

type SemVer struct {
	Major int64
	Minor int64
	Patch int64
}

func NewEmptySemVer() *SemVer {
	return &SemVer{
		Major: 0,
		Minor: 0,
		Patch: 0,
	}
}

func ParseSemVer(str string, allowSuffix bool) (*SemVer, error) {
	str = strings.TrimSpace(str)

	var (
		index  int
		digit  bool
		majorB strings.Builder
		minorB strings.Builder
		patchB strings.Builder
	)

	for i, r := range str {
		if (r < '0' || r > '9') && (!digit || r != '.') {
			if digit {
				if allowSuffix && index == 2 {
					break
				}

				return nil, fmt.Errorf("unexpected token %q at :%d", r, i)
			}

			continue
		}

		digit = true

		if r == '.' {
			index++

			if index > 2 {
				return nil, fmt.Errorf("unexpected token %q at :%d", r, i)
			}

			continue
		}

		switch index {
		case 0:
			majorB.WriteRune(r)
		case 1:
			minorB.WriteRune(r)
		case 2:
			patchB.WriteRune(r)
		}
	}

	major, err := strconv.ParseInt(majorB.String(), 10, 64)
	if err != nil {
		return nil, err
	}

	minor, err := strconv.ParseInt(minorB.String(), 10, 64)
	if err != nil {
		return nil, err
	}

	var patch int64

	if patchB.Len() > 0 {
		patch, err = strconv.ParseInt(patchB.String(), 10, 64)
		if err != nil {
			return nil, err
		}
	}

	return &SemVer{
		Major: major,
		Minor: minor,
		Patch: patch,
	}, nil
}

func (s *SemVer) String() string {
	return fmt.Sprintf("%d.%d.%d", s.Major, s.Minor, s.Patch)
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
