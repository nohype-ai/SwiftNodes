#!/bin/zsh
# Build this Swift package as if min macOS were 10.14 (pre-concurrency).
# Drop this script next to any Package.swift and run it to catch unguarded
# async/await (and similar) that Xcode Cloud may hit when platforms: is unset.
#
# Defaults to x86_64 — that matches Xcode Cloud and reliably surfaces
# "concurrency is only available in macOS 10.15" (arm64+10.14 can stay green).
#
# Usage:
#   ./build-for-macos-10.14.sh
#   ARCH=arm64 ./build-for-macos-10.14.sh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

if [[ ! -f Package.swift ]]; then
  print -u2 "error: no Package.swift in $SCRIPT_DIR"
  exit 1
fi

# Prefer a release Xcode if present — betas can rewrite deployment targets and hide errors.
RELEASE_XCODE="/Applications/Xcode-26.6.0.app"
if [[ -d "$RELEASE_XCODE/Contents/Developer" ]]; then
  export DEVELOPER_DIR="$RELEASE_XCODE/Contents/Developer"
elif [[ -n "${DEVELOPER_DIR:-}" ]]; then
  :
else
  export DEVELOPER_DIR="$(xcode-select -p)"
fi

SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
if [[ ! -x "$SWIFT" ]]; then
  SWIFT="$(command -v swift)"
fi

# x86_64 matches Cloud logs and actually enforces the 10.14 concurrency check.
ARCH="${ARCH:-x86_64}"
TARGET="${ARCH}-apple-macosx10.14"

print "package:  $SCRIPT_DIR"
print "swift:    $SWIFT"
print "xcode:    $($SWIFT --version 2>/dev/null | head -1)"
print "target:   $TARGET"
print ""

# Index stores can make a plain rm -rf fail mid-tree; wipe aggressively.
if [[ -d .build ]]; then
  chmod -R u+w .build 2>/dev/null || true
  rm -rf .build
fi

exec "$SWIFT" build \
  -Xswiftc -target -Xswiftc "$TARGET"
