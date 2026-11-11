# Installing Camera Reference 1.0 alpha 2

## Requirements

- macOS 13 or later; macOS 14 or later for automatic detection, capture preview and snapping.
- Lightroom Classic and the included Camera Reference bridge (0.5.1). Development verification used Lightroom Classic 15.6.
- ExifTool for CR3 embedded JPEG extraction/export. Obtain it from https://exiftool.org/ and use Settings → Choose ExifTool if the app cannot find it. A paired standalone JPEG can be used without CR3 extraction.
- Choose the DMG matching your Mac (`arm64` for Apple silicon, `x86_64` for Intel). This build script does not produce a universal binary.

## Application

1. Quit any older Camera Reference process.
2. Open the disk image and drag **CameraReference.app** onto **Applications**.
3. Launch the copy in Applications, not the copy inside the disk image.
4. On first use of automatic detection, allow Screen Recording (or Screen & System Audio Recording, depending on macOS). Accessibility is only used by optional read-only diagnostic tools; core placement does not require it.

The current alpha is ad-hoc signed, not Developer ID signed or notarised. Downloaded copies may be blocked by Gatekeeper. Only proceed if you trust the source; macOS’s Privacy & Security panel may offer **Open Anyway** after a blocked launch. Do not disable Gatekeeper globally. Apple’s instructions: https://support.apple.com/102445 . A notarised release remains future distribution work.

## Lightroom bridge

The bridge must live in a permanent folder, not on the mounted disk image.

1. Run **Install Lightroom Bridge.command** in the disk image. It copies the plugin to `~/Library/Application Support/Camera Reference/Plugins/CameraReference.lrplugin`, backs up an existing copy there, and reveals the installed folder. No administrator access is needed. If macOS blocks the script, you can instead copy the plugin folder manually to that location.
2. In Lightroom: **File → Plug-in Manager → Add**, select the installed `.lrplugin` folder and enable it.
3. If an older bridge entry points to your source checkout or another folder, disable that old entry to avoid running two copies.
4. Run **File → Plug-in Extras → Start / restart Camera Reference bridge**.
5. Eject the disk image after both components are installed.

The installer does not alter Lightroom’s plugin selection. Plugin configuration stays under your control in Plugin Manager.

## Upgrade

Quit the app, replace it in Applications, and restart it. GUI settings and calibration remain in the same macOS preference domain. Advanced settings migrate from `detection.conf` to `config.conf` only if the new file does not exist; the old file stays as a backup. If both files exist, only `config.conf` is authoritative.

Bridge 0.5.1 uses the consolidated folder. Quit the old companion app, stop/disable the old bridge, replace the plugin using the installer, then reload it in Lightroom Plug-in Manager. Start the new companion app. Older bridge versions cannot communicate with this app. Installer backups can be removed after confirming the new bridge works.

## Verify

The menu should say **Camera Reference 1.0 alpha 2**. Bridge diagnostics should report bridge 0.5.1 and a recent heartbeat. Start with Full, Lightroom Develop at Fit, and a known paired/embedded JPEG.

For an installed-from-DMG test, use TESTING.md in the repository. For checksum verification, compare `shasum -a 256 <downloaded.dmg>` with the adjacent `.sha256` download; this detects file corruption, not publisher identity.
