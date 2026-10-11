#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
repository_root="$(pwd -P)"
if [[ ! -f Formula/mute-on-lock.rb ]]; then
	exit 0
fi
if ! brew tap | rg --quiet --line-regexp 'shields/tap'; then
	brew tap shields/tap "$repository_root"
fi
tap_root="$(brew --repository shields/tap)"
mkdir -p "$tap_root/Formula"
if [[ "$(cd "$tap_root" && pwd -P)" != "$repository_root" ]]; then
	cp Formula/mute-on-lock.rb "$tap_root/Formula/mute-on-lock.rb"
fi
