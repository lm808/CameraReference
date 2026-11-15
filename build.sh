#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
  '') testing=false ;;
  --testing) testing=true ;;
  *) echo 'Usage: bash build.sh [--testing]' >&2; exit 2 ;;
esac
app_executable=CameraReference
if "$testing"; then app_executable=CameraReferenceTesting; fi
mkdir -p build/CameraReference.app/Contents/MacOS build/module-cache
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" -swift-version 5 -O -module-cache-path build/module-cache Sources/Interaction.swift Sources/Calibration.swift Sources/Shortcut.swift Sources/DetectionConfig.swift Sources/ConfigEditor.swift Sources/SplitLayout.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/AXAssisted.swift Sources/Permissions.swift Sources/Export.swift Sources/Core.swift Sources/ImageSource.swift Sources/AXTrial.swift Sources/Layout.swift Sources/Views.swift Sources/main.swift -o "build/CameraReference.app/Contents/MacOS/$app_executable"
mkdir -p build/CameraReference.app/Contents/Resources
cp Assets/AppIcon.icns build/CameraReference.app/Contents/Resources/AppIcon.icns
cat > build/CameraReference.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CameraReference</string>
<key>CFBundleIdentifier</key><string>org.local.CameraReference</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundleName</key><string>CameraReference</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.31</string>
<key>CFBundleVersion</key><string>55</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if "$testing"; then
  cp Assets/TestingIcon.icns build/CameraReference.app/Contents/Resources/AppIcon.icns
  /usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable CameraReferenceTesting' build/CameraReference.app/Contents/Info.plist
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier org.local.CameraReference.testing' build/CameraReference.app/Contents/Info.plist
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName CameraReference Testing' build/CameraReference.app/Contents/Info.plist
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string Camera Reference Testing' build/CameraReference.app/Contents/Info.plist
fi
# Remove only the obsolete generated executable when changing build flavour.
if "$testing"; then
  rm -f build/CameraReference.app/Contents/MacOS/CameraReference
else
  rm -f build/CameraReference.app/Contents/MacOS/CameraReferenceTesting
fi
codesign --force --sign - build/CameraReference.app
printf 'Built %s/build/CameraReference.app\n' "$PWD"
