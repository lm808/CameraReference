-- Read-only capability report. Never changes Lightroom's view or photographs.
local Tasks = import 'LrTasks'
local Dialogs = import 'LrDialogs'
Tasks.startAsyncTask(function()
    local View = import 'LrApplicationView'
    local names = {}
    for name, value in pairs(View) do
        if type(value) == 'function' then names[#names + 1] = name end
    end
    table.sort(names)
    local lines = { 'LrApplicationView exported functions:', table.concat(names, ', ') }
    local ok, module = Tasks.pcall(function() return View.getCurrentModuleName() end)
    lines[#lines + 1] = 'Current module: ' .. (ok and tostring(module) or 'unavailable')
    lines[#lines + 1] = 'Main-view getter candidates (presence only, not invoked):'
    for _, name in ipairs({ 'getMainViewName', 'getCurrentViewName', 'getCurrentView' }) do
        lines[#lines + 1] = name .. ': ' .. type(View[name])
    end
    lines[#lines + 1] = 'showView changes views; getSecondaryViewName describes the secondary display. Neither identifies the main Develop layout.'
    Dialogs.message('Camera Reference — View API diagnostics', table.concat(lines, '\n'), 'info')
end)
