#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
tools/check-version.sh 0.20261010.10 0.20261010.9
tools/check-version.sh 0.20261011.1 0.20261010.99
tools/check-version.sh 0.20261010.1 0.20261010.1
for pair in '0.20261010.9 0.20261010.10' '0.20261009.99 0.20261010.1' 'development 0.20261010.1'; do
	read -r candidate current <<<"$pair"
	if tools/check-version.sh "$candidate" "$current" 2>/dev/null; then
		echo "Accepted invalid update: $pair" >&2
		exit 1
	fi
done
