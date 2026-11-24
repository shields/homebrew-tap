# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

cask "typefaceoff" do
  version "0.20261124.11"
  sha256 "49e272b8f3c70baafb864eb67ecb70938a55aa751680148f2868deb0b58d5241"

  url "https://github.com/shields/typefaceoff/releases/download/v#{version}/TypefaceOff-#{version}.dmg"
  name "Typeface/Off"
  desc "Compare installed fonts, glyph shapes, and language coverage"
  homepage "https://typefaceoff.com/"

  depends_on macos: :sequoia

  app "TypefaceOff.app"
end
