#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
# Homebrew selects its tap-specific RuboCop rules and index by the path under Library/Taps.
tap="$(brew --repository)/Library/Taps/shields/homebrew-style-$$"
mkdir -p "${tap%/*}"
mkdir "$tap"
trap 'rm -rf "$tap"' EXIT
shopt -s nullglob
files=(Formula/*.rb Casks/*.rb)
if ((${#files[@]} == 0)); then exit 0; fi
for file in "${files[@]}"; do
	mkdir -p "$tap/${file%/*}"
	cp "$file" "$tap/$file"
done
brew style "$@" "${files[@]/#/$tap/}"
if [[ ${1:-} == --fix ]]; then
	for file in "${files[@]}"; do
		if ! cmp -s "$tap/$file" "$file"; then cp "$tap/$file" "$file"; fi
	done
fi
