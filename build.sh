#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/CameraReference.app/Contents/MacOS build/module-cache
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" -swift-version 5 -O -module-cache-path build/module-cache Sources/Interaction.swift Sources/Calibration.swift Sources/Shortcut.swift Sources/DetectionConfig.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/Permissions.swift Sources/Export.swift Sources/Core.swift Sources/ImageSource.swift Sources/Layout.swift Sources/Views.swift Sources/main.swift -o build/CameraReference.app/Contents/MacOS/CameraReference
mkdir -p build/CameraReference.app/Contents/Resources
cp Assets/AppIcon.icns build/CameraReference.app/Contents/Resources/AppIcon.icns
cat > build/CameraReference.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CameraReference</string>
<key>CFBundleIdentifier</key><string>org.local.CameraReference</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>CameraReference</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.9.7</string>
<key>CFBundleVersion</key><string>20</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - build/CameraReference.app
printf 'Built %s/build/CameraReference.app\n' "$PWD"
