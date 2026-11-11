#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash build.sh
architecture=$(uname -m)
release_name="CameraReference-1.0-alpha-${architecture}"
stage=$(mktemp -d "$PWD/build/package.XXXXXX")
# Fresh staging folder; no removal of a user's previous release or app installation.
ditto build/CameraReference.app "$stage/CameraReference.app"
ln -s /Applications "$stage/Applications"
ditto CameraReference.lrplugin "$stage/CameraReference.lrplugin"
cp scripts/Install-Lightroom-Bridge.command "$stage/Install Lightroom Bridge.command"
cp docs/INSTALL.md "$stage/INSTALL.md"
cp PRIVACY.md "$stage/PRIVACY.md"
cp RELEASE-NOTES.md "$stage/RELEASE-NOTES.md"
chmod +x "$stage/Install Lightroom Bridge.command"
mkdir -p dist
if [ -e "dist/$release_name.dmg" ]; then
  echo "Release already exists: dist/$release_name.dmg. Move it aside before repackaging." >&2
  exit 1
fi
hdiutil create -volname 'Camera Reference 1.0 alpha' -srcfolder "$stage" -format UDZO "dist/$release_name.dmg"
(cd dist && shasum -a 256 "$release_name.dmg" > "$release_name.dmg.sha256")
echo "Package: $PWD/dist/$release_name.dmg"
