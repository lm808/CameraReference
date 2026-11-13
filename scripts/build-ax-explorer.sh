#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/AXExplorer/module-cache"
# Compile to a temporary path and replace atomically, including when an older
# explorer is still running. This tool is never part of release staging.
staged_explorer=$(mktemp "$ROOT/build/AXExplorer/.AXExplorer.XXXXXX")
trap 'rm -f "$staged_explorer"' EXIT
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" -swift-version 5 -module-cache-path "$ROOT/build/AXExplorer/module-cache" -O -framework AppKit -framework ApplicationServices \
  "$ROOT/tools/AXExplorer/main.swift" -o "$staged_explorer"
codesign --force --sign - --identifier org.local.CameraReference.AXExplorer "$staged_explorer"
chmod +x "$staged_explorer"
mv -f "$staged_explorer" "$ROOT/build/AXExplorer/AXExplorer"
cp "$ROOT/tools/AXExplorer/Explore.command" "$ROOT/build/AXExplorer/Explore.command"
cp "$ROOT/tools/AXExplorer/README.md" "$ROOT/build/AXExplorer/README.md"
chmod +x "$ROOT/build/AXExplorer/Explore.command"
codesign --verify --strict "$ROOT/build/AXExplorer/AXExplorer"
printf 'Explorer ready: %s\n' "$ROOT/build/AXExplorer/Explore.command"
