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
opens formula PRs; required checks must pass before auto-merge. Bottles must
match the published executable checksum and identify the tested source commit.
Published artifacts are immutable, and formula versions must never decrease.
