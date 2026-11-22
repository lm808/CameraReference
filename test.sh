#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/Interaction.swift Sources/DetectionConfig.swift Sources/SplitLayout.swift Sources/OverlayBehaviour.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/AXPanelState.swift Sources/PlacementMode.swift Sources/Views.swift Sources/Export.swift Sources/Core.swift Sources/ImageSource.swift Sources/AXTrial.swift Sources/Layout.swift tests/main.swift -o build/core-tests
./build/core-tests
texlua tests/plugin-test.lua .
xcrun swiftc -O -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/SplitLayout.swift Sources/OverlayBehaviour.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/AXPanelState.swift Sources/PlacementMode.swift tests/detection/main.swift -o build/detection-tests
./build/detection-tests
xcrun swiftc -O -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/SplitLayout.swift Sources/OverlayBehaviour.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/AXPanelState.swift Sources/PlacementMode.swift tests/viewport/main.swift -o build/viewport-tests
./build/viewport-tests
xcrun swiftc -O -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/SplitLayout.swift Sources/OverlayBehaviour.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/AXPanelState.swift Sources/PlacementMode.swift tests/reset/ResetTests.swift -o build/reset-tests
./build/reset-tests
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/Interaction.swift Sources/DetectionConfig.swift Sources/SplitLayout.swift Sources/OverlayBehaviour.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/AXPanelState.swift Sources/PlacementMode.swift Sources/Views.swift Sources/Export.swift Sources/Core.swift Sources/ImageSource.swift Sources/AXTrial.swift Sources/Layout.swift tests/preview/main.swift -o build/preview-tests
./build/preview-tests
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/SplitLayout.swift Sources/OverlayBehaviour.swift Sources/Snapping.swift Sources/ViewportDetector.swift Sources/PhotoDetector.swift Sources/ScreenProbe.swift Sources/AXPanelState.swift Sources/PlacementMode.swift tests/capture/main.swift -o build/capture-tests
./build/capture-tests
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/SplitLayout.swift Sources/OverlayBehaviour.swift tests/split/main.swift -o build/split-tests
./build/split-tests

# File-driven advanced settings editor: no live app or AX interaction.
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/DetectionConfig.swift Sources/ConfigEditor.swift tests/config-editor/main.swift -o build/config-editor-tests
./build/config-editor-tests

# Coordinator characterisation; isolated bridge/preferences, no app or live AX.
bash tests/migration/run.sh

# Pure guided calibration calculations, no AX or UI interaction.
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/AXCalibration.swift tests/ax-calibration/main.swift -o build/ax-calibration-tests
./build/ax-calibration-tests
