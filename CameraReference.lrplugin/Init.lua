local Tasks = import 'LrTasks'
local Paths = import 'LrPathUtils'
local Files = import 'LrFileUtils'
local Application = import 'LrApplication'
local View = import 'LrApplicationView'
local folder = Paths.child(Paths.getStandardFilePath('home'),
    'Library/Application Support/CameraReference')
local function read(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local text = f:read('*a'); f:close(); return text
end
local function write(name, text)
    local f, err = io.open(Paths.child(folder, name), 'wb')
    if not f then error('Cannot write ' .. name .. ': ' .. tostring(err)) end
    local ok, why = f:write(text)
    f:close()
    if not ok then error('Cannot write ' .. name .. ': ' .. tostring(why)) end
end
local function hex(s)
    return (s:gsub('.', function(c) return string.format('%02x', string.byte(c)) end))
end
local generation = {}
_G.cameraReferenceGeneration = generation
_G.cameraReferenceRunning = true
_G.cameraReferenceFolder = folder
_G.cameraReferenceStatus = 'Starting bridge 0.4.0'
Tasks.startAsyncTask(function()
    local ok, err = Tasks.pcall(function()
        local created, why = Files.createAllDirectories(folder)
        if not created then error('Cannot create bridge folder: ' .. tostring(why)) end
        _G.cameraReferenceStatus = 'Running 0.4.0'
        write('status.txt', _G.cameraReferenceStatus)
        local request = Paths.child(folder, 'request.txt')
        Files.delete(Paths.child(folder, 'response.txt')) -- Remove any reply left by an earlier crashed session.
        local last = nil -- Service an outstanding request if startup was delayed.
        local heartbeatTime = nil
        local lastModule = nil
        local responseTime = nil
        while _G.cameraReferenceRunning and _G.cameraReferenceGeneration == generation do
            local now = os.time()
            local currentModule = View.getCurrentModuleName()
            if now ~= heartbeatTime or currentModule ~= lastModule then
                write('heartbeat.txt', tostring(now) .. '\n' .. tostring(currentModule) .. '\nEND\n')
                heartbeatTime = now; lastModule = currentModule
            end
            -- Short-lived path IPC only; no photo paths in status/logs. Clean abandoned replies.
            if responseTime and now - responseTime > 10 then
                Files.delete(Paths.child(folder, 'response.txt')); responseTime = nil
            end
            local message = read(request)
            local token, mode
            if message then token, mode = message:match('^([%x%-]+)\n([a-z]+)$') end
            if token and token ~= last and #token == 36 and (mode == 'overlay' or mode == 'window' or mode == 'check') then
                last = token
                local success, payload = Tasks.pcall(function()
                    if mode ~= 'window' and View.getCurrentModuleName() ~= 'develop' then
                        return 'ERR\n' .. hex('Select a photograph in Develop.')
                    end
                    local photo = Application.activeCatalog():getTargetPhoto()
                    if not photo then return 'ERR\n' .. hex('No active photograph.') end
                    local format = photo:getRawMetadata('fileFormat')
                    if format ~= 'RAW' and format ~= 'DNG' then
                        return 'ERR\n' .. hex('Select a RAW photograph. JPEG, TIFF and video selections are not supported.')
                    end
                    local path = photo:getRawMetadata('path')
                    if not path then return 'ERR\n' .. hex('The active photograph has no original path.') end
                    return 'OK\n' .. hex(path)
                end)
                if not success then payload = 'ERR\n' .. hex('Lightroom could not read the selected photograph.') end
                write('response.txt', token .. '\n' .. payload .. '\nEND\n')
                responseTime = now
            end
            Tasks.sleep(0.15)
        end
    end)
    if not ok and _G.cameraReferenceGeneration == generation then
        _G.cameraReferenceRunning = false
        _G.cameraReferenceStatus = 'ERROR: bridge stopped; check folder permissions and restart the bridge.'
        Tasks.pcall(function() write('status.txt', _G.cameraReferenceStatus) end)
    end
end)
