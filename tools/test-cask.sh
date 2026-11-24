#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
die() {
	echo "$*" >&2
	exit 1
}
export HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
cd "$(dirname "$0")/.."
cask=Casks/typefaceoff.rb
name=shields/tap/typefaceoff
# A branch cut before the cask was published has not deleted it, so look at the merge base.
if [[ ! -f $cask ]]; then
	if base=$(git merge-base origin/main HEAD 2>/dev/null) && git cat-file -e "$base:$cask" 2>/dev/null; then
		die "Missing published cask $cask"
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
digest=$(jq -er '.casks | select(length == 1) | .[0].sha256 | select(test("^[0-9a-f]{64}$"))' <<<"$metadata") || die "Invalid cask checksum"
url="https://github.com/shields/typefaceoff/releases/download/v$version/TypefaceOff-$version.dmg"
[[ $(jq -r '.casks[0].url' <<<"$metadata") == "$url" ]] || die "Cask URL is not $url"
release=$(gh api "repos/shields/typefaceoff/releases/tags/v$version")
jq -e --arg url "$url" --arg digest "sha256:$digest" '.immutable and any(.assets[]; .browser_download_url == $url and .digest == $digest)' >/dev/null <<<"$release" ||
	die "Release v$version is not immutable or does not publish $url with sha256:$digest"
brew audit --strict --cask "$name"
# brew list matches Caskroom directory names, so a tap-qualified name never matches.
if brew list --cask --versions "${name##*/}" >/dev/null 2>&1; then
	die "Cask qualification requires a clean installation of $name"
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/typefaceoff-cask-test.XXXXXX")
installed=false
cleanup() {
	local status=$?
	trap - EXIT
	if $installed; then brew uninstall --cask "$name" || status=$?; fi
	rm -rf "$work"
	exit "$status"
}
trap cleanup EXIT
brew install --cask --appdir="$work" "$name"
installed=true
app="$work/TypefaceOff.app"
codesign --verify --deep --strict -R='identifier "com.typefaceoff" and anchor apple generic and certificate leaf[subject.OU] = "229AJ92JUV" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$app"
spctl --assess --type execute "$app"
info="$app/Contents/Info.plist"
[[ $(plutil -extract CFBundleShortVersionString raw "$info") == "$version" ]] || die "Installed app is not version $version"
[[ $(plutil -extract CFBundleVersion raw "$info") == "${version#0.}" ]] || die "Installed app is not build ${version#0.}"
[[ $(plutil -extract CFBundleIdentifier raw "$info") == com.typefaceoff ]] || die "Installed app is not com.typefaceoff"
for arch in arm64 x86_64; do lipo "$app/Contents/MacOS/TypefaceOff" -verify_arch "$arch"; done
brew uninstall --cask "$name"
installed=false
[[ ! -e $app ]] || die "Uninstalling $name left $app"
