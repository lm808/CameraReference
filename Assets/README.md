AppIcon.icns is bundled by build.sh. The original icon is drawn with AppKit in make-icon.swift; no downloaded assets or dependencies.

Regenerate from the repository root:

    xcrun swift -module-cache-path build/module-cache Assets/make-icon.swift "$PWD"
    iconutil -c icns build/AppIcon.iconset -o Assets/AppIcon.icns

On this Mac iconutil requires execution outside the sandbox; inside it reported Invalid Iconset for valid PNGs.
