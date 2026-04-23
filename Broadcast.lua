local ADDON_NAME, LMG = ...

-----------------------------------------------------------------------
-- MODULE: Broadcast
--
-- PURPOSE:
-- Owns outgoing message formatting, incoming payload parsing, and
-- broadcast permission checks.
--
-- DOES NOT:
-- - mutate pattern state tables directly beyond calling the shared
--   bridge helpers exposed from Core.lua
-- - construct UI
-- - manage timer internals directly
--
-- NOTES:
-- - Incoming [LMG] PATTERN messages now start / reset the local timer.
-- - [LMG] CLEAR is intentionally left disabled as a commented backup.
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Outgoing pattern formatting
-----------------------------------------------------------------------
local function patternToText(pattern)
    local parts = {}
    for _, i in ipairs(LMG.GetActiveSlotIndices and LMG.GetActiveSlotIndices() or {}) do
        local entry = pattern[i]
        if entry then
            parts[#parts + 1] = entry.label
        end
    end
    return (#parts > 0) and table.concat(parts, " > ") or "(empty)"
end

local function currentPatternText()
    local state = LMG.GetState and LMG.GetState() or {}
    return patternToText(state)
end

-----------------------------------------------------------------------
-- Incoming text decoding
-----------------------------------------------------------------------
local function textToPattern(text)
    local decoded = {}
    local syms = LMG.GetSymbols and LMG.GetSymbols() or {}

    for rawPart in tostring(text):gmatch("([^>]+)") do
        local needle = (rawPart and rawPart:match("^%s*(.-)%s*$") or ""):lower()
        for _, sym in ipairs(syms) do
            if sym.label:lower() == needle then
                decoded[#decoded + 1] = sym
                break
            end
        end
        if #decoded >= (LMG.GetMaxSymbols and LMG.GetMaxSymbols() or 5) then
            break
        end
    end

    return decoded
end

-----------------------------------------------------------------------
-- Raid warning output formatting
-----------------------------------------------------------------------
local function rwLabelForSymbol(label)
    local map = {
        Diamond = "DIAMOND",
        Triangle = "TRIANGLE",
        Circle = "CIRCLE",
        Cross = "CROSS",
        T = "tTt",
    }
    return map[label] or label:upper()
end

local function buildRWText()
    local parts = {}
    local state = LMG.GetState and LMG.GetState() or {}

    for _, i in ipairs(LMG.GetActiveSlotIndices and LMG.GetActiveSlotIndices() or {}) do
        local entry = state[i]
        if entry then
            parts[#parts + 1] = rwLabelForSymbol(entry.label)
        end
    end

    if #parts == 0 then
        return nil
    end

    return ">>> " .. table.concat(parts, " <> ") .. " <<<"
end

local function maybeSendRW()
    if not (LMG.GetAlsoSendRW and LMG.GetAlsoSendRW()) or not (LMG.StateHasAnyEntries and LMG.StateHasAnyEntries()) then
        return
    end

    local rwText = buildRWText()
    if rwText then
        SendChatMessage(rwText, "RAID_WARNING")
    end
end

-----------------------------------------------------------------------
-- Broadcast permission checks
--
-- WHY:
-- Preserves the existing rule that test mode bypasses raid role checks.
-----------------------------------------------------------------------
local function playerCanBroadcast()
    if LMG.GetTestMode and LMG.GetTestMode() then
        return true
    end

    if not IsInRaid() then
        return false
    end

    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-----------------------------------------------------------------------
-- Outgoing send
-----------------------------------------------------------------------
local function sendPattern()
    if not (LMG.StateHasAnyEntries and LMG.StateHasAnyEntries()) then
        return
    end

    -- Lock immediately so local send cannot race with sync updates.
    if LMG.GetLockAfterSend and LMG.GetLockAfterSend() then
        if LMG.SetPatternLocked then LMG.SetPatternLocked(true) end
    else
        if LMG.SetPatternLocked then LMG.SetPatternLocked(false) end
    end

    if LMG.SaveLastFullPatternIfComplete then
        LMG.SaveLastFullPatternIfComplete()
    end

    SendChatMessage((LMG.GetSayPrefix and LMG.GetSayPrefix() or "[LMG]") .. " PATTERN: " .. currentPatternText(), "SAY")
    maybeSendRW()

    if LMG.GetLockAfterSend and LMG.GetLockAfterSend() and LMG.NotifyInfo then
        LMG.NotifyInfo("Pattern locked after send. Use /lmg unlock or clear the pattern.")
    end

    if LMG.RefreshAutoClearTimer then
        LMG.RefreshAutoClearTimer()
    end
    if LMG.Redraw then
        LMG.Redraw()
    end
end

-----------------------------------------------------------------------
-- Incoming payload parsing
-----------------------------------------------------------------------
local function parsePayload(msg)
    local payload = msg and msg:match("^%[LMG%]%s*(.+)$")
    if not payload then
        return nil
    end

    payload = (payload and payload:match("^%s*(.-)%s*$")) or ""

    -------------------------------------------------------------------
    -- BACKUP ONLY: [LMG] CLEAR parsing path
    --
    -- This is intentionally disabled. Pattern lifecycle now begins on
    -- [LMG] PATTERN receipt and ends on the local auto-clear timer.
    --
    -- if payload == "CLEAR" then
    --     return "clear"
    -- end
    -------------------------------------------------------------------

    local patternText = payload:match("^PATTERN:%s*(.+)$")
    if patternText then
        return "pattern", patternText
    end

    return nil
end

local function handleIncomingSay(msg, author)
    local kind, value = parsePayload(msg)
    if kind == "clear" then
        -- Disabled backup path; left for reference.
        return
    end

    if kind == "pattern" then
        local decoded = textToPattern(value)
        if #decoded > 0 then
            local lockedBeforeSync = LMG.GetPatternLocked and LMG.GetPatternLocked() or false

            if LMG.SetStateFromDecoded then
                LMG.SetStateFromDecoded(decoded)
            end
            if LMG.AutoFillRemainingSlotIfNeeded then
                LMG.AutoFillRemainingSlotIfNeeded()
            end
            if LMG.SaveLastFullPatternIfComplete then
                LMG.SaveLastFullPatternIfComplete()
            end
            if LMG.SetPatternLocked then
                LMG.SetPatternLocked(lockedBeforeSync)
            end

            local win = LMG.GetWindow and LMG.GetWindow()
            if win and not win:IsShown() then
                win:Show()
            end

            -- Received patterns own their own local timer lifecycle.
            if LMG.RefreshAutoClearTimer then
                LMG.RefreshAutoClearTimer()
            end

            if LMG.Redraw then
                LMG.Redraw()
            end
        end
    end
end

-----------------------------------------------------------------------
-- Shared bridge exports
-----------------------------------------------------------------------
LMG.PlayerCanBroadcast = playerCanBroadcast
LMG.SendPattern = sendPattern
LMG.HandleIncomingSay = handleIncomingSay
