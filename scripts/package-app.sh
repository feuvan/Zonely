#!/bin/zsh
set -euo pipefail

# Packages a universal Zonely.app as build/Zonely-<version>-macos.zip with a
# SHA-256 checksum file.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-local}"
if [[ ! "$VERSION" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  printf 'Invalid version: use letters, numbers, dots, underscores, or hyphens.\n' >&2
  exit 1
fi

# Zonely 0.1.x looks for this exact name when it updates itself.
ARCHIVE_NAME="Zonely-${VERSION}-macos.zip"
ARCHIVE_PATH="$ROOT_DIR/build/$ARCHIVE_NAME"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

cd "$ROOT_DIR"
UNIVERSAL=1 ./scripts/build-app.sh

BUNDLE_VERSION="${VERSION#v}"
if [[ "$BUNDLE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUNDLE_VERSION" build/Zonely.app/Contents/Info.plist
fi
plutil -lint build/Zonely.app/Contents/Info.plist

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "build/Zonely.app" "$ARCHIVE_PATH"
(
  cd build
  shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

printf 'Packaged %s\n' "$ARCHIVE_PATH"
printf 'Checksum %s\n' "$CHECKSUM_PATH"
