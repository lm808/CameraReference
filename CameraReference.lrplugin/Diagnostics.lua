import 'LrDialogs'.message('Camera Reference bridge 0.5.2',
    tostring(_G.cameraReferenceStatus or 'Not started') .. '\nFolder: ' ..
    tostring(_G.cameraReferenceFolder or 'not established') ..
    '\nPlugin: ' .. tostring(_PLUGIN.path), 'info')
