#!/bin/bash
set -euo pipefail

BLINKBAR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BLINKBAR_BUILD_DIR="$BLINKBAR_ROOT/.build"
BLINKBAR_CACHE_DIR="$BLINKBAR_BUILD_DIR/cache"
BLINKBAR_CONFIG_DIR="$BLINKBAR_BUILD_DIR/config"
BLINKBAR_SECURITY_DIR="$BLINKBAR_BUILD_DIR/security"
BLINKBAR_MODULE_CACHE_DIR="$BLINKBAR_BUILD_DIR/.module-cache"
BLINKBAR_SWIFT_BUILD_ARGS=(
  --configuration release
  --product BlinkBar
  --disable-sandbox
  --scratch-path "$BLINKBAR_BUILD_DIR"
  --cache-path "$BLINKBAR_CACHE_DIR"
  --config-path "$BLINKBAR_CONFIG_DIR"
  --security-path "$BLINKBAR_SECURITY_DIR"
  --manifest-cache local
)

mkdir -p "$BLINKBAR_CACHE_DIR" "$BLINKBAR_CONFIG_DIR" \
  "$BLINKBAR_SECURITY_DIR" "$BLINKBAR_MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$BLINKBAR_MODULE_CACHE_DIR"
export SWIFT_MODULECACHE_PATH="$BLINKBAR_MODULE_CACHE_DIR"

if ! command -v codesign >/dev/null 2>&1; then
  echo "ERROR: codesign is required to sign and verify BlinkBar.app." >&2
  exit 1
fi

echo "Building BlinkBar in release mode…"
swift build "${BLINKBAR_SWIFT_BUILD_ARGS[@]}" || {
  BLINKBAR_STATUS=$?
  echo "ERROR: SwiftPM release build failed." >&2
  echo "If the compiler and MacOSX SDK versions do not match, install matching Command Line Tools or use a matching Xcode toolchain." >&2
  exit "$BLINKBAR_STATUS"
}

BLINKBAR_BIN_DIR="$(swift build "${BLINKBAR_SWIFT_BUILD_ARGS[@]}" --show-bin-path)" || {
  BLINKBAR_STATUS=$?
  echo "ERROR: Could not determine the release binary directory after building." >&2
  exit "$BLINKBAR_STATUS"
}
BLINKBAR_BINARY="$BLINKBAR_BIN_DIR/BlinkBar"
if [ ! -f "$BLINKBAR_BINARY" ] || [ ! -x "$BLINKBAR_BINARY" ]; then
  echo "ERROR: Release executable was not produced at $BLINKBAR_BINARY." >&2
  exit 1
fi

BLINKBAR_APP="$BLINKBAR_ROOT/dist/BlinkBar.app"
BLINKBAR_CONTENTS="$BLINKBAR_APP/Contents"
BLINKBAR_EXECUTABLE="$BLINKBAR_CONTENTS/MacOS/BlinkBar"
BLINKBAR_PLIST="$BLINKBAR_CONTENTS/Info.plist"
rm -rf "$BLINKBAR_APP"
mkdir -p "$BLINKBAR_CONTENTS/MacOS"
cp "$BLINKBAR_BINARY" "$BLINKBAR_EXECUTABLE"
cp "$BLINKBAR_ROOT/Resources/Info.plist" "$BLINKBAR_PLIST"
chmod +x "$BLINKBAR_EXECUTABLE"

if [ ! -f "$BLINKBAR_EXECUTABLE" ] || [ ! -x "$BLINKBAR_EXECUTABLE" ]; then
  echo "ERROR: App executable is missing or not executable: $BLINKBAR_EXECUTABLE." >&2
  exit 1
fi
if ! plutil -lint "$BLINKBAR_PLIST" >/dev/null; then
  echo "ERROR: App Info.plist is invalid: $BLINKBAR_PLIST." >&2
  exit 1
fi
BLINKBAR_PLIST_EXECUTABLE="$(plutil -extract CFBundleExecutable raw -o - "$BLINKBAR_PLIST")"
if [ "$BLINKBAR_PLIST_EXECUTABLE" != "BlinkBar" ]; then
  echo "ERROR: Info.plist CFBundleExecutable is not BlinkBar." >&2
  exit 1
fi

codesign --force --deep --sign - "$BLINKBAR_APP"
codesign --verify --deep --strict --verbose=2 "$BLINKBAR_APP"

echo "Created and verified $BLINKBAR_APP"
file "$BLINKBAR_EXECUTABLE"
plutil -p "$BLINKBAR_PLIST"
