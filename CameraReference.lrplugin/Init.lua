local Tasks = import 'LrTasks'
local Paths = import 'LrPathUtils'
local Files = import 'LrFileUtils'
local Application = import 'LrApplication'
local View = import 'LrApplicationView'
local UUID = import 'LrUUID'
local FunctionContext = import 'LrFunctionContext'
local folder = Paths.child(Paths.getStandardFilePath('home'),
    'Library/Application Support/CameraReference/Bridge')
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
_G.cameraReferenceStatus = 'Starting bridge 0.5.3'
Tasks.startAsyncTask(function()
    local ok, err = Tasks.pcall(function()
      FunctionContext.callWithContext("CameraReferenceSelection", function(context)
        local created, why = Files.createAllDirectories(folder)
        if not created then error('Cannot create bridge folder: ' .. tostring(why)) end
        _G.cameraReferenceStatus = 'Running 0.5.3'
        write('status.txt', _G.cameraReferenceStatus)
        local request = Paths.child(folder, 'request.txt')
        Files.delete(Paths.child(folder, 'response.txt')) -- Remove any reply left by an earlier crashed session.
        local last = nil -- Service an outstanding request if startup was delayed.
        local heartbeatTime = nil
        local lastModule = nil
        local responseTime = nil
        local session = UUID.generateUUID()
        local revision, selectedKey, selectionEpoch = 0, nil, nil
        local selectionTime = nil
        -- Installed Lightroom 15.6 exposes (functionContext, observer, callback).
        -- This API is not documented: guard it and disable caching if unavailable.
        local observerReady = false
        if type(Application.addActivePhotoChangeObserver) == 'function' then
            observerReady = Tasks.pcall(function()
                Application.addActivePhotoChangeObserver(context, generation, function()
                    if _G.cameraReferenceGeneration == generation then
                        revision = revision + 1; selectionTime = nil
                    end
                end)
            end)
        end
        local function sampleSelection()
            local ok, key = Tasks.pcall(function()
                local catalog = Application.activeCatalog()
                local photo = catalog:getTargetPhoto()
                if not photo then return 'none' end
                local catalogKey = catalog.getPath and catalog:getPath() or ''
                return tostring(catalogKey) .. ':' .. tostring(photo.localIdentifier or photo:getRawMetadata('path'))
            end)
            if not ok then key = nil end
            if not ok or key ~= selectedKey then
                revision = revision + 1; selectedKey = key
            end
            selectionEpoch = (ok and observerReady) and (session .. ':' .. tostring(revision)) or nil
            if selectionEpoch and (selectionTime ~= os.time() or selectionEpoch ~= _G.cameraReferenceSelectionEpoch) then
                write('selection.txt', selectionEpoch .. '\nEND\n')
                selectionTime = os.time()
            elseif not selectionEpoch then Files.delete(Paths.child(folder, 'selection.txt')) end
            _G.cameraReferenceSelectionEpoch = selectionEpoch
            return selectionEpoch
        end
        while _G.cameraReferenceRunning and _G.cameraReferenceGeneration == generation do
            local now = os.time()
            sampleSelection()
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
                local responseEpoch = sampleSelection()
                local success, payload = Tasks.pcall(function()
                    local module = View.getCurrentModuleName()
                    if module ~= 'develop' and module ~= 'library' then
                        return 'ERR\n' .. hex('Switch Lightroom to Library or Develop.')
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
                local currentEpoch = sampleSelection()
                if responseEpoch and responseEpoch ~= currentEpoch then
                    payload = 'ERR\n' .. hex('Selection changed while reading the photograph. Invoke again.')
                end
                if responseEpoch and responseEpoch == currentEpoch then
                    write('response-selection.txt', token .. '\n' .. responseEpoch .. '\nEND\n')
                else Files.delete(Paths.child(folder, 'response-selection.txt')) end
                write('response.txt', token .. '\n' .. payload .. '\nEND\n')
                responseTime = now
            end
            Tasks.sleep(0.15)
        end
      end)
    end)
    if not ok and _G.cameraReferenceGeneration == generation then
        _G.cameraReferenceRunning = false
        _G.cameraReferenceStatus = 'ERROR: bridge stopped; check folder permissions and restart the bridge.'
        Tasks.pcall(function() write('status.txt', _G.cameraReferenceStatus) end)
    end
end)
