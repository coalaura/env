package main

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
)

func (u *UpgradeConfig) FetchLatestVersion() (*SemVer, error) {
	req, err := http.NewRequest("GET", fmt.Sprintf("https://github.com/%s/tags", u.Repository), nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; upgrader/1.0)")
	req.Header.Set("Accept", "text/html")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()

	html, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var latest *SemVer

	rgx := regexp.MustCompile(`(?i)href="/` + regexp.QuoteMeta(u.Repository) + `/releases/tag/([^"?]+)"`)

	for _, match := range rgx.FindAllSubmatch(html, -1) {
		if len(match) < 2 {
			continue
		}

		tag := string(match[1])
		tag, _ = url.PathUnescape(tag)

		if u.Prefix != "" && !strings.HasPrefix(tag, u.Prefix) {
			continue
		}

		version, err := ParseSemVer(tag, false)
		if err != nil {
			continue
		}

		if latest == nil || version.HigherThan(latest) {
			latest = version
		}
	}

	if latest == nil {
		return nil, errors.New("no latest version found")
	}

	return latest, nil
}
