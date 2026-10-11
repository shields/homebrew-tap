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

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: setup ci-setup setup-tap build lint fmt test run
setup: setup-tap
	bun install --frozen-lockfile
	lefthook install

ci-setup:
	brew install lefthook shellcheck shfmt zizmor ripgrep jq
	git fetch --no-tags origin +refs/heads/main:refs/remotes/origin/main
	$(MAKE) setup

setup-tap:
	./tools/setup-tap.sh

build: lint

lint:
	./tools/check-notices.sh
	bunx --no-install prettier --check .
	shellcheck tools/*.sh
	shfmt -d tools/*.sh
	if [[ -f Formula/mute-on-lock.rb ]]; then brew style Formula/mute-on-lock.rb; fi
	if [[ -d .github/workflows ]]; then zizmor --persona pedantic .github/workflows; fi

fmt:
	bunx --no-install prettier --write .
	shfmt -w tools/*.sh
	if [[ -f Formula/mute-on-lock.rb ]]; then brew style --fix Formula/mute-on-lock.rb; fi

test: setup-tap
	./tools/test-version.sh
	./tools/test-bottle.sh

run: test
