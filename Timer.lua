local ADDON_NAME, LMG = ...

local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
local timerHost = {}
local autoClearTimerHandle = nil

if AceTimer then
    AceTimer:Embed(timerHost)
end

local function cancelAutoClearTimer()
    if autoClearTimerHandle and timerHost and timerHost.CancelTimer then
        timerHost:CancelTimer(autoClearTimerHandle)
    end
    autoClearTimerHandle = nil
end

local function handleAutoClearTimer()
    autoClearTimerHandle = nil

    if not (LMG.StateHasAnyEntries and LMG.StateHasAnyEntries()) then
        return
    end

    if LMG.ClearState then
        LMG.ClearState()
    end
    if LMG.SetPatternLocked then
        LMG.SetPatternLocked(false)
    end
    if LMG.Redraw then
        LMG.Redraw()
    end
    if LMG.NotifyInfo and LMG.GetAutoClearSeconds then
        LMG.NotifyInfo("Pattern auto-cleared after " .. LMG.GetAutoClearSeconds() .. " seconds.")
    end
end

local function refreshAutoClearTimer()
    cancelAutoClearTimer()

    if not (LMG.StateHasAnyEntries and LMG.StateHasAnyEntries()) then
        return
    end

    if timerHost and timerHost.ScheduleTimer and LMG.GetAutoClearSeconds then
        autoClearTimerHandle = timerHost:ScheduleTimer(handleAutoClearTimer, LMG.GetAutoClearSeconds())
    end
end

LMG.CancelAutoClearTimer = cancelAutoClearTimer
LMG.RefreshAutoClearTimer = refreshAutoClearTimer
