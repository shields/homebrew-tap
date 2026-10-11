#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
case ${0##*/} in
brew)
	printf '%s\n' "$*" >>"$MOCK_LOG"
	case $1 in
	audit | install | test | uninstall) ;;
	--prefix) printf '%s\n' "$MOCK_PREFIX" ;;
	services)
		case $2 in
		start | restart | stop) ;;
		info) printf '[{"running":true}]\n' ;;
		*) exit 64 ;;
		esac
		;;
	*) exit 64 ;;
	esac
	exit 0
	;;
curl)
	[[ $# -eq 7 && $6 == -o ]] || exit 64
	cp "$MOCK_METADATA" "$7"
	exit 0
	;;
mute-on-lock)
	[[ $1 == --version ]] || exit 64
	printf '%s\n' "$MOCK_VERSION"
	exit 0
	;;
esac
cd "$(dirname "$0")/.."
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mute-on-lock-verification.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT
git init --quiet "$test_directory"
mkdir -p "$test_directory/bin" "$test_directory/tools" "$test_directory/Formula" "$test_directory/prefix/bin"
cp tools/test-bottle.sh tools/check-version.sh "$test_directory/tools/"
cp tools/test-verification.sh "$test_directory/bin/mock-command"
chmod +x "$test_directory/bin/mock-command"
ln -s mock-command "$test_directory/bin/brew"
ln -s mock-command "$test_directory/bin/curl"
ln -s "$test_directory/bin/mock-command" "$test_directory/prefix/bin/mute-on-lock"
printf '# Copyright © 2026 Michael Shields\n# SPDX-License-Identifier: Apache-2.0\n  url "https://github.com/shields/mute-on-lock/archive/refs/tags/v0.20261010.1.tar.gz"\n' \
	>"$test_directory/Formula/mute-on-lock.rb"
export MOCK_LOG=$test_directory/calls MOCK_PREFIX=$test_directory/prefix MOCK_METADATA=$test_directory/release.json
export PATH=$test_directory/bin:$PATH
executable_hash=$(shasum -a 256 "$MOCK_PREFIX/bin/mute-on-lock" | awk '{print $1}')
for scenario in valid upgrade current downgrade wrong_hash invalid_hash wrong_version invalid_revision wrong_binary_version; do
	export MOCK_VERSION='0.20261010.1 (aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)'
	jq --null-input --arg hash "$executable_hash" \
		'{copyright:"Copyright © 2026 Michael Shields", license:"Apache-2.0", version:"0.20261010.1", revision:("a" * 40), executableSHA256:$hash}' \
		>"$MOCK_METADATA"
	case $scenario in
	wrong_hash) transformation='.executableSHA256 = ("b" * 64)' ;;
	invalid_hash) transformation='del(.executableSHA256)' ;;
	wrong_version) transformation='.version = "0.20261010.2"' ;;
	invalid_revision) transformation='.revision = "development"' ;;
	wrong_binary_version)
		export MOCK_VERSION='development (unknown)'
		transformation='.'
		;;
	*) transformation='.' ;;
	esac
	jq "$transformation" "$MOCK_METADATA" >"$test_directory/modified.json"
	mv "$test_directory/modified.json" "$MOCK_METADATA"
	git -C "$test_directory" update-ref -d refs/remotes/origin/main
	case $scenario in
	upgrade) base_version=0.20261009.1 ;;
	current) base_version=0.20261010.1 ;;
	downgrade) base_version=0.20261011.1 ;;
	*) base_version= ;;
	esac
	if [[ -n $base_version ]]; then
		base_blob=$(printf '  url "https://github.com/shields/mute-on-lock/archive/refs/tags/v%s.tar.gz"\n' "$base_version" | git -C "$test_directory" hash-object -w --stdin)
		formula_tree=$(printf '100644 blob %s\tmute-on-lock.rb\n' "$base_blob" | git -C "$test_directory" mktree)
		base_tree=$(printf '040000 tree %s\tFormula\n' "$formula_tree" | git -C "$test_directory" mktree)
		base_commit=$(printf 'Create tap test fixture\n' | git -C "$test_directory" -c user.name='Release tests' -c user.email='tests@example.invalid' commit-tree "$base_tree")
		git -C "$test_directory" update-ref refs/remotes/origin/main "$base_commit"
	fi
	: >"$MOCK_LOG"
	status=0
	/bin/bash "$test_directory/tools/test-bottle.sh" >"$test_directory/output" 2>&1 || status=$?
	if [[ $scenario == valid || $scenario == upgrade || $scenario == current ]]; then
		if [[ $status -ne 0 ]]; then
			cat "$test_directory/output"
			exit "$status"
		fi
		rg --quiet '^test shields/tap/mute-on-lock$' "$MOCK_LOG"
		for operation in start restart stop; do
			rg --quiet "^services $operation shields/tap/mute-on-lock$" "$MOCK_LOG"
		done
	else
		[[ $status -ne 0 ]] || {
			echo "Accepted invalid bottle: $scenario" >&2
			exit 1
		}
		if [[ $scenario == downgrade ]]; then
			rg --quiet '^Formula downgrade: 0.20261011.1 to 0.20261010.1$' "$test_directory/output"
			if rg --quiet '^install ' "$MOCK_LOG"; then
				echo 'Installed a formula downgrade' >&2
				exit 1
			fi
		fi
		if rg --quiet '^(test |services start )' "$MOCK_LOG"; then
			echo "Executed an unverified bottle: $scenario" >&2
			exit 1
		fi
	fi
done
