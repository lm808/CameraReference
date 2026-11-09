-- A menu action gives deferred plugins an explicit first use; no Lightroom restart required.
local Tasks = import 'LrTasks'
local Paths = import 'LrPathUtils'
Tasks.startAsyncTask(function()
    local ok, err = Tasks.pcall(function() dofile(Paths.child(_PLUGIN.path, 'Init.lua')) end)
    if not ok then
        _G.cameraReferenceStatus = 'ERROR: ' .. tostring(err)
        import 'LrDialogs'.message('Camera Reference could not start', tostring(err), 'critical')
    end
end)
