# Building from source and keeping a working version

Use a separate checkout for a known-good version and for development. Run the app from each checkout's **release/CameraReference.app**. Updating one checkout then cannot replace the other's executable. Only run one companion app and one Lightroom bridge at a time.

## Requirements

On the Mac where you will run the app:

1. Install Apple's command-line developer tools if needed:

   ```sh
   xcode-select --install
   ```

2. Check the selected tools:

   ```sh
   xcode-select -p
   xcrun swiftc --version
   git --version
   ```

3. Install ExifTool if you use embedded CR3 JPEGs. This is a runtime requirement, not a compiler dependency. Choose its executable in the app's settings if automatic lookup fails.
4. The optional full test suite also needs `texlua` on PATH (provided by a TeX distribution). Building the app does not require it.

Builds target the current Mac's architecture. The app requires macOS 13 or later; capture features require macOS 14 or later. No Xcode project, signing certificate or DMG is required; build.sh creates an ad-hoc signed app.

## Build and run

For a fresh checkout:

```sh
git clone https://github.com/lm808/CameraReference.git
cd CameraReference
```

For your existing checkout, simply open Terminal in that folder. Quit its running app before updating its executable. Then:

```sh
bash test.sh
bash scripts/stage.sh
codesign --verify --deep --strict release/CameraReference.app
open release/CameraReference.app
```

The test command is optional for a local build if texlua is unavailable; do not describe an unrun suite as passing. Stage builds the app and refreshes changed files in release/. It does not install anything or create a DMG. The app menu should show the checked-out source's version. Follow that checkout's TESTING.md.

To build a different branch, first inspect `git status`. Commit intentional changes or stash them before switching; do not discard them with reset/clean. Then use `git switch BRANCH_NAME` and rebuild. A separate worktree, described below, is preferable because a single checkout's ignored release/ contents do not roll back when you switch branches.

### Older commits without scripts/stage.sh

Read the checked-out commit's README and build script. For historical CameraReference commits which have build.sh and CameraReference.lrplugin, stage manually:

```sh
bash build.sh
mkdir -p release
ditto build/CameraReference.app release/CameraReference.app
ditto CameraReference.lrplugin release/CameraReference.lrplugin
open release/CameraReference.app
```

Use a fresh worktree for an old version so stale files cannot be mixed into its app bundle. Older commits may not ignore release/; never add generated app/plugin copies to Git. Old source may require adjustments for a newer compiler; a tag preserves source, not the historical toolchain. Keeping the already-tested app alongside its matching plugin is the quickest fallback.

## Install manually, without a DMG or installer

Running from release/ is sufficient for your normal testing. To install a fixed copy instead:

1. Quit CameraReference. In Finder, copy release/CameraReference.app into Applications (or your user Applications folder). Preserve your previous known-good app outside that destination first. Replace the whole app bundle rather than copying individual files into it.
2. Disable the old bridge in Lightroom Plug-in Manager; quit Lightroom before replacing or moving its plugin folder.
3. Copy the **matching** release/CameraReference.lrplugin into a permanent folder. The current convention is:

   ```text
   ~/Library/Application Support/CameraReference/Plugins/CameraReference.lrplugin
   ```

   Move any previous plugin somewhere safe first; do not merge different versions of its files. You can also keep version-specific plugin folders alongside separate stable/candidate checkouts, but enable only one entry.
4. Reopen Lightroom. File → Plug-in Manager → Add the copied plugin; disable any older entry and enable this one. Run File → Plug-in Extras → Start / restart Camera Reference bridge.
5. Open the selected companion app. Check its menu version and Developer tools → Bridge diagnostics for the expected bridge version and a current heartbeat.
6. Allow Screen Recording when requested for capture. If permissions need refreshing after a rebuilt/ad-hoc signed app, use macOS Privacy settings; do not reset all privacy permissions.

Always pair the app with the plugin from the same commit unless that version's documentation explicitly confirms compatibility. Git checkout alone does not replace Lightroom's installed plugin or stop a running old app.

## Recommended Git workflow

