#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Explicit packaging only. Package the staged/tested payload, never rebuild it.
stage="$PWD/release"
app_name=CameraReference.app
if [ ! -d "$stage/$app_name" ] && [ -d "$stage/CameraReference Testing.app" ]; then app_name='CameraReference Testing.app'; fi
for item in "$app_name" CameraReference.lrplugin 'Install Lightroom Bridge.command' INSTALL.md SOURCE-BUILD.md PRIVACY.md RELEASE-NOTES.md Applications; do
  if [ ! -e "$stage/$item" ]; then echo "Missing staged component: $item. Run scripts/stage.sh first." >&2; exit 1; fi
done
codesign --verify --deep --strict "$stage/$app_name"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$stage/$app_name/Contents/Info.plist")
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$stage/$app_name/Contents/Info.plist")
architecture=$(lipo -archs "$stage/$app_name/Contents/MacOS/$executable" | tr ' ' '-')
release_name="CameraReference-${version}-${architecture}"
if [ "$app_name" = 'CameraReference Testing.app' ]; then release_name="${release_name}-testing"; fi
mkdir -p dist
if [ -e "dist/$release_name.dmg" ]; then
  echo "Release already exists: dist/$release_name.dmg. Move it aside before repackaging." >&2
  exit 1
fi
hdiutil create -volname "CameraReference $version" -srcfolder "$stage" -format UDZO "dist/$release_name.dmg"
(cd dist && shasum -a 256 "$release_name.dmg" > "$release_name.dmg.sha256")
echo "Package: $PWD/dist/$release_name.dmg"
