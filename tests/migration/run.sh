#!/bin/bash
# No app launch, live AX/capture, personal preferences or production bridge writes.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/migration-tests
python3 tests/migration/prepare.py
sources=()
for source in Sources/*.swift; do
  case "$source" in Sources/main.swift|Sources/Core.swift|Sources/Diagnostics.swift|Sources/PhotoRequestCoordinator.swift) ;; *) sources+=("$source");; esac
done
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache \
  "${sources[@]}" build/migration-tests/Core.swift build/migration-tests/AppDelegate.swift build/migration-tests/Diagnostics.swift build/migration-tests/PhotoRequestCoordinator.swift \
  tests/migration/LegacyDiagnostics.swift tests/migration/Harness.swift -o build/migration-tests/run
./build/migration-tests/run