A tag records the exact source you accepted; a branch is where development moves forward. A worktree gives each version a separate folder and separate build/release outputs while sharing Git history. See the [official Git worktree documentation](https://git-scm.com/docs/git-worktree).

These are examples to run deliberately, not commands the assistant has executed. Replace `GOOD_COMMIT` with the hash you actually tested, and choose unused tag/branch/folder names. Do not label the newest commit known-good merely because it compiled.

### 1. Preserve the version you trust

From the main repository:

```sh
git status --short
git log --oneline -12
git tag -a working-1.0.1 GOOD_COMMIT -m "Accepted for daily use"
git worktree add --detach ../CameraReference-stable working-1.0.1
```

Use a tag name matching the version you accepted; `working-1.0.1` is only an example. Build/stage inside CameraReference-stable using the instructions above. Run its release/CameraReference.app for daily work. Keep this folder at that tag; do not pull or stage newer source into it. A detached checkout is suitable for building a fixed version; create a branch first if you later want to edit it.

Tags stay local unless you explicitly push them. To back up a chosen accepted tag to GitHub:

```sh
git push origin working-1.0.1
```

### 2. Develop and test separately

From the main repository, create a candidate branch/worktree:

```sh
git worktree add -b codex/next ../CameraReference-next main
```

Alternatively, keep using the existing main checkout for development and only create the stable worktree. In either case, leave the stable output alone. Run tests and stage the candidate in its own folder. Quit the stable app and disable its bridge before trying the candidate app/bridge.

### 3. Accept a candidate only after testing

When the candidate passes the relevant manual tests, record its exact commit with a new accepted tag (for example working-1.0.2). Keep the previous tag. You can make another fixed worktree at that tag and use its release/ app, leaving the older fallback intact until you are comfortable removing it.

If development was on codex/next and main has not diverged, return to the main checkout with a clean working tree and run:

```sh
git switch main
git merge --ff-only codex/next
```

If this refuses because main diverged, review the branches before merging; do not force-reset main. Merge acceptance does not itself require packaging. Patch updates remain source/staged updates; request a minor-version packaged release when the feature set is ready.

### 4. Roll back a failed candidate

Quit the candidate app. Disable its bridge, enable/reload the matching stable bridge, then open CameraReference-stable/release/CameraReference.app. No Git reset or source deletion is needed. If you installed into Applications, replace that app with the saved whole stable bundle first.

## Shared settings: separate checkouts are not isolated profiles

All versions use the same macOS preference domain, and recent versions use the same Application Support folder. Before testing a migration, quit the companion and Lightroom, then save these **outside the repository**:

- The tested app and matching plugin, with their commit hash.
- Your config.conf (and detection.conf for old versions), keeping a note of the original path.
- A preferences export, using a destination you choose:

  ```sh
  defaults export org.local.CameraReference ~/Desktop/CameraReference-preferences-before-test.plist
  ```

The export contains GUI settings and calibration; keep it private. To restore it deliberately, quit both apps first, then:

```sh
defaults import org.local.CameraReference ~/Desktop/CameraReference-preferences-before-test.plist
```

Restore config separately to the location expected by the old app. Do not copy request/response/heartbeat files back: they are transient protocol data, not settings. Older versions used different support paths; consult their own documentation. Switching source or app versions does not undo a settings migration. This is particularly relevant when going back across the alpha folder-name changes.

A separate macOS user account provides stronger settings/permission isolation if you want to test migrations without sharing your daily configuration.

## Removing old worktrees

Use `git worktree list` to see them. Once you no longer need a worktree, quit its app and remove/disable any Lightroom plugin pointing into it. Preserve anything you still need, then use `git worktree remove PATH`. Git may refuse because generated files remain; inspect them rather than using force blindly. Removing a worktree does not remove its tag or the main repository.

Apple reference: [installing command-line tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/).

For candidate worktrees, use `bash scripts/stage.sh --testing`. This selects the purple testing icon and separate bundle identity while preserving the shared settings domain. Use plain `bash scripts/stage.sh` for a requested stable build. Do not rebuild the accepted main app until candidate acceptance. Only one copy should run because the Lightroom bridge is shared.

Testing staging now uses `release/CameraReference Testing.app` with executable CameraReferenceTesting and a large T badge. Stable staging keeps its original path. Build intermediates are not launch targets.
