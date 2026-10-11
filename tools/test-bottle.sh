#!/bin/bash

# Copyright © 2026 Michael Shields
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail
die() {
	echo "$*" >&2
	exit 1
}
cd "$(dirname "$0")/.."
if [[ ! -f Formula/mute-on-lock.rb ]]; then
	exit 0
fi
formula_name=shields/tap/mute-on-lock
candidate_version=$(sed -n 's/^  version "\([^"]*\)".*/\1/p' Formula/mute-on-lock.rb)
tools/check-version.sh "$candidate_version" "$candidate_version"
if git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null &&
	git cat-file -e refs/remotes/origin/main:Formula/mute-on-lock.rb 2>/dev/null; then
	current_version=$(git show refs/remotes/origin/main:Formula/mute-on-lock.rb | sed -n 's/^  version "\([^"]*\)".*/\1/p')
	tools/check-version.sh "$candidate_version" "$current_version"
fi
brew audit --strict --formula "$formula_name"
brew install --force-bottle "$formula_name"
service_binary="$(brew --prefix "$formula_name")/bin/mute-on-lock"
verification_directory=$(mktemp -d "${TMPDIR:-/tmp}/mute-on-lock-bottle-test.XXXXXX")
trap 'rm -rf "$verification_directory"' EXIT
curl --fail --location --silent --show-error \
	"https://github.com/shields/mute-on-lock/releases/download/v$candidate_version/release.json" \
	-o "$verification_directory/release.json"
jq --exit-status --arg version "$candidate_version" \
	'.version == $version and (.revision | test("^[0-9a-f]{40}$"))' \
	"$verification_directory/release.json"
expected_hash=$(jq --exit-status --raw-output '.executableSHA256' "$verification_directory/release.json")
[[ $expected_hash =~ ^[0-9a-f]{64}$ ]] || die "Invalid published executable checksum"
[[ $(shasum -a 256 "$service_binary" | awk '{print $1}') == "$expected_hash" ]] || die "Bottle executable checksum mismatch"
[[ $("$service_binary" --version) == "$candidate_version ($(jq --raw-output .revision "$verification_directory/release.json"))" ]] || die "Bottle identifies another release"
brew test "$formula_name"
brew services start "$formula_name"
trap 'brew services stop "$formula_name"; rm -rf "$verification_directory"' EXIT
wait_for_service() {
	local attempt running
	for ((attempt = 0; attempt < 100; attempt++)); do
		running=$(brew services info --json "$formula_name" | jq --raw-output '
      if length != 1 or (.[0].running | type) != "boolean" then
        error("Invalid service status")
      else .[0].running end')
		if [[ $running == true ]]; then return 0; fi
		sleep 0.1
	done
	echo "mute-on-lock service did not start" >&2
	return 1
}
wait_for_service
brew services restart "$formula_name"
wait_for_service
brew services stop "$formula_name"
trap 'rm -rf "$verification_directory"' EXIT
brew uninstall "$formula_name"
rm -rf "$verification_directory"
trap - EXIT
