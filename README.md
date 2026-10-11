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

# Shields’s Homebrew tap

Homebrew packages for macOS utilities. Formula updates arrive as pull requests
from release automation in each source repository. Required checks verify the
formula and bottle before GitHub merges the update.

The first formula is added when its release is available.

For development, install Bun and Homebrew, then run `make ci-setup` and
`make lint test`. `make setup` and `make test` register the local repository as
`shields/tap` when it is untapped and copy the checked-out formula into the tap
used by Homebrew. This ensures that local tests and CI test the working tree.

```sh
brew install shields/tap/mute-on-lock
brew services start shields/tap/mute-on-lock
```

Run `brew update` and `brew upgrade shields/tap/mute-on-lock` to get a release,
then `brew services restart shields/tap/mute-on-lock` to run it. The source
project owns versioning, bottle builds, and release assets.

Copyright © 2026 Michael Shields. Licensed under Apache-2.0; see
[LICENSE](LICENSE).
