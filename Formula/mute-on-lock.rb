# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

class MuteOnLock < Formula
  desc "Mute speakers when macOS locks while leaving headphones playing"
  homepage "https://github.com/shields/mute-on-lock"
  url "https://github.com/shields/mute-on-lock/archive/refs/tags/v0.20261114.1.tar.gz"
  sha256 "dd73c8abe1c53ab5f422f4d016b540fbe82a8c6b86e4a7f90a9269bf7d03b489"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/shields/mute-on-lock/releases/download/v0.20261114.1"
    sha256 cellar: :any_skip_relocation, arm64_golden_gate: "611caca0c5ffcfca6acaaea7ffa724527f2f69f1d30b3efc0fcd0ee61fc49f88"
  end

  depends_on xcode: ["27.0", :build]
  depends_on arch: :arm64
  depends_on macos: :golden_gate

  resource "swift-argument-parser" do
    url "https://github.com/apple/swift-argument-parser/archive/6a52f3251125d74daf04fcbd5e6f08a75d074382.tar.gz"
    version "1.8.2"
    sha256 "23ab82e8be3b82b199a008e0044229ae327a8824734d917b78bcdde64ce81ec1"
  end

  def install
    resource("swift-argument-parser").stage buildpath/"swift-argument-parser"
    # Homebrew confines the build, and SwiftPM cannot nest its sandbox.
    ENV["SWIFT_BUILD_FLAGS"] = "--disable-sandbox"
    ENV["SWIFT_ARGUMENT_PARSER_PATH"] = (buildpath/"swift-argument-parser").to_s
    ENV["VERSION"] = version.to_s
    ENV["REVISION"] = "b816ccbdde1e05a0a74b170fc8e1bff8301f3f3a"
    # A local dependency graph avoids fetching stale remote pins.
    rm "Package.resolved"
    system "make", "build"
    bin.install ".build/release/mute-on-lock"
    doc.install "README.md"
    pkgshare.install "LICENSE"
  end

  service do
    name macos: "dev.msrl.mute-on-lock"
    run [opt_bin/"mute-on-lock", "run"]
    keep_alive successful_exit: false
    require_root false
    throttle_interval 10
  end

  test do
    assert_equal "#{version} (b816ccbdde1e05a0a74b170fc8e1bff8301f3f3a)", shell_output("#{bin}/mute-on-lock --version").strip
    assert_match "Mute speaker and unidentified outputs", shell_output("#{bin}/mute-on-lock --help")
  end
end
