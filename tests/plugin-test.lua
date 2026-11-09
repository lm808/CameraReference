-- Cooperative SDK stand-ins; actual Lightroom loading remains a manual test.
local root = assert(arg[1], 'Pass project root')
local token = '11111111-1111-1111-1111-111111111111'
for _, scenario in ipairs({'ok', 'dng', 'library', 'none', 'notraw', 'sdkerror', 'writeerror', 'pending', 'restart', 'windowlibrary', 'modulechange', 'cleanup'}) do
    local files, tasks, responses = {}, {}, 0
    local currentModule = (scenario == 'library' or scenario == 'windowlibrary') and 'library' or 'develop'
    local clock = 1000
    local originalTime = os.time; os.time = function() return clock end
    local message = token .. '\n' .. (scenario == 'windowlibrary' and 'window' or 'overlay')
    local originalIO = io
    _G.cameraReferenceStatus = nil
    _PLUGIN = { path = root .. '/CameraReference.lrplugin' }
    io = { open = function(path, mode)
        local name = path:match('[^/]+$')
        if mode == 'rb' then
            if not files[name] then return nil end
            return { read = function() return files[name] end, close = function() end }
        end
        if scenario == 'writeerror' and name == 'response.txt' then return nil, 'Permission denied (mock)' end
        return { write = function(self, data)
            files[name] = data
            if name == 'response.txt' then responses = responses + 1 end
            return self
        end, close = function() return true end }
    end }
    local modules = {
        LrTasks = { pcall = pcall, startAsyncTask = function(f) tasks[#tasks+1] = coroutine.create(f) end,
            sleep = function() coroutine.yield() end },
        LrPathUtils = { child = function(a,b) return a .. '/' .. b end, getStandardFilePath = function() return '/test' end },
        LrFileUtils = { createAllDirectories = function() return true end, delete = function(path) files[path:match('[^/]+$')] = nil end },
        LrDialogs = {message = function() end},
        LrApplicationView = { getCurrentModuleName = function() return currentModule end },
        LrApplication = { activeCatalog = function() return { getTargetPhoto = function()
            if scenario == 'sdkerror' then error('SDK failed') end
            if scenario == 'none' then return nil end
            return {getRawMetadata = function(_, key)
                if key == 'fileFormat' then return scenario == 'notraw' and 'JPG' or (scenario == 'dng' and 'DNG' or 'RAW') end
                assert(key == 'path'); return '/假期/IMG_1234.NEF'
            end}
        end } end }
    }
    import = function(name) return assert(modules[name], name) end
    local function step()
        local n = #tasks
        for i=1,n do
            if coroutine.status(tasks[i]) ~= 'dead' then
                local ok, err = coroutine.resume(tasks[i]); assert(ok, err)
            end
        end
    end
    local info = assert(loadfile(_PLUGIN.path .. '/Info.lua'))()
    -- Regression: the first build omitted BOTH conditions for automatic startup.
    assert(info.LrForceInitPlugin == true, 'Missing forced startup')
    assert(#info.LrExportMenuItems >= 1, 'Forced startup requires a menu contribution')
    if scenario == 'pending' then files['request.txt'] = message end
    dofile(_PLUGIN.path .. '/' .. info.LrInitPlugin)
    step()
    assert(files['heartbeat.txt'], 'No heartbeat')
    if scenario == 'restart' then
        dofile(_PLUGIN.path .. '/Start.lua'); step(); step()
    end
    files['request.txt'] = message
    step(); step()
    if scenario == 'writeerror' then
        assert(_G.cameraReferenceStatus:find('ERROR',1,true))
        assert(files['status.txt']:find('ERROR',1,true))
        assert(responses == 0)
    else
        assert(responses == 1, 'Expected exactly one response')
        assert(files['response.txt']:find(token,1,true) == 1)
        assert(files['response.txt']:sub(-5) == '\nEND\n')
        local success = scenario == 'ok' or scenario == 'dng' or scenario == 'pending' or scenario == 'restart' or scenario == 'windowlibrary' or scenario == 'modulechange' or scenario == 'cleanup'
        assert(files['response.txt']:find(success and '\nOK\n' or '\nERR\n',1,true))
    end
    if scenario == 'modulechange' then
        currentModule = 'library'; step()
        assert(files['heartbeat.txt']:find('\nlibrary\n',1,true), 'Module not reported immediately')
    end
    if scenario == 'cleanup' then clock = clock + 11; step(); assert(files['response.txt'] == nil) end
    dofile(_PLUGIN.path .. '/Diagnostics.lua')
    dofile(_PLUGIN.path .. '/Shutdown.lua'); step()
    for _, task in ipairs(tasks) do assert(coroutine.status(task) == 'dead', 'Loop did not stop') end
    io = originalIO; os.time = originalTime
end
print('PASS: startup flags/menu, heartbeat, RAW/DNG, errors, delayed startup, manual restart, single response, write-error diagnostics, shutdown')
