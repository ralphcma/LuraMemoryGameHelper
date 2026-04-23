local ADDON_NAME, LMG = ...

-----------------------------------------------------------------------
-- MODULE: Events
--
-- PURPOSE:
-- Owns WoW event registration and dispatch for the addon.
--
-- NOTES:
-- - This module intentionally does not contain pattern logic.
-- - This module intentionally does not contain UI construction logic.
-- - Event handlers call through the shared LMG.* bridge API.
-----------------------------------------------------------------------

local eventsFrame = CreateFrame("Frame")

-----------------------------------------------------------------------
-- ADDON_LOADED
--
-- WHY:
-- This is the earliest safe place to initialize persisted settings and
-- build on-demand UI state for this addon specifically.
-----------------------------------------------------------------------
local function handleAddonLoaded(addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    if LMG.InitializeDB then
        LMG.InitializeDB()
    end

    if LMG.InitializeCurrentPatternSlotCount then
        LMG.InitializeCurrentPatternSlotCount()
    end

    if LMG.BuildSettingsWindow then
        LMG.BuildSettingsWindow()
    end

    print("|cff8cd1ffLura Memory Game Helper|r loaded! Type |cffffd700/lmg|r to open.")

    if LMG.ShowChangelogIfNeeded then
        LMG.ShowChangelogIfNeeded()
    end
end

-----------------------------------------------------------------------
-- GROUP / ZONE / WORLD STATE
--
-- WHY:
-- These events all feed the same behavior:
-- - refresh settings controls if present
-- - auto-handle raid visibility / slot mode behavior
-----------------------------------------------------------------------
local function handleRosterOrZoneEvent()
    local win = LMG.GetWindow and LMG.GetWindow()

    if win and LMG.UpdateBroadcastControls then
        LMG.UpdateBroadcastControls()
    end

    if LMG.RefreshSettingsControls then
        LMG.RefreshSettingsControls()
    end

    if LMG.HandleRosterOrZoneChange then
        LMG.HandleRosterOrZoneChange()
    end
end

-----------------------------------------------------------------------
-- CHAT_MSG_SAY
--
-- WHY:
-- Incoming [LMG] sync messages are still parsed by existing Core logic.
-- Events.lua only forwards the chat event payload.
-----------------------------------------------------------------------
local function handleChatSay(msg, author)
    if LMG.HandleIncomingSay then
        LMG.HandleIncomingSay(msg, author)
    end
end

-----------------------------------------------------------------------
-- Event dispatcher
-----------------------------------------------------------------------
eventsFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        handleAddonLoaded(...)
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        handleRosterOrZoneEvent()
        return
    end

    if event == "CHAT_MSG_SAY" then
        handleChatSay(...)
    end
end)

-----------------------------------------------------------------------
-- Event registration
-----------------------------------------------------------------------
eventsFrame:RegisterEvent("ADDON_LOADED")
eventsFrame:RegisterEvent("CHAT_MSG_SAY")
eventsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventsFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
