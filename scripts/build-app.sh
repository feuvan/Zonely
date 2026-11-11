#!/bin/zsh
set -euo pipefail

# Builds build/Zonely.app for the current architecture.
# Set UNIVERSAL=1 to build one binary for both arm64 and x86_64 (needs Xcode).

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

BUILD_FLAGS=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  BUILD_FLAGS+=(--arch arm64 --arch x86_64)
fi

cd "$ROOT_DIR"
swift build "${BUILD_FLAGS[@]}"
BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
APP_PATH="$ROOT_DIR/build/Zonely.app"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/Zonely" "$APP_PATH/Contents/MacOS/Zonely"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/Zonely")"
  if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
    printf 'Expected a universal binary, got: %s\n' "$ARCHS" >&2
    exit 1
  fi
fi

printf 'Built %s\n' "$APP_PATH"
