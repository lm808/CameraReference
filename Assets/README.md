AppIcon.icns is bundled by build.sh. The original icon is drawn with AppKit in make-icon.swift; no downloaded assets or dependencies.

Regenerate from the repository root:

    xcrun swift -module-cache-path build/module-cache Assets/make-icon.swift "$PWD"
    iconutil -c icns build/AppIcon.iconset -o Assets/AppIcon.icns

On this Mac iconutil requires execution outside the sandbox; inside it reported Invalid Iconset for valid PNGs.

TestingIcon.icns uses the same native drawing with a purple camera body. Regenerate with `Assets/make-icon.swift "$PWD" --testing`, then `iconutil -c icns build/TestingIcon.iconset -o Assets/TestingIcon.icns`. `build.sh --testing` uses that icon and the separate testing bundle ID.
