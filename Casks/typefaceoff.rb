# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

cask "typefaceoff" do
  version "0.20261124.13"
  sha256 "f71ccfe103436eba01fb93921edea7f01004970ccc8e01718f4d4d36da195e2d"

  url "https://github.com/shields/typefaceoff/releases/download/v#{version}/TypefaceOff-#{version}.dmg"
  name "Typeface/Off"
  desc "Compare installed fonts, glyph shapes, and language coverage"
  homepage "https://typefaceoff.com/"

  depends_on macos: :sequoia

  app "TypefaceOff.app"
end
