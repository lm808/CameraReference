_G.cameraReferenceRunning = false
_G.cameraReferenceStatus = 'Stopped'

local Files = import 'LrFileUtils'
local Paths = import 'LrPathUtils'
if _G.cameraReferenceFolder then
    Files.delete(Paths.child(_G.cameraReferenceFolder, 'selection.txt'))
    Files.delete(Paths.child(_G.cameraReferenceFolder, 'response-selection.txt'))
end
_G.cameraReferenceSelectionEpoch = nil
