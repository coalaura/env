---
description: Suggest the next release tag name and message
---

Suggest a release tag name and a concise message covering everything that matters in the release.

First inspect all commits and the actual diff between the latest release tag reachable from HEAD and HEAD. If no tags exist, review all committed history. Exclude uncommitted changes.

## Release scope

- Include every distinct change affecting functionality, correctness, performance, security, compatibility, dependencies, installation, or shipped artifacts.
- Skip documentation, CI, tests, formatting, and housekeeping unless they affect the delivered release. Judge changes by their impact, not just their file paths or commit messages.
- Combine related changes without hiding distinct improvements. Omit duplicates and fully reverted changes.

## Tag name

- Use vMAJOR.MINOR.PATCH and choose the smallest sensible, unused version.
- Use patch for compatible fixes and small improvements, minor for new capabilities, major for breaking changes. Judge the complete release, not the number of commits.
- For 0.x releases, use minor bumps for new capabilities or breaking changes. Do not infer readiness for 1.0.0 from change size.

## Tag message

- Write one lowercase line of short, concrete phrases separated by ", ".
- Lead with the most significant changes. Prefer direct wording such as "apng support", "fix animation timing", or "faster extraction".
- Cover every release-relevant change, grouping related details where useful. Keep wording brief without replacing distinct changes with vague catchalls like "various fixes".
- Use no commit prefixes, filler, or trailing punctuation. Never use ", and" or ", or"; conjunctions within a phrase are fine.

## Review and output

Before responding, check that the version fits the changes, every release-relevant change is represented, and every claim is supported by the diff. Remove redundant wording.

Return only the tag name and message in separate code blocks. If nothing warrants a release, say so instead. If the history is incomplete, report the limitation rather than guessing.

Suggest only; do not modify files, create tags, or push anything.

$ARGUMENTS