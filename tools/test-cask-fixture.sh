#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
case ${0##*/} in
brew | gh | codesign | spctl | lipo) printf '%s\n' "${0##*/} $*" >>"$FIXTURE_ROOT/calls" ;;
esac
case ${0##*/} in
brew)
	case $1 in
	info) jq -n --arg url "$cask_url" --arg hash "$cask_hash" --argjson count "${FIXTURE_CASKS:-1}" '[range($count) | {url:$url,sha256:$hash}] | {casks:.}' ;;
	audit) ;;
	list)
		[[ ${FIXTURE_INSTALLED:-} == 1 && $4 == typefaceoff ]] || exit 1
		echo typefaceoff 0.20261123.1
		;;
	install)
		[[ $HOMEBREW_NO_AUTOREMOVE == 1 && $HOMEBREW_NO_INSTALL_CLEANUP == 1 ]] || exit 1
		dir=${3#--appdir=}
		printf '%s\n' "$dir" >"$FIXTURE_ROOT/installed"
		mkdir -p "$dir/TypefaceOff.app/Contents"
		plutil -create xml1 "$dir/TypefaceOff.app/Contents/Info.plist"
		for pair in "CFBundleIdentifier=${FIXTURE_BUNDLE_ID:-com.typefaceoff}" "CFBundleVersion=${FIXTURE_BUILD:-20261123.1}" "CFBundleShortVersionString=${FIXTURE_VERSION:-0.20261123.1}"; do
			plutil -insert "${pair%%=*}" -string "${pair#*=}" "$dir/TypefaceOff.app/Contents/Info.plist"
		done
		;;
	uninstall)
		[[ $HOMEBREW_NO_AUTOREMOVE == 1 && $HOMEBREW_NO_INSTALL_CLEANUP == 1 && -e $FIXTURE_ROOT/installed ]] || exit 1
		[[ ${FIXTURE_KEEP:-} == 1 ]] || rm -rf "$(cat "$FIXTURE_ROOT/installed")/TypefaceOff.app"
		rm "$FIXTURE_ROOT/installed"
		;;
	*) exit 2 ;;
	esac
	exit 0
	;;
gh)
	[[ $1 == api && $2 == repos/shields/typefaceoff/releases/tags/v0.20261123.1 ]] || exit 1
	jq -n --argjson immutable "$release_immutable" --arg url "$asset_url" --arg hash "$asset_hash" '{immutable:$immutable,assets:[{browser_download_url:$url,digest:("sha256:"+$hash)}]}'
	exit 0
	;;
codesign)
	[[ ${FIXTURE_FAIL:-} != codesign ]] || {
		echo 'codesign: signature rejected' >&2
		exit 1
	}
	for argument in "$@"; do
		case $argument in
		-R=*)
			# The real codesign rejects a malformed requirement before it examines any code.
			output=$(/usr/bin/codesign --verify "$argument" /bin/ls 2>&1 || true)
			case $output in
			*'invalid or corrupted code requirement'*)
				echo "$output" >&2
				exit 1
				;;
			esac
			;;
		esac
	done
	exit 0
	;;
spctl | lipo) exit 0 ;;
esac

cd "$(dirname "$0")/.."
work=$(mktemp -d "${TMPDIR:-/tmp}/typefaceoff-cask-fixture.XXXXXX")
export FIXTURE_ROOT="$work"
trap 'rm -rf "$work"' EXIT
tap=$work/tap
mkdir -p "$tap/tools" "$tap/Casks" "$work/bin"
cp tools/test-cask.sh tools/check-version.sh "$tap/tools/"
git init -q "$tap"
echo '  version "0.20261123.1"' >"$tap/Casks/typefaceoff.rb"
for command in brew gh codesign spctl lipo; do
	cp tools/test-cask-fixture.sh "$work/bin/$command"
	chmod +x "$work/bin/$command"
done
export PATH="$work/bin:$PATH"
asset=https://github.com/shields/typefaceoff/releases/download/v0.20261123.1/TypefaceOff-0.20261123.1.dmg
digest=$(printf '%064d' 1)
export cask_url=$asset cask_hash=$digest asset_url=$asset asset_hash=$digest release_immutable=true

