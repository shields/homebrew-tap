# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

cask "typefaceoff" do
  version "0.20261124.15"
  sha256 "e363b91d6a038bc1404ea1c9d04c1409dab7cf216c8e45fe63083b66e6cda541"

  url "https://github.com/shields/typefaceoff/releases/download/v#{version}/TypefaceOff-#{version}.dmg"
  name "Typeface/Off"
  desc "Compare installed fonts, glyph shapes, and language coverage"
  homepage "https://typefaceoff.com/"

  depends_on macos: :sequoia

  app "TypefaceOff.app"
end
