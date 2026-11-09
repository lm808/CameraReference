import 'LrDialogs'.message('Camera Reference bridge 0.4.0',
    tostring(_G.cameraReferenceStatus or 'Not started') .. '\nFolder: ' ..
    tostring(_G.cameraReferenceFolder or 'not established') ..
    '\nPlugin: ' .. tostring(_PLUGIN.path), 'info')
