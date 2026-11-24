#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
die() {
	echo "$*" >&2
	exit 1
}
cd "$(dirname "$0")/.."
cask=Casks/typefaceoff.rb
name=shields/tap/typefaceoff
# Compare with the merge base so a branch cut before a cask update is not mistaken for a change or deletion.
base=
if git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null; then
	base=$(git merge-base refs/remotes/origin/main HEAD) || die "No merge base with origin/main"
fi
if [[ ! -f $cask ]]; then
	if [[ -n $base ]] && git cat-file -e "$base:$cask" 2>/dev/null; then
		die "Missing published cask $cask"
	fi
	exit 0
fi
if [[ -n $base && $(git rev-parse HEAD) != "$(git rev-parse refs/remotes/origin/main)" ]] && git show "$base:$cask" 2>/dev/null | cmp -s - "$cask"; then
	echo "$cask is unchanged from its merge base with origin/main; not qualifying it"
	exit 0
fi
version=$(sed -n 's/^  version "\([^"]*\)"$/\1/p' "$cask")
tools/check-version.sh "$version" "$version"
if git cat-file -e "refs/remotes/origin/main:$cask" 2>/dev/null; then
	current=$(git show "refs/remotes/origin/main:$cask" | sed -n 's/^  version "\([^"]*\)"$/\1/p')
	tools/check-version.sh "$version" "$current"
fi
metadata=$(brew info --json=v2 --cask "$name")
digest=$(jq -er '.casks | select(length == 1) | .[0].sha256 | select(test("^[0-9a-f]{64}$"))' <<<"$metadata") || die "Invalid cask checksum"
url="https://github.com/shields/typefaceoff/releases/download/v$version/TypefaceOff-$version.dmg"
[[ $(jq -r '.casks[0].url' <<<"$metadata") == "$url" ]] || die "Cask URL is not $url"
release=$(gh api "repos/shields/typefaceoff/releases/tags/v$version")
jq -e --arg url "$url" --arg digest "sha256:$digest" '.immutable and any(.assets[]; .browser_download_url == $url and .digest == $digest)' >/dev/null <<<"$release" ||
	die "Release v$version is not immutable or does not publish $url with sha256:$digest"
brew audit --strict --cask "$name"
