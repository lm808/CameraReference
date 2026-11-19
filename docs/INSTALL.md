# Installing Camera Reference

For manual source builds, older-commit recovery, and stable/candidate Git worktrees, see [Building from source and keeping a working version](SOURCE-BUILD.md).

## Requirements

- macOS 13 or later; macOS 14 or later for screenshot detection, capture preview and snapping (Accessibility placement does not require macOS 14).
- Lightroom Classic and the included Camera Reference bridge (0.5.3). Development verification used Lightroom Classic 15.6.
- ExifTool for CR3/ARW embedded JPEG extraction/export. Obtain it from https://exiftool.org/ and use Settings → Choose ExifTool if the app cannot find it. A paired standalone JPEG can be used without embedded extraction.
- Choose the DMG matching your Mac (`arm64` for Apple silicon, `x86_64` for Intel). This build script does not produce a universal binary.

## Testing from the repository

Run `bash scripts/stage.sh` to build and refresh release/. Launch **release/CameraReference.app**; build/ is internal. Quit and reopen that release/ app after an update to load the new executable. The staging command updates only changed files and does not make a DMG.

## Application

1. Quit any older Camera Reference process.
2. Open the disk image and drag **CameraReference.app** onto **Applications**.
3. Launch the copy in Applications, not the copy inside the disk image.
4. AX-only placement uses Accessibility access and always detects the view. Screen Recording is optional and is never requested by the app. Grant it yourself in macOS Privacy & Security if you want screenshot detection, capture previews or calibration snapping. Without it, manual calibration works without snapping.

The current build is ad-hoc signed, not Developer ID signed or notarised. Downloaded copies may be blocked by Gatekeeper. Only proceed if you trust the source; macOS’s Privacy & Security panel may offer **Open Anyway** after a blocked launch. Do not disable Gatekeeper globally. Apple’s instructions: https://support.apple.com/102445 . A notarised release remains future distribution work.

## Lightroom bridge

The bridge must live in a permanent folder, not on the mounted disk image.

1. Run **Install Lightroom Bridge.command** in release/ or the disk image. It copies the plugin to `~/Library/Application Support/CameraReference/Plugins/CameraReference.lrplugin`, backs up an existing copy there, and reveals the installed folder. No administrator access is needed. If macOS blocks the script, you can instead copy the plugin folder manually to that location.
2. In Lightroom: **File → Plug-in Manager → Add**, select the installed `.lrplugin` folder and enable it.
3. If an older bridge entry points to your source checkout or another folder, disable that old entry to avoid running two copies.
4. Run **File → Plug-in Extras → Start / restart Camera Reference bridge**.
5. If using a disk image, eject it after both components are installed.

The installer does not alter Lightroom’s plugin selection. Plugin configuration stays under your control in Plugin Manager.

## Upgrade

Quit the app, replace it in Applications, and restart it. GUI settings and calibration remain in the same macOS preference domain. Advanced settings migrate from `detection.conf` to `config.conf` only if the new file does not exist; the old file stays as a backup. If both files exist, only `config.conf` is authoritative.

Bridge 0.5.3 uses the unspaced CameraReference/Bridge folder. Quit the old companion app, stop/disable the old bridge, replace the plugin using the installer, then reload it in Lightroom Plug-in Manager. Start the new companion app from release/. The old spaced support directory merges into CameraReference after the old bridge stops. If the plugin was previously inside the spaced folder, re-add it from CameraReference/Plugins after migration. Older bridge versions cannot communicate with this app. Installer backups can be removed after confirming the new bridge works.

## Verify

The menu should show the version you installed (candidate source: **1.1.6**). Developer tools → Diagnostics… should report bridge 0.5.3 and a recent heartbeat. Start with Loupe View, Lightroom Develop at Fit, and a known paired/embedded JPEG.

Use TESTING.md in the repository for staged-app acceptance; DMG installation is tested only when a package is requested. For checksum verification, compare `shasum -a 256 <downloaded.dmg>` with the adjacent `.sha256` download; this detects file corruption, not publisher identity.

### Stable and testing copies

Use `bash scripts/stage.sh --testing` in the candidate worktree for Camera Reference Testing (purple icon, `org.local.CameraReference.testing`). Stable builds keep `org.local.CameraReference`. Keep main’s accepted app while testing; quit one before starting the other because settings/bridge are shared. The testing identity uses its own permissions entries: Accessibility for AX features, optional Screen Recording for screenshot features. Separate identity protects stable’s permissions entry; ad-hoc-signed testing updates may still require renewed approval. No permission is granted or reset by the build scripts.

Testing app path: `release/CameraReference Testing.app` (purple with T badge). Add this exact file in permission settings; leave the stable entry alone. Quit and reopen this exact build after approval if required. Current builds are ad-hoc signed; rebuilding does not guarantee resolution of a stale or unrecognised macOS grant. Persistent certificate signing remains outstanding.

Confirm bridge 0.5.3 in diagnostics. If an older bridge is loaded, update/reload the staged CameraReference.lrplugin manually. It permits Library/Develop photo requests and rejects other modules. No plugin update is needed if 0.5.3 is already running. Main now stages the accepted normal-identity CameraReference.app; the testing worktree stays separate.
