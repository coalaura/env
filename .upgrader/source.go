package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"runtime"
)

type GoRelease struct {
	Version string   `json:"version"`
	Stable  bool     `json:"stable"`
	Files   []GoFile `json:"files"`
}

type GoFile struct {
	Filename string `json:"filename"`
	OS       string `json:"os"`
	Arch     string `json:"arch"`
	SHA256   string `json:"sha256"`
	Kind     string `json:"kind"`
}

type ZigFile struct {
	Tarball string `json:"tarball"`
	SHA256  string `json:"shasum"`
}

func FetchLatestGoVersion() (*SemVer, error) {
	resp, err := metadataClient.Get("https://go.dev/dl/?mode=json")
	if err != nil {
		return nil, err
	}

	body, err := ReadResponse(resp, MaxMetadataSize)
	if err != nil {
		return nil, err
	}

	var releases []GoRelease

	err = json.Unmarshal(body, &releases)
	if err != nil {
		return nil, err
	}

	var latest *SemVer

	for _, release := range releases {
		if !release.Stable {
			continue
		}

		version, err := ParseVersionTag(release.Version, "go")
		if err != nil {
			continue
		}

		if latest == nil || version.HigherThan(latest) {
			latest = version
		}
	}

	if latest == nil {
		return nil, errors.New("no latest Go version found")
	}

	return latest, nil
}

func FetchLatestZigVersion() (*SemVer, error) {
	resp, err := metadataClient.Get("https://ziglang.org/download/index.json")
	if err != nil {
		return nil, err
	}

	body, err := ReadResponse(resp, MaxMetadataSize)
	if err != nil {
		return nil, err
	}

	var versions map[string]json.RawMessage

	err = json.Unmarshal(body, &versions)
	if err != nil {
		return nil, err
	}

	var latest *SemVer

	for name := range versions {
		version, err := ParseSemVer(name, false)
		if err != nil {
			continue
		}

		if latest == nil || version.HigherThan(latest) {
			latest = version
		}
	}

	if latest == nil {
		return nil, errors.New("no latest Zig version found")
	}

	return latest, nil
}

func FetchGoFile(ver *SemVer) (*GoFile, error) {
	resp, err := metadataClient.Get("https://go.dev/dl/?mode=json&include=all")
	if err != nil {
		return nil, err
	}

	body, err := ReadResponse(resp, MaxMetadataSize)
	if err != nil {
		return nil, err
	}

	var releases []GoRelease

	err = json.Unmarshal(body, &releases)
	if err != nil {
		return nil, err
	}

	version := "go" + ver.String()

	for _, release := range releases {
		if release.Version != version {
			continue
		}

		for _, file := range release.Files {
			if file.OS == runtime.GOOS && file.Arch == runtime.GOARCH && file.Kind == GoFileKind() {
				return &file, nil
			}
		}
	}

	return nil, fmt.Errorf("go %s download not found for %s/%s", ver, runtime.GOOS, runtime.GOARCH)
}

func FetchZigFile(ver *SemVer) (*ZigFile, error) {
	resp, err := metadataClient.Get("https://ziglang.org/download/index.json")
	if err != nil {
		return nil, err
	}

	body, err := ReadResponse(resp, MaxMetadataSize)
	if err != nil {
		return nil, err
	}

	var versions map[string]map[string]json.RawMessage

	err = json.Unmarshal(body, &versions)
	if err != nil {
		return nil, err
	}

	version, ok := versions[ver.String()]
	if !ok {
		return nil, fmt.Errorf("zig %s download metadata not found", ver)
	}

	raw, ok := version[ZigPlatform()]
	if !ok {
		return nil, fmt.Errorf("zig %s download not found for %s/%s", ver, runtime.GOOS, runtime.GOARCH)
	}

	var file ZigFile

	err = json.Unmarshal(raw, &file)
	if err != nil {
		return nil, err
	}

	if file.Tarball == "" {
		return nil, errors.New("zig metadata is missing tarball URL")
	}

	_, err = parseSHA256(file.SHA256)
	if err != nil {
		return nil, fmt.Errorf("zig download: %w", err)
	}

	return &file, nil
}

func DownloadGoFile(ver *SemVer) (string, error) {
	file, err := FetchGoFile(ver)
	if err != nil {
		return "", err
	}

	return DownloadTempFile("https://go.dev/dl/"+file.Filename, GoFileExtension(), file.SHA256)
}

func DownloadZigFile(ver *SemVer) (string, error) {
	file, err := FetchZigFile(ver)
	if err != nil {
		return "", err
	}

	return DownloadTempFile(file.Tarball, ZigFileExtension(), file.SHA256)
}
