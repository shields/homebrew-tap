# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

cask "typefaceoff" do
  version "0.20261124.9"
  sha256 "cba4d2b66b22e697493278b464e2515c4ff6c819a57867058399ff37ccdc15cf"

  url "https://github.com/shields/typefaceoff/releases/download/v#{version}/TypefaceOff-#{version}.dmg"
  name "Typeface/Off"
  desc "Compare installed fonts, glyph shapes, and language coverage"
  homepage "https://typefaceoff.com/"

  depends_on macos: :sequoia

  app "TypefaceOff.app"
end
