local ADDON_NAME, LMG = ...

local AceConsole = LibStub and LibStub("AceConsole-3.0", true)
local commandHost = {}

if AceConsole then
    AceConsole:Embed(commandHost)
end

local commands = {
    clear = function()
        if LMG.PlayerCanBroadcast and not LMG.PlayerCanBroadcast() then return end
        if LMG.SaveUndoState then LMG.SaveUndoState() end
        if LMG.DoClear then LMG.DoClear(true) end
    end,
    say = function()
        if LMG.PlayerCanBroadcast and not LMG.PlayerCanBroadcast() then return end
        if LMG.SendPattern then LMG.SendPattern() end
    end,
    show = function()
        if LMG.ShowWindow then LMG.ShowWindow(true) end
    end,
    hide = function()
        if LMG.HideWindow then LMG.HideWindow() end
    end,
    test = function()
        local current = LMG.GetTestMode and LMG.GetTestMode() or false
        if LMG.SetTestMode then LMG.SetTestMode(not current) end
        if LMG.NotifyInfo then LMG.NotifyInfo("Test Mode: " .. ((not current) and "ENABLED" or "DISABLED")) end
        if LMG.UpdateBroadcastControls then LMG.UpdateBroadcastControls() end
    end,
    undo = function()
        local ok = LMG.RestoreUndoState and LMG.RestoreUndoState()
        if LMG.NotifyInfo then LMG.NotifyInfo(ok and "Undo applied." or "Nothing to undo.") end
    end,
    redo = function()
        local ok = LMG.RestoreRedoState and LMG.RestoreRedoState()
        if LMG.NotifyInfo then LMG.NotifyInfo(ok and "Redo applied." or "Nothing to redo.") end
    end,
    lock = function()
        if LMG.SetPatternLocked then LMG.SetPatternLocked(true) end
        if LMG.NotifyInfo then LMG.NotifyInfo("Pattern locked.") end
        if LMG.Redraw then LMG.Redraw() end
    end,
    unlock = function()
        if LMG.SetPatternLocked then LMG.SetPatternLocked(false) end
        if LMG.NotifyInfo then LMG.NotifyInfo("Pattern unlocked.") end
        if LMG.Redraw then LMG.Redraw() end
    end,
    locksend = function()
        local state = LMG.GetLockAfterSend and LMG.GetLockAfterSend() or false
        if LMG.NotifyInfo then
            LMG.NotifyInfo("Lock-after-send is currently " .. (state and "ON" or "OFF") .. ". Use /lmg locksend on|off or /lmg sendlock on|off.")
        end
    end,
    sendlock = function()
        local state = LMG.GetLockAfterSend and LMG.GetLockAfterSend() or false
        if LMG.NotifyInfo then
            LMG.NotifyInfo("Lock-after-send is currently " .. (state and "ON" or "OFF") .. ". Use /lmg locksend on|off or /lmg sendlock on|off.")
        end
    end,
    changelog = function()
        if LMG.BuildChangelogFrame then LMG.BuildChangelogFrame() end
        local frame = LMG.GetChangelogFrame and LMG.GetChangelogFrame()
        if frame and frame.dismissCheck and frame.dismissCheck.checkedTex then
            frame.dismissCheck.checkedTex:SetShown(false)
        end
        if frame then frame:Show() end
    end,
    settings = function()
        if LMG.BuildSettingsWindow then LMG.BuildSettingsWindow() end
        if LMG.ToggleSettingsWindow then LMG.ToggleSettingsWindow() end
    end,
    minimap = function()
        if LMG.ToggleMinimap then LMG.ToggleMinimap() end
    end,
    selfsync = function()
        local enabled = LMG.GetAllowSelfTestSync and LMG.GetAllowSelfTestSync() or false
        if LMG.NotifyInfo then
            LMG.NotifyInfo("Self-sync test mode is currently " .. (enabled and "ON" or "OFF") .. ". Use /lmg selfsync on|off.")
        end
    end,
    restorefull = function()
        local ok = LMG.RestoreLastFullPattern and LMG.RestoreLastFullPattern()
        if LMG.NotifyInfo then LMG.NotifyInfo(ok and "Restored last full pattern." or "No saved full pattern to restore.") end
    end,
}

local function normalize(s)
    s = tostring(s or "")
    s = s:lower()
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("%s+", " ")
    return s
