#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
case ${0##*/} in
brew)
	printf '%s\n' "brew $*" >>"$FIXTURE_ROOT/calls"
	case $1 in
	info) jq -n --arg url "$cask_url" --arg hash "$cask_hash" --argjson count "${FIXTURE_CASKS:-1}" '[range($count) | {url:$url,sha256:$hash}] | {casks:.}' ;;
	audit) [[ ${FIXTURE_FAIL:-} != audit ]] || {
		echo 'brew audit: offense' >&2
		exit 1
	} ;;
	*) exit 2 ;;
	esac
	exit 0
	;;
gh)
	printf '%s\n' "gh $*" >>"$FIXTURE_ROOT/calls"
	[[ $1 == api && $2 == "repos/shields/typefaceoff/releases/tags/v$release_version" ]] || {
		echo 'gh: Not Found (HTTP 404)' >&2
		exit 1
	}
	jq -n --argjson immutable "$release_immutable" --arg url "$asset_url" --arg hash "$asset_hash" '{immutable:$immutable,assets:[{browser_download_url:$url,digest:("sha256:"+$hash)}]}'
	exit 0
	;;
esac

cd "$(dirname "$0")/.."
work=$(mktemp -d "${TMPDIR:-/tmp}/typefaceoff-cask-fixture.XXXXXX")
export FIXTURE_ROOT="$work"
trap 'rm -rf "$work"' EXIT
tap=$work/tap
mkdir -p "$tap/tools" "$tap/Casks" "$work/bin"
cp tools/test-cask.sh tools/check-version.sh "$tap/tools/"
git init -q "$tap"
for command in brew gh; do
	cp tools/test-cask-fixture.sh "$work/bin/$command"
	chmod +x "$work/bin/$command"
done
export PATH="$work/bin:$PATH"
asset=https://github.com/shields/typefaceoff/releases/download/v0.20261123.1/TypefaceOff-0.20261123.1.dmg
digest=$(printf '%064d' 1)
export cask_url=$asset cask_hash=$digest asset_url=$asset asset_hash=$digest release_immutable=true release_version=0.20261123.1
write_cask() { echo "  version \"$1\"" >"$tap/Casks/typefaceoff.rb"; }

fail() {
	echo "$*" >&2
	exit 1
}
called() { grep -Eq "$1" "$work/calls"; }
run() {
	: >"$work/calls"
	env "$@" "$tap/tools/test-cask.sh" >"$work/output" 2>&1
}
accept() {
	if ! run "$@"; then
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
}
qualified() {
	called '^brew info --json=v2 --cask shields/tap/typefaceoff$' || fail "Did not read the cask: $1"
	called '^gh api repos/shields/typefaceoff/releases/tags/v' || fail "Did not read the release: $1"
	called '^brew audit --strict --cask shields/tap/typefaceoff$' || fail "Did not audit the cask: $1"
}
skipped() {
	if [[ -s $work/calls ]]; then fail "Qualified an unchanged cask: $1"; fi
}

write_cask 0.20261123.1
accept
qualified 'new cask'

reject 'does not publish' asset_hash="$(printf '%064d' 2)"
reject 'does not publish' release_immutable=false
reject 'does not publish' asset_url=https://example.invalid/TypefaceOff.dmg
reject 'Cask URL is not' cask_url=https://example.invalid/TypefaceOff.dmg
reject 'Invalid cask checksum' cask_hash=no_check
reject 'Invalid cask checksum' FIXTURE_CASKS=2
reject 'brew audit' FIXTURE_FAIL=audit
reject 'HTTP 404' release_version=0.20261122.1

write_cask development
reject 'Invalid version'
if called '^(brew|gh) '; then fail "Read metadata for an invalid version"; fi

git_tap() { git -C "$tap" -c user.name='Cask tests' -c user.email='tests@example.invalid' "$@"; }
commit_cask() {
	local blob casks root
	blob=$(printf '  version "%s"\n' "$1" | git_tap hash-object -w --stdin)
	casks=$(printf '100644 blob %s\ttypefaceoff.rb\n' "$blob" | git_tap mktree)
	root=$(printf '040000 tree %s\tCasks\n' "$casks" | git_tap mktree)
	git_tap commit-tree "$root" -p "$2" -m "Publish cask $1"
}
empty=$(git_tap commit-tree "$(git_tap mktree </dev/null)" -m 'Create tap test fixture')
published=$(commit_cask 0.20261123.1 "$empty")
git_tap update-ref refs/remotes/origin/main "$published"
git_tap update-ref --no-deref HEAD "$published"

write_cask 0.20261123.1
accept
qualified 'default branch'
reject 'does not publish' asset_hash="$(printf '%064d' 2)"

git_tap update-ref --no-deref HEAD "$(commit_cask 0.20261123.1 "$published")"
accept
skipped 'branch with the published cask'
accept asset_hash="$(printf '%064d' 2)"
skipped 'branch with the published cask and a changed release'
git_tap update-ref --no-deref HEAD "$published"

write_cask 0.20261123.2
export cask_url=${asset//0.20261123.1/0.20261123.2} asset_url=${asset//0.20261123.1/0.20261123.2} release_version=0.20261123.2
accept
qualified 'updated cask'
export cask_url=$asset asset_url=$asset release_version=0.20261123.1

write_cask 0.20261122.1
reject 'downgrade'
rm "$tap/Casks/typefaceoff.rb"
reject 'Missing published cask'
skipped 'deleted cask'

git_tap update-ref --no-deref HEAD "$empty"
accept
skipped 'branch from before the cask'

git_tap update-ref refs/remotes/origin/main "$empty"
git_tap update-ref --no-deref HEAD "$(git_tap commit-tree "$(git_tap mktree </dev/null)" -p "$empty" -m 'Add cask')"
write_cask 0.20261123.1
accept
qualified 'cask added to a default branch without one'

git_tap update-ref --no-deref HEAD "$(git_tap commit-tree "$(git_tap mktree </dev/null)" -m 'Unrelated history')"
reject 'No merge base'

newer=$(commit_cask 0.20261124.1 "$published")
git_tap update-ref refs/remotes/origin/main "$newer"
git_tap update-ref --no-deref HEAD "$published"
write_cask 0.20261123.1
accept
skipped 'branch from before a cask update'
