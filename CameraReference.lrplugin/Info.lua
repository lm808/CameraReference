return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'org.local.camerareference.bridge',
    LrPluginName = 'Camera Reference Bridge',
    LrInitPlugin = 'Init.lua',
    -- Adobe requires at least one menu contribution for forced initialisation.
    LrForceInitPlugin = true,
    LrExportMenuItems = {
        { title = 'Start / restart Camera Reference bridge', file = 'Start.lua' },
        { title = 'Camera Reference bridge diagnostics', file = 'Diagnostics.lua' },
    },
    LrShutdownPlugin = 'Shutdown.lua',
    VERSION = { major=0, minor=4, revision=0, build=4 },
}
