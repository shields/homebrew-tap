# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

class MuteOnLock < Formula
  desc "Mute speakers when macOS locks while leaving headphones playing"
  homepage "https://github.com/shields/mute-on-lock"
  url "https://github.com/shields/mute-on-lock/archive/refs/tags/v0.20261027.2.tar.gz"
  sha256 "27b512236afae1e84afbff5eaf2b177c31b1db324524d4bb2385ffe19e45f4fd"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/shields/mute-on-lock/releases/download/v0.20261027.2"
    sha256 cellar: :any_skip_relocation, arm64_golden_gate: "068b900d42b5cd8b22c22ad59e62d8800542e34b030f64fc81faa38eb579c9b9"
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
    ENV["REVISION"] = "52959eadf4a643e8452f61fc78ffcd601e5b0736"
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
    assert_equal "#{version} (52959eadf4a643e8452f61fc78ffcd601e5b0736)", shell_output("#{bin}/mute-on-lock --version").strip
    assert_match "Mute speaker and unidentified outputs", shell_output("#{bin}/mute-on-lock --help")
  end
end
