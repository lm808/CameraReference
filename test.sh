#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/Interaction.swift Sources/DetectionConfig.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/Views.swift Sources/Export.swift Sources/Core.swift Sources/ImageSource.swift Sources/Layout.swift tests/main.swift -o build/core-tests
./build/core-tests
texlua tests/plugin-test.lua .
xcrun swiftc -O -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift tests/detection/main.swift -o build/detection-tests
./build/detection-tests
xcrun swiftc -O -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift tests/viewport/main.swift -o build/viewport-tests
./build/viewport-tests
xcrun swiftc -O -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift tests/reset/ResetTests.swift -o build/reset-tests
./build/reset-tests
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/Interaction.swift Sources/DetectionConfig.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/Views.swift Sources/Export.swift Sources/Core.swift Sources/ImageSource.swift Sources/Layout.swift tests/preview/main.swift -o build/preview-tests
./build/preview-tests
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift tests/capture/main.swift -o build/capture-tests
./build/capture-tests
