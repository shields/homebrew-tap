<!--
Copyright © 2026 Michael Shields

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Agents

Use [right-answers](https://github.com/shields/right-answers), especially
`ci.md`, as the canonical source of shared conventions. Homebrew owns Ruby
style.

Use `make setup`, `make lint`, `make fmt`, and `make test`. Release automation
opens formula and cask PRs; required checks must pass before auto-merge. Bottles
must match the published executable checksum and identify the tested source
commit. Published artifacts are immutable, and formula and cask versions must
never decrease.

`make test-bottle` qualifies the published bottle on a clean Homebrew
installation. It installs, starts, stops, and removes the formula, and refuses
an existing installation. CI runs it after the local metadata and verification
tests.

`make test-cask` qualifies the cask at the tip of `origin/main`, a cask that
differs from its merge base with `origin/main`, and any cask when `origin/main`
is absent. The URL must name the Typeface/Off release's disk image, the release
must be immutable, its asset digest must equal the cask's checksum, and
`brew audit --strict` must pass. It reads the release through `gh`, so it needs
`GH_TOKEN` or a logged-in `gh`. The cask is not installed: the Typeface/Off
release checks the image's signature, notarization, and contents before
publishing it, and Homebrew enforces the checksum on download. CI runs it after
`make test-bottle`.
