"""Compile actual coordinator code without its application entry point.

Only test seams below are changed in generated, ignored copies. Production guards,
load pipeline, timing and state transitions are not replaced by a model. Exact
match counts fail closed if source changes. Delete these seams as proper injectable
boundaries become available during migration.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
out = root / 'build/migration-tests'
out.mkdir(parents=True, exist_ok=True)
def once(text, old, new):
    assert text.count(old) == 1, f'Test seam moved/duplicated: {old[:100]}'
    return text.replace(old, new)
main = (root / 'Sources/main.swift').read_text()
main = once(main, 'let app = NSApplication.shared\nlet delegate = AppDelegate()\napp.delegate = delegate\napp.run()', '')
main = once(main, 'FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CameraReference/Bridge")', 'MigrationEnvironment.bridge')
main = once(main, 'let detectionSettings=DetectionConfigStore()', 'let detectionSettings=DetectionConfigStore(url:MigrationEnvironment.root.appendingPathComponent("config.conf"))')
# No status-bar object is created. Keep report scheduling and text behaviour.
diagnostics = (root / 'Sources/Diagnostics.swift').read_text()
diagnostics = once(diagnostics, 'lastResult = text; detail.title = String(text.prefix(100)); status.button?.toolTip = text', 'lastResult = text')
# Instrument arrival, without altering the completion guard or its body.
main = once(main, 'guard self.pending == token, !work.isCancelled else { return }', 'MigrationEnvironment.loadCompletions += 1\n                guard self.pending == token, !work.isCancelled else { return }')
(out / 'AppDelegate.swift').write_text(main)
core = (root / 'Sources/Core.swift').read_text()
start = core.index('    static let shared:UserDefaults =')
end = core.index('\n}', start)
core = core[:start] + '    static let shared = MigrationEnvironment.preferences' + core[end:]
(out / 'Core.swift').write_text(core)

(out / 'Diagnostics.swift').write_text(diagnostics)