fail() {
	echo "$*" >&2
	exit 1
}
called() { grep -Eq "$1" "$work/calls"; }
run() {
	: >"$work/calls"
	rm -f "$work/installed"
	env "$@" "$tap/tools/test-cask.sh" >"$work/output" 2>&1
}
accept() {
	if ! run; then
		cat "$work/output" >&2
		fail "Rejected valid cask"
	fi
}
reject() {
	local message=$1
	shift
	if run "$@"; then fail "Accepted invalid cask: $message"; fi
	if ! grep -q "$message" "$work/output"; then
		cat "$work/output" >&2
		fail "Wrong failure for: $message"
	fi
	if [[ -e $work/installed ]]; then fail "Left the cask installed: $message"; fi
	if called '^brew install ' && ! called '^brew uninstall '; then fail "Left the cask installed: $message"; fi
}
untouched() {
	if called '^brew (install|uninstall) '; then fail "Modified an installation: $1"; fi
}

accept
called '^brew info --json=v2 --cask shields/tap/typefaceoff$' || fail "Did not read the cask"
called '^brew audit --strict --cask shields/tap/typefaceoff$' || fail "Did not audit the cask"
called '^brew install --cask --appdir=/.* shields/tap/typefaceoff$' || fail "Did not install the cask"
called '^brew uninstall --cask shields/tap/typefaceoff$' || fail "Did not uninstall the cask"
called '^codesign --verify --deep --strict -R=identifier "com.typefaceoff" and anchor apple generic and certificate leaf\[subject.OU\] = "229AJ92JUV" and ' || fail "Did not check the signature"
called '^spctl --assess --type execute /.*/TypefaceOff.app$' || fail "Did not assess Gatekeeper"
for arch in arm64 x86_64; do
	called "^lipo /.*/TypefaceOff.app/Contents/MacOS/TypefaceOff -verify_arch $arch\$" || fail "Did not check $arch"
done

reject 'does not publish' asset_hash="$(printf '%064d' 2)"
untouched checksum
reject 'does not publish' release_immutable=false
untouched mutable
reject 'does not publish' asset_url=https://example.invalid/TypefaceOff.dmg
untouched asset
reject 'Cask URL is not' cask_url=https://example.invalid/TypefaceOff.dmg
untouched cask
reject 'Invalid cask checksum' cask_hash=no_check
untouched unchecked
reject 'Invalid cask checksum' FIXTURE_CASKS=2
untouched ambiguous
reject 'requires a clean installation' FIXTURE_INSTALLED=1
untouched installed
reject 'Installed app is not com.typefaceoff' FIXTURE_BUNDLE_ID=com.example.other
called '^brew uninstall ' || fail "Kept a mismatched bundle"
reject 'Installed app is not version' FIXTURE_VERSION=0.20261122.1
reject 'Installed app is not build' FIXTURE_BUILD=20261122.1
reject 'left' FIXTURE_KEEP=1
reject 'codesign' FIXTURE_FAIL=codesign
called '^brew uninstall ' || fail "Kept an unsigned bundle"

echo '  version "development"' >"$tap/Casks/typefaceoff.rb"
reject 'Invalid version'
untouched version
echo '  version "0.20261123.1"' >"$tap/Casks/typefaceoff.rb"

git_tap() { git -C "$tap" -c user.name='Cask tests' -c user.email='tests@example.invalid' "$@"; }
base=$(git_tap commit-tree "$(git_tap mktree </dev/null)" -m 'Create tap test fixture')
casks=$(printf '100644 blob %s\ttypefaceoff.rb\n' "$(git_tap hash-object -w Casks/typefaceoff.rb)" | git_tap mktree)
root=$(printf '040000 tree %s\tCasks\n' "$casks" | git_tap mktree)
published=$(git_tap commit-tree "$root" -p "$base" -m 'Publish cask')
git_tap update-ref refs/remotes/origin/main "$published"
git_tap update-ref --no-deref HEAD "$published"

accept
echo '  version "0.20261122.1"' >"$tap/Casks/typefaceoff.rb"
reject 'downgrade'
untouched downgrade
rm "$tap/Casks/typefaceoff.rb"
reject 'Missing published cask'
untouched deletion

git_tap update-ref --no-deref HEAD "$base"
accept
untouched 'branch from before the cask'
