#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
  --no-build) ;;
  --testing) bash build.sh --testing ;;
  '') bash build.sh ;;
  *) echo 'Usage: bash scripts/stage.sh [--testing|--no-build]' >&2; exit 2 ;;
esac
mkdir -p release
app_name=CameraReference.app
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build/CameraReference.app/Contents/Info.plist)
if [ "$bundle_id" = org.local.CameraReference.testing ]; then
  app_name='CameraReference Testing.app'
  # Retire the ambiguous old candidate path, never a stable app. Keep its
  # generated payload internally for recovery rather than deleting it.
  if [ -f release/CameraReference.app/Contents/Info.plist ]; then
    old_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' release/CameraReference.app/Contents/Info.plist)
    if [ "$old_id" = org.local.CameraReference.testing ]; then
      retired=$(mktemp -d build/retired-testing.XXXXXX)
      mv release/CameraReference.app "$retired/CameraReference.app"
    fi
  fi
fi
# Checksums avoid replacing unchanged components; changed files are renamed
# into place by rsync. A running app still needs quitting/reopening afterward.
rsync -a --checksum --delete build/CameraReference.app/ "release/$app_name/"
rsync -a --checksum --delete CameraReference.lrplugin/ release/CameraReference.lrplugin/
for source in scripts/Install-Lightroom-Bridge.command docs/INSTALL.md docs/SOURCE-BUILD.md PRIVACY.md RELEASE-NOTES.md; do
  target="release/$(basename "$source")"
  if [ "$source" = 'scripts/Install-Lightroom-Bridge.command' ]; then target='release/Install Lightroom Bridge.command'; fi
  if ! cmp -s "$source" "$target"; then cp -p "$source" "$target"; fi
done
if [ ! -e release/Applications ]; then ln -s /Applications release/Applications; fi
codesign --verify --deep --strict "release/$app_name"
printf 'Ready to test: %s/release/%s\n' "$PWD" "$app_name"
