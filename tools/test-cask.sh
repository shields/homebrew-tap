#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
export HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
cd "$(dirname "$0")/.."
cask=Casks/typefaceoff.rb
name=shields/tap/typefaceoff
if [[ ! -f $cask ]]; then
	if git cat-file -e "origin/main:$cask" 2>/dev/null; then
		echo "Missing published cask $cask" >&2
		exit 1
	fi
	exit 0
fi
version=$(sed -n 's/^  version "\([^"]*\)"$/\1/p' "$cask")
tools/check-version.sh "$version" "$version"
if git cat-file -e "origin/main:$cask" 2>/dev/null; then
	current=$(git show "origin/main:$cask" | sed -n 's/^  version "\([^"]*\)"$/\1/p')
	tools/check-version.sh "$version" "$current"
fi
metadata=$(brew info --json=v2 --cask "$name")
digest=$(jq -er '.casks | select(length == 1) | .[0].sha256 | select(test("^[0-9a-f]{64}$"))' <<<"$metadata")
url="https://github.com/shields/typefaceoff/releases/download/v$version/TypefaceOff-$version.dmg"
[[ $(jq -r '.casks[0].url' <<<"$metadata") == "$url" ]]
curl -fsSL "https://api.github.com/repos/shields/typefaceoff/releases/tags/v$version" |
	jq -e --arg url "$url" --arg digest "sha256:$digest" '.immutable and any(.assets[]; .browser_download_url == $url and .digest == $digest)' >/dev/null
brew audit --strict --cask "$name"
if brew list --cask --versions "$name" >/dev/null 2>&1; then
	echo "$name is already installed" >&2
	exit 1
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
brew install --cask --appdir="$work" "$name"
trap 'brew uninstall --cask "$name"; rm -rf "$work"' EXIT
app="$work/TypefaceOff.app"
codesign --verify --deep --strict -R='identifier "com.typefaceoff" and anchor apple generic and certificate leaf[subject.OU] = "229AJ92JUV" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$app"
spctl --assess --type execute "$app"
info="$app/Contents/Info.plist"
[[ $(plutil -extract CFBundleShortVersionString raw "$info") == "$version" ]]
[[ $(plutil -extract CFBundleVersion raw "$info") == "${version#0.}" ]]
[[ $(plutil -extract CFBundleIdentifier raw "$info") == com.typefaceoff ]]
for arch in arm64 x86_64; do lipo "$app/Contents/MacOS/TypefaceOff" -verify_arch "$arch"; done
brew uninstall --cask "$name"
trap 'rm -rf "$work"' EXIT
[[ ! -e $app ]]
