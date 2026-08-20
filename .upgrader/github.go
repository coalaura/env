package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

type GitHubAsset struct {
	Name   string `json:"name"`
	URL    string `json:"browser_download_url"`
	Digest string `json:"digest"`
}

type GitHubRelease struct {
	TagName    string        `json:"tag_name"`
	Draft      bool          `json:"draft"`
	Prerelease bool          `json:"prerelease"`
	Assets     []GitHubAsset `json:"assets"`
}

type GitHubTag struct {
	Name string `json:"name"`
}

func (u *UpgradeConfig) FetchLatestVersion() (*SemVer, error) {
	if u.Resolver != nil {
		return u.Resolver()
	}

	endpoint := "tags"
	if u.Releases {
		endpoint = "releases"
	}

	next := fmt.Sprintf("https://api.github.com/repos/%s/%s?per_page=100", u.Repository, endpoint)

	var latest *SemVer

	for next != "" {
		resp, err := githubRequest(next)
		if err != nil {
			return nil, err
		}

		body, err := ReadResponse(resp, MaxMetadataSize)
		if err != nil {
			return nil, err
		}

		var names []string

		if u.Releases {
			var releases []GitHubRelease

			err = json.Unmarshal(body, &releases)
			if err != nil {
				return nil, err
			}

			for _, release := range releases {
				if !release.Draft && !release.Prerelease {
					names = append(names, release.TagName)
				}
			}
		} else {
			var tags []GitHubTag

			err = json.Unmarshal(body, &tags)
			if err != nil {
				return nil, err
			}

			for _, tag := range tags {
				names = append(names, tag.Name)
			}
		}

		for _, name := range names {
			version, err := ParseVersionTag(name, u.Prefix)
			if err != nil {
				continue
			}

			if latest == nil || version.HigherThan(latest) {
				latest = version
			}
		}

		next = ""
	}

	if latest == nil {
		return nil, errors.New("no latest version found")
	}

	return latest, nil
}

func DownloadGitHubAssetTemp(repository, tag, asset, ext string) (string, error) {
	info, err := FetchGitHubAsset(repository, tag, asset)
	if err != nil {
		return "", err
	}

	return DownloadTempFile(info.URL, ext, info.Digest)
}

func InstallGitHubExecutable(repository, tag, asset, path string, ver *SemVer, args []string) error {
	info, err := FetchGitHubAsset(repository, tag, asset)
	if err != nil {
		return err
	}

	tmp, err := DownloadTempFile(info.URL, filepath.Ext(asset), info.Digest)
	if err != nil {
		return err
	}

	defer os.Remove(tmp)

	err = os.Chmod(tmp, 0755)
	if err != nil {
		return err
	}

	err = ValidateBinary(tmp, args, ver)
	if err != nil {
		return err
	}

	return CopyFileMode(tmp, path, 0755)
}

func FetchGitHubAsset(repository, tag, name string) (*GitHubAsset, error) {
	uri := fmt.Sprintf("https://api.github.com/repos/%s/releases/tags/%s", repository, url.PathEscape(tag))

	resp, err := githubRequest(uri)
	if err != nil {
		return nil, err
	}

	body, err := ReadResponse(resp, MaxMetadataSize)
	if err != nil {
		return nil, err
	}

	var release GitHubRelease

	err = json.Unmarshal(body, &release)
	if err != nil {
		return nil, err
	}

	for _, asset := range release.Assets {
		if asset.Name != name {
			continue
		}

		_, err = parseSHA256(asset.Digest)
		if err != nil {
			return nil, fmt.Errorf("asset %s: %w", name, err)
		}

		return &asset, nil
	}

	return nil, fmt.Errorf("asset %s not found in %s release %s", name, repository, tag)
}

func githubRequest(uri string) (*http.Response, error) {
	req, err := http.NewRequest(http.MethodGet, uri, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", "env-upgrader/1.0")
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	if token := strings.TrimSpace(os.Getenv("GITHUB_TOKEN")); token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	return metadataClient.Do(req)
}
