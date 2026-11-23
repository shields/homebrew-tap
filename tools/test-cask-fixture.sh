#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
case ${0##*/} in
brew)
	case $1 in
	info) jq -n --arg url "$url" --arg hash "$hash" '{casks:[{url:$url,sha256:$hash}]}' ;;
	audit) ;;
	list) exit 1 ;;
	install)
		dir=${3#--appdir=}
		printf '%s\n' "$dir" >"$FIXTURE_ROOT/install"
		mkdir -p "$dir/TypefaceOff.app/Contents"
		plutil -create xml1 "$dir/TypefaceOff.app/Contents/Info.plist"
		for pair in CFBundleIdentifier=com.typefaceoff CFBundleVersion=20261123.1 CFBundleShortVersionString=0.20261123.1; do
			plutil -insert "${pair%=*}" -string "${pair#*=}" "$dir/TypefaceOff.app/Contents/Info.plist"
		done
		;;
	uninstall)
		[[ $HOMEBREW_NO_AUTOREMOVE == 1 && $HOMEBREW_NO_INSTALL_CLEANUP == 1 ]]
		rm -rf "$(cat "$FIXTURE_ROOT/install")/TypefaceOff.app"
		echo uninstalled >"$FIXTURE_ROOT/result"
		;;
	*) exit 2 ;;
	esac
	exit 0
	;;
curl)
	jq -n --arg url "$url" --arg hash "$published_hash" '{immutable:true,assets:[{browser_download_url:$url,digest:("sha256:"+$hash)}]}'
	exit 0
	;;
codesign | spctl | lipo) exit 0 ;;
esac

work=$(mktemp -d)
export FIXTURE_ROOT="$work"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/tap/tools" "$work/tap/Casks" "$work/bin"
cp tools/{test-cask.sh,check-version.sh} "$work/tap/tools/"
git init -q "$work/tap"
echo '  version "0.20261123.1"' >"$work/tap/Casks/typefaceoff.rb"
for command in brew curl codesign spctl lipo; do
	cp "$0" "$work/bin/$command"
	chmod +x "$work/bin/$command"
done
export PATH="$work/bin:$PATH"
export url=https://github.com/shields/typefaceoff/releases/download/v0.20261123.1/TypefaceOff-0.20261123.1.dmg
hash=$(printf '%064d' 1)
export hash published_hash="$hash"
bash "$work/tap/tools/test-cask.sh"
grep -qx uninstalled "$FIXTURE_ROOT/result"
rm "$FIXTURE_ROOT/install"
published_hash=$(printf '%064d' 2)
if bash "$work/tap/tools/test-cask.sh"; then exit 1; fi
[[ ! -e $work/install ]]
