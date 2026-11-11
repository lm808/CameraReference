#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != '--no-build' ]; then bash build.sh; fi
mkdir -p release
# Checksums avoid replacing unchanged components; changed files are renamed
# into place by rsync. A running app still needs quitting/reopening afterward.
rsync -a --checksum --delete build/CameraReference.app/ release/CameraReference.app/
rsync -a --checksum --delete CameraReference.lrplugin/ release/CameraReference.lrplugin/
for source in scripts/Install-Lightroom-Bridge.command docs/INSTALL.md PRIVACY.md RELEASE-NOTES.md; do
  target="release/$(basename "$source")"
  if [ "$source" = 'scripts/Install-Lightroom-Bridge.command' ]; then target='release/Install Lightroom Bridge.command'; fi
  if ! cmp -s "$source" "$target"; then cp -p "$source" "$target"; fi
done
if [ ! -e release/Applications ]; then ln -s /Applications release/Applications; fi
codesign --verify --deep --strict release/CameraReference.app
printf 'Ready to test: %s/release/CameraReference.app\n' "$PWD"
