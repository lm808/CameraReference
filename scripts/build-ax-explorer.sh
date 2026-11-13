#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/AXExplorer" "$ROOT/release/AXExplorer" "$ROOT/build/AXExplorer/module-cache"
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" -swift-version 5 -module-cache-path "$ROOT/build/AXExplorer/module-cache" -O -framework AppKit -framework ApplicationServices \
  "$ROOT/tools/AXExplorer/main.swift" -o "$ROOT/build/AXExplorer/AXExplorer"
codesign --force --sign - --identifier org.local.CameraReference.AXExplorer "$ROOT/build/AXExplorer/AXExplorer"
# Replace the executable atomically; in-place overwrites can retain stale macOS
# executable/signature state while an older explorer is still running.
staged_explorer=$(mktemp "$ROOT/release/AXExplorer/.AXExplorer.XXXXXX")
trap 'rm -f "$staged_explorer"' EXIT
cp "$ROOT/build/AXExplorer/AXExplorer" "$staged_explorer"
chmod +x "$staged_explorer"
mv -f "$staged_explorer" "$ROOT/release/AXExplorer/AXExplorer"
cp "$ROOT/tools/AXExplorer/Explore.command" "$ROOT/release/AXExplorer/Explore.command"
cp "$ROOT/tools/AXExplorer/README.md" "$ROOT/release/AXExplorer/README.md"
chmod +x "$ROOT/release/AXExplorer/Explore.command"
codesign --verify --strict "$ROOT/release/AXExplorer/AXExplorer"
printf 'Explorer ready: %s\n' "$ROOT/release/AXExplorer/Explore.command"