end

local function handleSlashCommand(msg)
    local normalized = normalize(msg)
    local cmd, arg = normalized:match("^(%S+)%s*(.-)$")
    cmd = cmd or ""
    arg = arg or ""

    if LMG.EnsureWindowBuilt then LMG.EnsureWindowBuilt() end
    if LMG.UpdateBroadcastControls then LMG.UpdateBroadcastControls() end

    if normalized == "" then
        if LMG.ToggleWindow then LMG.ToggleWindow() end
        return
    end

    local fn = commands[normalized] or commands[cmd]

    if (cmd == "locksend" or cmd == "sendlock") and arg ~= "" then
        if arg == "on" then
            if LMG.SetLockAfterSend then LMG.SetLockAfterSend(true) end
            if LMG.SaveSettingsState then LMG.SaveSettingsState() end
            if LMG.NotifyInfo then LMG.NotifyInfo("Lock-after-send enabled.") end
            return
        elseif arg == "off" then
            if LMG.SetLockAfterSend then LMG.SetLockAfterSend(false) end
            if LMG.SetPatternLocked then LMG.SetPatternLocked(false) end
            if LMG.SaveSettingsState then LMG.SaveSettingsState() end
            if LMG.NotifyInfo then LMG.NotifyInfo("Lock-after-send disabled.") end
            if LMG.Redraw then LMG.Redraw() end
            return
        end
    elseif cmd == "autofill" and arg ~= "" then
        if arg == "on" then
            if LMG.SetAutoFill then LMG.SetAutoFill(true) end
            if LMG.SaveSettingsState then LMG.SaveSettingsState() end
            if LMG.NotifyInfo then LMG.NotifyInfo("Autofill enabled.") end
            return
        elseif arg == "off" then
            if LMG.SetAutoFill then LMG.SetAutoFill(false) end
            if LMG.SaveSettingsState then LMG.SaveSettingsState() end
            if LMG.NotifyInfo then LMG.NotifyInfo("Autofill disabled.") end
            return
        end
    elseif cmd == "duplicates" and arg ~= "" then
        if arg == "on" then
            if LMG.SetPreventDuplicates then LMG.SetPreventDuplicates(true) end
            if LMG.SaveSettingsState then LMG.SaveSettingsState() end
            if LMG.NotifyInfo then LMG.NotifyInfo("Duplicate prevention enabled.") end
            return
        elseif arg == "off" then
            if LMG.SetPreventDuplicates then LMG.SetPreventDuplicates(false) end
            if LMG.SaveSettingsState then LMG.SaveSettingsState() end
            if LMG.NotifyInfo then LMG.NotifyInfo("Duplicate prevention disabled.") end
            return
        end
    elseif cmd == "selfsync" and arg ~= "" then
        if arg == "on" then
            if LMG.SetAllowSelfTestSync then LMG.SetAllowSelfTestSync(true) end
            if LMG.NotifyInfo then LMG.NotifyInfo("Self-sync test mode enabled. Your own [LMG] /say messages will be parsed locally.") end
            return
        elseif arg == "off" then
            if LMG.SetAllowSelfTestSync then LMG.SetAllowSelfTestSync(false) end
            if LMG.NotifyInfo then LMG.NotifyInfo("Self-sync test mode disabled.") end
            return
        end
    end

    if fn then
        fn()
    else
        if LMG.ToggleWindow then LMG.ToggleWindow() end
    end
end

LMG.HandleSlashCommand = handleSlashCommand

local function registerSlashCommands()
    if not LMG or not LMG.HandleSlashCommand then
        return
    end

    if commandHost and commandHost.RegisterChatCommand then
        commandHost:RegisterChatCommand("lmg", LMG.HandleSlashCommand)
        commandHost:RegisterChatCommand("memorygame", LMG.HandleSlashCommand)
        commandHost:RegisterChatCommand("luramemory", LMG.HandleSlashCommand)
    end

    SLASH_LURAMEMORYGAMEHELPER1 = "/lmg"
    SLASH_LURAMEMORYGAMEHELPER2 = "/memorygame"
    SLASH_LURAMEMORYGAMEHELPER3 = "/luramemory"
    SlashCmdList["LURAMEMORYGAMEHELPER"] = LMG.HandleSlashCommand
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    registerSlashCommands()
    self:UnregisterEvent("ADDON_LOADED")
end)
