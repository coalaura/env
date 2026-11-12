---
description: Suggest the next release tag name and message
---

Suggest the next release tag and a short tag message. Suggest only: do not modify files, create tags, or push.

## Gather
- Find the latest tag reachable from HEAD (`git describe --tags --abbrev=0`) and review both the commits and the actual diff from it to HEAD. If no tags exist, review all committed history. Ignore uncommitted changes.
- Check `git tag` so the suggested version is unused.

## Scope
Include changes that affect what ships: functionality, fixes, performance, security, compatibility, dependencies, installation, or artifacts. Skip docs, CI, tests, formatting, and housekeeping unless they change the delivered release. Judge by actual impact, not file paths or commit messages. Merge related changes; drop duplicates and fully reverted work.

## Version
Use `vMAJOR.MINOR.PATCH` with the smallest sensible bump for the release as a whole, not the commit count. Use patch for compatible fixes and small improvements, minor for new capabilities, and major for breaking changes. On 0.x, new capabilities or breaking changes bump minor, and change size alone never justifies 1.0.0.

## Message
One lowercase line of short, concrete phrases separated by ", ", most significant first, e.g. `apng support, fix animation timing, faster extraction`.
- Represent every distinct release-relevant change, grouping related details; no vague catchalls like "various fixes".
- No commit prefixes, filler, trailing punctuation, or ", and" / ", or" between items (conjunctions inside a phrase are fine).
- Every claim must be supported by the diff.

## Output
Only the tag name and the message, each in its own code block. If nothing warrants a release, say so instead. If history is incomplete (e.g. a shallow clone), report the limitation rather than guessing.

Additional notes (may be empty): $ARGUMENTS