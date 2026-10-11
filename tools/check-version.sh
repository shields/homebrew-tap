#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
candidate=${1:?Missing candidate version}
current=${2:?Missing current version}
for version in "$candidate" "$current"; do
	[[ $version =~ ^0\.[0-9]{8}\.[1-9][0-9]{0,8}$ ]] || {
		echo "Invalid mute-on-lock version: $version" >&2
		exit 1
	}
done
candidate_date=${candidate#0.}
candidate_count=${candidate_date#*.}
candidate_date=${candidate_date%%.*}
current_date=${current#0.}
current_count=${current_date#*.}
current_date=${current_date%%.*}
if ((10#$candidate_date < 10#$current_date)) ||
	{ ((10#$candidate_date == 10#$current_date)) && ((10#$candidate_count < 10#$current_count)); }; then
	echo "Formula downgrade: $current to $candidate" >&2
	exit 1
fi
