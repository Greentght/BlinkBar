#!/bin/bash
set -euo pipefail

BLINKBAR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BLINKBAR_BUILD_DIR="$BLINKBAR_ROOT/.build"
BLINKBAR_CACHE_DIR="$BLINKBAR_BUILD_DIR/cache"
BLINKBAR_CONFIG_DIR="$BLINKBAR_BUILD_DIR/config"
BLINKBAR_SECURITY_DIR="$BLINKBAR_BUILD_DIR/security"
BLINKBAR_MODULE_CACHE_DIR="$BLINKBAR_BUILD_DIR/.module-cache"
BLINKBAR_SWIFT_TEST_ARGS=(
  --disable-sandbox
  --scratch-path "$BLINKBAR_BUILD_DIR"
  --cache-path "$BLINKBAR_CACHE_DIR"
  --config-path "$BLINKBAR_CONFIG_DIR"
  --security-path "$BLINKBAR_SECURITY_DIR"
  --manifest-cache local
)

mkdir -p "$BLINKBAR_CACHE_DIR" "$BLINKBAR_CONFIG_DIR" "$BLINKBAR_SECURITY_DIR" "$BLINKBAR_MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$BLINKBAR_MODULE_CACHE_DIR"
export SWIFT_MODULECACHE_PATH="$BLINKBAR_MODULE_CACHE_DIR"

if BLINKBAR_XCODE_PATH="$(xcode-select -p 2>/dev/null)"; then
  BLINKBAR_TESTING_FRAMEWORK_DIR="$BLINKBAR_XCODE_PATH/Library/Developer/Frameworks"
  if [ -d "$BLINKBAR_TESTING_FRAMEWORK_DIR/Testing.framework" ]; then
    BLINKBAR_TESTING_RUNTIME_DIR="$BLINKBAR_XCODE_PATH/Library/Developer/usr/lib"
    BLINKBAR_SWIFT_TEST_ARGS+=(
      -Xswiftc -F
      -Xswiftc "$BLINKBAR_TESTING_FRAMEWORK_DIR"
      -Xlinker -F
      -Xlinker "$BLINKBAR_TESTING_FRAMEWORK_DIR"
      -Xlinker -rpath
      -Xlinker "$BLINKBAR_TESTING_FRAMEWORK_DIR"
      -Xlinker -rpath
      -Xlinker "$BLINKBAR_TESTING_RUNTIME_DIR"
    )
  fi
fi

exec swift test "${BLINKBAR_SWIFT_TEST_ARGS[@]}"
