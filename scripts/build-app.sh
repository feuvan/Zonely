#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"
APP_PATH="$ROOT_DIR/build/Zonely.app"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/Zonely" "$APP_PATH/Contents/MacOS/Zonely"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"

printf 'Built %s\n' "$APP_PATH"
