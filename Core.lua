-- ============================================================
-- Lura Memory Game Helper
-- Version: 1.5.31
--
-- Created By: Tinaria
--
-- Inspired by:
-- Lura Tily Helper by tilynye.
-- I was trying to make that one work and somehow ended up with this monstrosity.
--
-- What this is:
-- A visual L'ura memory game helper for those of us who cannot remember
-- what happened 30 seconds ago.
--
-- Commands:
--   /lmg
--   /memorygame
--   /luramemory
--
-- Extra commands:
--   /lmg test      - allows testing outside the raid
--   /lmg show      - shows the addon window
--   /lmg hide      - hides the addon window
--
-- Notes:
--   - Broadcast functions only work if you are raid leader or raid assist,
--     unless test mode is enabled.
--   - Arc slots are clickable.
--   - Clicking a placed icon clears only that slot.
--   - Clicking a new icon fills the first empty slot.
--   - Duplicate prevention can be enabled.
--   - Slot 5 can auto-fill with the only remaining symbol.
--   - Drag a filled arc slot onto another slot to swap.
--   - Drag a filled arc slot onto an empty slot to move it.
--   - /lmg undo restores the previous pattern edit.
--   - /lmg redo reapplies the most recently undone edit.
--   - Window position, size, collapse state, and toggles persist via SavedVariables.
--   - Changelog popup can be dismissed until the next update.
--   - Optional lock-after-send prevents accidental edits until cleared or unlocked.
-- ============================================================

local ADDON_NAME, LMG = ...
LMG = LMG or {}
ADDON_NAME = ADDON_NAME or "LuraMemoryGameHelper"
local ADDON_VERSION = "1.5.31"
local SAY_PREFIX = "[LMG]"
local TEX = "Interface\\AddOns\\LuraMemoryGameHelper\\Textures\\"
local MAX = 5

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local AceDB = LibStub and LibStub("AceDB-3.0", true)
local AceConsole = LibStub and LibStub("AceConsole-3.0", true)
local AceTimer = LibStub and LibStub("AceTimer-3.0", true)

local TARGET_RAID_NAME = "March on Quel'Danas"
local autoInitialized = false

-- ============================================================
-- UI sizing / layout configuration
-- ============================================================
local UI = {
    width = 395,
    height = 535,
    minWidth = 320,
    minHeight = 500,
    maxWidth = 400,
    maxHeight = 550,
    collapsedHeight = 70,

    windowAnchor = "CENTER",
    windowRelativeTo = UIParent,
    windowRelativePoint = "CENTER",
    windowOffsetX = 200,
    windowOffsetY = 80,

    titleOffsetY = -20,
    titleWidth = 300,
    titleHeight = 30,

    bossLabelY = -130,
    bossWidth = 250,
    bossHeight = 40,
    luraArtY = -235,
    luraArtWidth = 190,
    luraArtHeight = 190,
    luraArtAlpha = 0.85,

    frameInset = 4,
    frameEdge = 12,
    cornerSize = 20,

    outerPad = 22,
    topSeparatorTopOffset = -42,

    arcIconSize = 50,
    separatorSize = 30,

    actionButtonY = 150,
    actionButtonWidth = 124,
    actionButtonHeight = 40,
    actionButtonGap = 24,

    checkboxY = 100,
    checkboxSize = 30,
    checkboxLabelWidth = 170,
    checkboxLabelHeight = 22,
    checkboxLabelOffsetX = 8,

    difficultyDropdownY = -70,
    difficultyDropdownWidth = 145,

    symbolButtonSize = 60,
    symbolButtonGap = 8,
    symbolButtonY = 28,

    thinSeparatorHeight = 16,
}

local BASE_UI = {
    width = 395,
    height = 535,

    titleWidth = 300,
    titleHeight = 30,

    bossWidth = 250,
    bossHeight = 40,
    luraArtWidth = 190,
    luraArtHeight = 190,

    frameInset = 4,
    frameEdge = 12,
    cornerSize = 20,
    outerPad = 22,

    arcIconSize = 50,
    separatorSize = 30,

    actionButtonWidth = 124,
    actionButtonHeight = 40,
    actionButtonGap = 24,

    checkboxSize = 30,
    checkboxLabelWidth = 170,
    checkboxLabelHeight = 22,
    checkboxLabelOffsetX = 8,

    difficultyDropdownY = -54,
    difficultyDropdownWidth = 145,

    symbolButtonSize = 54,
    symbolButtonGap = 8,
    thinSeparatorHeight = 16,
}

-- ============================================================
-- Shared arc constants
-- Adjust these for the final arc / separator layout.
-- ============================================================
local ARC_RADIUS = 200
local ARC_BOTTOM_DOWN = 250
local ARC_ANGLES = { 135, 112, 90, 68, 45 }

local SEP_RADIUS_FACTOR = 0.90
local SEP_ANGLES = { 123.5, 101, 79, 56.5 }

-- ============================================================
-- Feature toggles
-- ============================================================
local AUTO_FILL_SLOT5 = true
local PREVENT_DUPLICATES = true
local LOCK_AFTER_SEND = false

local THREE_SLOT_MODE_INDICES = { 2, 3, 4 }
local FIVE_SLOT_MODE_INDICES = { 1, 2, 3, 4, 5 }
local currentPatternSlotCount = 5
local manualDifficultyOverride = "auto"

-- ============================================================
-- Utility scaling helpers
-- ============================================================
local function scaleX(value)
    if value == nil then
        return 0
    end
    return math.floor((value * UI.width / BASE_UI.width) + 0.5)
end

local function scaleY(value)
    if value == nil then
        return 0
    end
    return math.floor((value * UI.height / BASE_UI.height) + 0.5)
end

-- ============================================================
-- Symbol definitions
-- ============================================================
local SYMS = {
    { label = "Diamond",  tex = TEX .. "sym_diamond.tga"  },
    { label = "Triangle", tex = TEX .. "sym_triangle.tga" },
    { label = "Circle",   tex = TEX .. "sym_circle.tga"   },
    { label = "Cross",    tex = TEX .. "sym_cross.tga"    },
    { label = "T",        tex = TEX .. "sym_t.tga"        },
}

-- ============================================================
-- Runtime state
-- Fixed slot model:
-- state[1] through state[5]
-- nil means the slot is empty.
-- ============================================================
local state = { nil, nil, nil, nil, nil }
local autoFilled = { false, false, false, false, false }
local win
local arcIcons = {}
local contentRegions = {}
local isCollapsed = false
local alsoSendRW = false
local testMode = false
local allowSelfTestSync = false
local slots = {}
local getArcButtonFromFocusRegion

-- ============================================================
-- Forward declarations
-- Group these here so async callbacks and cross-references
-- always bind to locals instead of falling back to globals.
-- ============================================================
local redraw
local applyLayout
local applyRaidDifficultyPatternMode
local ensureWindowBuilt
local handleSlashCommand

local clearState
local stateHasAnyEntries

local cancelAutoClearTimer
local refreshAutoClearTimer

local dragSourceStateIndex = nil
local dragHoverStateIndex = nil
local undoState = nil
local redoState = nil
local lastFullPattern = nil
local isPatternLocked = false
local changelogFrame = nil
local settingsFrame = nil
local DB_NAME = "LuraMemoryGameHelperDB"
local AUTO_CLEAR_SECONDS = 10
local addonDB

local function notifyInfo(msg)
    print("|cff8cd1ffLMG:|r " .. msg)
end


cancelAutoClearTimer = function()
    if LMG.CancelAutoClearTimer then
        LMG.CancelAutoClearTimer()
    end
end

refreshAutoClearTimer = function()
    if LMG.RefreshAutoClearTimer then
        LMG.RefreshAutoClearTimer()
    end
end

local CHANGELOG_TEXT = table.concat({
    "Lura Memory Game Helper v" .. ADDON_VERSION,
    "",
    "Phase 2 highlights:",
    "- SavedVariables persistence for window position, size, collapse state, and toggles",
    "- /lmg redo support",
    "- /lmg locksend on|off support",
    "- Pattern lock / unlock controls",
    "",
    "Recent additions:",
    "- Smart autofill now fills the only remaining empty slot",
    "- Drag filled to filled = swap",
    "- Drag filled to empty = move",
    "- Click filled slot = clear",
    "- One-step undo support",
    "- Difficulty-aware 3-slot Normal mode and 5-slot Heroic/Mythic mode",
    "- Dropdown difficulty override for testing outside raid",
}, "\n")

local function shouldShowChangelog()
    local settings = LMG.GetSettingsDB and LMG.GetSettingsDB()
    return settings and settings.changelogDismissedVersion ~= ADDON_VERSION
end

local function setChangelogDismissedForCurrentVersion(shouldDismiss)
    local settings = LMG.GetSettingsDB and LMG.GetSettingsDB()
    if not settings then
        return
    end
    settings.changelogDismissedVersion = shouldDismiss and ADDON_VERSION or ""
end

local function buildChangelogFrame()
    if changelogFrame then
        return
    end

    local f = CreateFrame("Frame", "LuraMemoryGameHelperChangelog", UIParent, "BackdropTemplate")
    f:SetSize(520, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.04, 0.04, 0.08, 0.95)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Lura Memory Game Helper - Changelog")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 58)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(460, 260)
    scroll:SetScrollChild(content)

    local body = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    body:SetWidth(440)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(4)
    body:SetText(CHANGELOG_TEXT)
    content.body = body

    local cb = CreateFrame("CheckButton", nil, f)
    cb:SetSize(24, 24)
    cb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)

    local cbBg = cb:CreateTexture(nil, "BACKGROUND")
    cbBg:SetAllPoints()
    cbBg:SetTexture(TEX .. "checkbox_unchecked.tga")

    local cbCheck = cb:CreateTexture(nil, "ARTWORK")
    cbCheck:SetAllPoints()
    cbCheck:SetTexture(TEX .. "checkbox_checked.tga")
    cb.checkedTex = cbCheck
    cbCheck:SetShown(false)

    local cbLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    cbLabel:SetText("Don't show again until next update")

    cb:SetScript("OnClick", function(self)
        self.checkedTex:SetShown(not self.checkedTex:IsShown())
    end)

    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(90, 24)
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 18)
    ok:SetText("Close")
    ok:SetScript("OnClick", function()
        setChangelogDismissedForCurrentVersion(cb.checkedTex:IsShown())
        if LMG.SaveSettingsState then LMG.SaveSettingsState() end
        f:Hide()
    end)

    f.dismissCheck = cb
    changelogFrame = f
end

local function showChangelogIfNeeded()
    if not shouldShowChangelog() then
        return
    end
    buildChangelogFrame()
    changelogFrame.dismissCheck.checkedTex:SetShown(false)
    changelogFrame:Show()
end

local function notifyLocked()
    local msg = "Pattern is locked. Use /lmg unlock or clear the pattern."
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1.0, 0.35, 0.35, 1.0)
    end
    notifyInfo(msg)
end

local function canEditPattern()
    if isPatternLocked then
        notifyLocked()
        return false
    end
    return true
end

local function copySlots(src)
    local out = {}
    for i = 1, MAX do
        out[i] = src[i]
    end
    return out
end

local function makeSnapshot()
    return {
        state = copySlots(state),
        autoFilled = copySlots(autoFilled),
        isPatternLocked = isPatternLocked,
    }
end

local function applySnapshot(snapshot)
    if not snapshot then
        return
    end

    state = copySlots(snapshot.state)
    autoFilled = copySlots(snapshot.autoFilled)
    isPatternLocked = not not snapshot.isPatternLocked
    if LMG.Redraw then LMG.Redraw() end
end

local function saveLastFullPatternIfComplete()
    for i = 1, MAX do
        if not state[i] then
            return
        end
    end

    lastFullPattern = {
        state = copySlots(state),
        autoFilled = copySlots(autoFilled),
    }
end

local function saveUndoState()
    undoState = makeSnapshot()
    redoState = nil
end

local function restoreUndoState()
    if not undoState then
        return false
    end

    redoState = makeSnapshot()
    local snapshot = undoState
    undoState = nil
    applySnapshot(snapshot)
    if LMG.SaveWindowState then LMG.SaveWindowState() end
    return true
end

local function restoreRedoState()
    if not redoState then
        return false
    end

    undoState = makeSnapshot()
    local snapshot = redoState
    redoState = nil
    applySnapshot(snapshot)
    return true
end

local function restoreLastFullPattern()
    if lastFullPattern then
        saveUndoState()
        state = copySlots(lastFullPattern.state)
        autoFilled = copySlots(lastFullPattern.autoFilled)
        isPatternLocked = false
        if LMG.Redraw then LMG.Redraw() end
        return true
    end
    return false
end


-- ============================================================
-- Shared geometry helpers
-- ============================================================
local function getArcGeometry()
    local sx = UI.width / 395
    local sy = UI.height / 535

    local radius = ARC_RADIUS * sy
    local bottomDown = ARC_BOTTOM_DOWN * sy
    local centerDown = bottomDown - radius

    return sx, sy, radius, bottomDown, centerDown
end

local function buildSeparatorPoints()
    local sx, sy, radius, _, centerDown = getArcGeometry()
    local sepRadius = radius * SEP_RADIUS_FACTOR
    local sepPoints = {}

    for i = 1, 4 do
        local rad = math.rad(SEP_ANGLES[i])
        local x = sepRadius * math.cos(rad) * (sx / sy)
        local down = centerDown + sepRadius * math.sin(rad)

        sepPoints[i] = {
            x = math.floor(x + 0.5),
            y = math.floor(-down + 0.5),
        }
    end

    return sepPoints
end

-- ============================================================
-- Compute icon arc positions
-- ============================================================
local function recomputeSlots()
    local sx, sy, radius, _, centerDown = getArcGeometry()

    for i = 1, 5 do
        local rad = math.rad(ARC_ANGLES[i])
        local x = radius * math.cos(rad) * (sx / sy)
        local down = centerDown + radius * math.sin(rad)

        slots[i] = {
            x = math.floor(x + 0.5),
            y = math.floor(-down + 0.5),
        }
    end
end

recomputeSlots()

getArcButtonFromFocusRegion = function(region)
    local current = region
    while current do
        if current.stateIndex and current.tex then
            return current
        end
        if current.GetParent then
            current = current:GetParent()
        else
            current = nil
        end
    end
    return nil
end

-- ============================================================
-- Small string helpers
-- ============================================================
local function trim(s)
    return (s and s:match("^%s*(.-)%s*$")) or ""
end

local function normalize(s)
    return trim((s or ""):lower())
end

-- ============================================================
-- Detect whether we are in the target raid
-- ============================================================
local function inTargetRaid()
    local name, instanceType = GetInstanceInfo()
    return instanceType == "raid" and name == TARGET_RAID_NAME
end

local function getActiveSlotIndices()
    return currentPatternSlotCount == 3 and THREE_SLOT_MODE_INDICES or FIVE_SLOT_MODE_INDICES
end

local function isStateSlotActive(stateIndex)
    if currentPatternSlotCount == 3 then
        return stateIndex >= 2 and stateIndex <= 4
    end
    return stateIndex >= 1 and stateIndex <= 5
end

local function isSeparatorActive(separatorIndex)
    if currentPatternSlotCount == 3 then
        return separatorIndex == 2 or separatorIndex == 3
    end
    return true
end

local function getPatternSlotCountForCurrentDifficulty()
    if manualDifficultyOverride and manualDifficultyOverride ~= "auto" then
        if manualDifficultyOverride == "normal" then
            return 3
        end
        return 5
    end

    if not inTargetRaid() then
        return 5
    end

    local difficultyID = GetRaidDifficultyID and GetRaidDifficultyID() or nil
    if not difficultyID then
        return 5
    end

    local _, groupType, isHeroic, _, _, displayMythic = GetDifficultyInfo(difficultyID)
    if groupType ~= "raid" then
        return 5
    end

    if displayMythic or isHeroic then
        return 5
    end

    return 3
end


-- ============================================================
-- Generic tooltip helper
-- ============================================================
local function attachTooltip(frame, anchor, textProvider)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_TOP")
        local text = type(textProvider) == "function" and textProvider() or textProvider
        if text and text ~= "" then
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- ============================================================
-- Track UI regions that should hide while collapsed
-- ============================================================
local function registerContent(region)
    contentRegions[#contentRegions + 1] = region
    return region
end

-- ============================================================
-- Symbol lookup by label
-- ============================================================
local function getSymByLabel(label)
    local needle = trim(label):lower()
    for _, sym in ipairs(SYMS) do
        if sym.label:lower() == needle then
            return sym
        end
    end
end

-- ============================================================
-- State helpers
-- ============================================================
local function clearStateTable()
    for i = 1, MAX do
        state[i] = nil
        autoFilled[i] = false
    end
end

local function clearAutoFilledSlots()
    for i = 1, MAX do
        if autoFilled[i] then
            state[i] = nil
            autoFilled[i] = false
        end
    end
end

clearState = function()
    clearStateTable()
end

local function setStateFromDecoded(decoded)
    clearStateTable()
    local activeSlots = getActiveSlotIndices()
    local writePointer = 1

    for i = 1, #decoded do
        if decoded[i] and activeSlots[writePointer] then
            local targetIndex = activeSlots[writePointer]
            state[targetIndex] = decoded[i]
            autoFilled[targetIndex] = false
            writePointer = writePointer + 1
            if not activeSlots[writePointer] then
                break
            end
        end
    end
end

stateHasAnyEntries = function()
    for _, i in ipairs(getActiveSlotIndices()) do
        if state[i] then
            return true
        end
    end
    return false
end

local function stateContainsSymbol(sym)
    for _, i in ipairs(getActiveSlotIndices()) do
        if state[i] and state[i].label == sym.label then
            return true
        end
    end
    return false
end

local function getRemainingUnusedSymbol()
    local remaining = nil
    local remainingCount = 0

    for _, sym in ipairs(SYMS) do
        if not stateContainsSymbol(sym) then
            remaining = sym
            remainingCount = remainingCount + 1
        end
    end

    if remainingCount == 1 then
        return remaining
    end

    return nil
end

local function getSingleEmptySlotIndex()
    local emptyIndex = nil
    local emptyCount = 0

    for _, i in ipairs(getActiveSlotIndices()) do
        if not state[i] then
            emptyIndex = i
            emptyCount = emptyCount + 1
        end
    end

    if emptyCount == 1 then
        return emptyIndex
    end

    return nil
end

local function autoFillRemainingSlotIfNeeded()
    if not AUTO_FILL_SLOT5 or currentPatternSlotCount ~= 5 then
        return
    end

    local emptyIndex = getSingleEmptySlotIndex()
    if not emptyIndex then
        return
    end

    local remaining = getRemainingUnusedSymbol()
    if remaining then
        state[emptyIndex] = remaining
        autoFilled[emptyIndex] = true
    end
end

-- ============================================================
-- Refresh visible arc from current state
-- Visual order remains right-to-left:
-- state[1] -> visual slot 5
-- state[2] -> visual slot 4
-- ...
-- state[5] -> visual slot 1
-- ============================================================


-----------------------------------------------------------------------
-- Broadcast-related UI state
--
-- This remains in Core because it directly manipulates live frame
-- widgets. The permission decision itself is now owned by Broadcast.lua.
-----------------------------------------------------------------------
local function updateBroadcastControls()
    if not win then return end

    local enabled = LMG.PlayerCanBroadcast and LMG.PlayerCanBroadcast() or false

    if win.clearBtn then
        win.clearBtn:SetEnabled(enabled)
        win.clearBtn:SetAlpha(enabled and 1 or 0.45)
    end

    if win.sendBtn then
        win.sendBtn:SetEnabled(enabled)
        win.sendBtn:SetAlpha(enabled and 1 or 0.45)
    end

    if win.rwCheckbox then
        win.rwCheckbox:SetEnabled(enabled)
        win.rwCheckbox:SetAlpha(enabled and 1 or 0.45)

        if not enabled then
            alsoSendRW = false
            if win.rwCheckbox.checkedTex then
                win.rwCheckbox.checkedTex:SetShown(false)
            end
            if LMG.SaveSettingsState then LMG.SaveSettingsState() end
        end
    end
end

-- ============================================================
-- Window show / hide / collapse helpers
-- ============================================================
local function showWindow(expand)
    if not win then return end

    win:Show()

    if expand then
        isCollapsed = false
        for _, region in ipairs(contentRegions) do
            region:Show()
        end
        win:SetHeight(UI.height)
        if win.minBtn then
            win.minBtn:SetText("-")
        end
        if LMG.Redraw then LMG.Redraw() end
    end
end

local function hideWindow()
    if win then
        win:Hide()
    end
end

local function toggleWindow()
    if not win then return end
    if win:IsShown() then
        hideWindow()
    else
        showWindow(false)
    end
end

local function setCollapsed(collapsed)
    if not win then return end

    isCollapsed = collapsed

    for _, region in ipairs(contentRegions) do
        if collapsed then
            region:Hide()
        else
            region:Show()
        end
    end

    if collapsed then
        win:SetHeight(UI.collapsedHeight)
        if win.minBtn then
            win.minBtn:SetText("+")
        end
    else
        win:SetHeight(UI.height)
        if win.minBtn then
            win.minBtn:SetText("-")
        end
    end

    if LMG.Redraw then LMG.Redraw() end
    if LMG.SaveWindowState then LMG.SaveWindowState() end
end

local function toggleCollapsed()
    setCollapsed(not isCollapsed)
end

-- ============================================================
-- Pattern actions
-- ============================================================
local function doClear(sendChat)
    cancelAutoClearTimer()
    clearState()
    isPatternLocked = false
    if LMG.Redraw then LMG.Redraw() end

    -------------------------------------------------------------------
    -- BACKUP ONLY: [LMG] CLEAR broadcast path
    --
    -- This path is intentionally disabled. The addon now treats an
    -- incoming [LMG] PATTERN message as the start of that pattern's
    -- local lifetime and clears through the timer instead of syncing a
    -- later CLEAR message.
    --
    -- if sendChat then
    --     SendChatMessage(SAY_PREFIX .. " CLEAR", "SAY")
    -- end
    -------------------------------------------------------------------
end

local function sendPattern()
    if not stateHasAnyEntries() then return end

    -- Apply lock immediately so the send action cannot race with chat-sync.
    if LOCK_AFTER_SEND then
        isPatternLocked = true
    else
        isPatternLocked = false
    end

    saveLastFullPatternIfComplete()
    SendChatMessage(SAY_PREFIX .. " PATTERN: " .. currentPatternText(), "SAY")
    maybeSendRW()

    if LOCK_AFTER_SEND then
        notifyInfo("Pattern locked after send. Use /lmg unlock or clear the pattern.")
    end

    refreshAutoClearTimer()
    if LMG.Redraw then LMG.Redraw() end
end

local function addSymbol(sym)
    if not canEditPattern() then
        return
    end

    if PREVENT_DUPLICATES and stateContainsSymbol(sym) then
        local msg = "LMG: " .. sym.label .. " is already used."
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(msg, 1.0, 0.35, 0.35, 1.0)
        end
        print("|cffff8080" .. msg .. "|r")
        return
    end

    saveUndoState()
    clearAutoFilledSlots()

    for _, i in ipairs(getActiveSlotIndices()) do
        if not state[i] then
            state[i] = sym
            autoFilled[i] = false
            autoFillRemainingSlotIfNeeded()
            saveLastFullPatternIfComplete()
            if LMG.Redraw then LMG.Redraw() end
            return
        end
    end
end

-- ============================================================
-- Decorative custom frame border
-- ============================================================












applyLayout = function()
    if LMG.ApplyLayout then
        return LMG.ApplyLayout()
    end
end


local function buildWindow()
    if win then return end
    recomputeSlots()
    if LMG.BuildMainFrame then LMG.BuildMainFrame() end
    if LMG.BuildTitleBar then LMG.BuildTitleBar() end
    if LMG.BuildArcDisplay then LMG.BuildArcDisplay() end
    if LMG.BuildActionButtons then LMG.BuildActionButtons() end
    if LMG.BuildRWCheckbox then LMG.BuildRWCheckbox() end
    if LMG.BuildDifficultyDropdown then LMG.BuildDifficultyDropdown() end
    if LMG.BuildSymbolButtons then LMG.BuildSymbolButtons() end
    applyLayout()
    updateBroadcastControls()
    if win.rwCheckbox and win.rwCheckbox.checkedTex then
        win.rwCheckbox.checkedTex:SetShown(alsoSendRW)
    end
    if isCollapsed then
        setCollapsed(true)
    end
end

ensureWindowBuilt = function()
    if not win then
        buildWindow()
    end
    if LMG.BuildSettingsWindow then
        LMG.BuildSettingsWindow()
    end
end

applyRaidDifficultyPatternMode = function()
    local newSlotCount = getPatternSlotCountForCurrentDifficulty()
    if newSlotCount == currentPatternSlotCount then
        if win then
            if LMG.Redraw then LMG.Redraw() end
        end
        return
    end

    local hadEntries = stateHasAnyEntries()
    local shouldClear = false

    if newSlotCount == 3 and (state[1] or state[5]) then
        shouldClear = true
    end

    currentPatternSlotCount = newSlotCount

    if shouldClear then
        cancelAutoClearTimer()
        clearState()
        isPatternLocked = false
        if hadEntries then
            notifyInfo("Raid difficulty changed. Pattern cleared for 3-slot mode.")
        end
    end

    if inTargetRaid() then
        if newSlotCount == 3 then
            notifyInfo("Normal difficulty detected. Using middle 3 arc slots.")
        else
            notifyInfo("Heroic or Mythic difficulty detected. Using all 5 arc slots.")
        end
    end

    if win then
        applyLayout()
        if LMG.Redraw then LMG.Redraw() end
    end
end

local function autoHandleTargetRaid()
    if inTargetRaid() then
        ensureWindowBuilt()
        applyRaidDifficultyPatternMode()
        if not win:IsShown() then
            showWindow(true)
        end
        autoInitialized = true
    else
        currentPatternSlotCount = getPatternSlotCountForCurrentDifficulty()
        if win then
            applyLayout()
            if LMG.Redraw then LMG.Redraw() end
            if LMG.RefreshDifficultyDropdown then LMG.RefreshDifficultyDropdown() end
        end
        if win and autoInitialized then
            hideWindow()
        end
    end
end




-----------------------------------------------------------------------
-- Core bridge exports
--
-- These exports are the shared API surface used by the split modules.
-- Events.lua, UI modules, and future logic modules should call through
-- this bridge instead of reaching for Core locals directly.
-----------------------------------------------------------------------
LMG.NotifyInfo = notifyInfo
LMG.UpdateBroadcastControls = updateBroadcastControls
LMG.SaveUndoState = saveUndoState
LMG.DoClear = doClear
LMG.ShowWindow = showWindow
LMG.HideWindow = hideWindow
LMG.RestoreUndoState = restoreUndoState
LMG.RestoreRedoState = restoreRedoState
LMG.RestoreLastFullPattern = restoreLastFullPattern
LMG.GetTestMode = function() return testMode end
LMG.SetTestMode = function(v) testMode = not not v end
LMG.GetAllowSelfTestSync = function() return allowSelfTestSync end
LMG.SetAllowSelfTestSync = function(v) allowSelfTestSync = not not v end
LMG.GetLockAfterSend = function() return LOCK_AFTER_SEND end
LMG.SetLockAfterSend = function(v) LOCK_AFTER_SEND = not not v end
LMG.GetAutoFill = function() return AUTO_FILL_SLOT5 end
LMG.SetAutoFill = function(v) AUTO_FILL_SLOT5 = not not v end
LMG.GetPreventDuplicates = function() return PREVENT_DUPLICATES end
LMG.SetPreventDuplicates = function(v) PREVENT_DUPLICATES = not not v end
LMG.GetSayPrefix = function() return SAY_PREFIX end
LMG.GetSymbols = function() return SYMS end
LMG.StateHasAnyEntries = stateHasAnyEntries
LMG.GetState = function() return state end
LMG.GetActiveSlotIndices = getActiveSlotIndices
LMG.GetLockAfterSend = function() return LOCK_AFTER_SEND end
LMG.SetPatternLocked = function(v) isPatternLocked = not not v end
LMG.SaveLastFullPatternIfComplete = saveLastFullPatternIfComplete
LMG.CurrentPatternText = currentPatternText
LMG.SetStateFromDecoded = setStateFromDecoded
LMG.AutoFillRemainingSlotIfNeeded = autoFillRemainingSlotIfNeeded
LMG.GetPatternLocked = function() return isPatternLocked end
LMG.GetWindow = function() return win end
LMG.BuildChangelogFrame = buildChangelogFrame
LMG.GetChangelogFrame = function() return changelogFrame end
LMG.GetAlsoSendRW = function() return alsoSendRW end
LMG.SetAlsoSendRW = function(v) alsoSendRW = not not v end
LMG.GetManualDifficultyOverride = function() return manualDifficultyOverride end
LMG.SetManualDifficultyOverride = function(v) manualDifficultyOverride = v or "auto" end
LMG.RefreshDifficultyDropdown = refreshDifficultyDropdown
LMG.ApplyRaidDifficultyPatternMode = applyRaidDifficultyPatternMode
LMG.SetWindow = function(v) win = v end
LMG.GetWindow = function() return win end
LMG.GetArcIcons = function() return arcIcons end
LMG.GetSlots = function() return slots end
LMG.GetState = function() return state end
LMG.GetAutoFilled = function() return autoFilled end
LMG.GetMaxSymbols = function() return MAX end
LMG.IsStateSlotActive = isStateSlotActive
LMG.IsSeparatorActive = isSeparatorActive
LMG.GetActiveSlotIndices = getActiveSlotIndices
LMG.CanEditPattern = canEditPattern
LMG.GetPatternLocked = function() return isPatternLocked end
LMG.NotifyLocked = notifyLocked
LMG.ClearAutoFilledSlots = clearAutoFilledSlots
LMG.AutoFillRemainingSlotIfNeeded = autoFillRemainingSlotIfNeeded
LMG.SaveLastFullPatternIfComplete = saveLastFullPatternIfComplete
LMG.GetArcButtonFromFocusRegion = getArcButtonFromFocusRegion
LMG.RecomputeSlots = recomputeSlots
LMG.BuildSeparatorPoints = buildSeparatorPoints
LMG.GetDragSourceStateIndex = function() return dragSourceStateIndex end
LMG.SetDragSourceStateIndex = function(v) dragSourceStateIndex = v end
LMG.GetDragHoverStateIndex = function() return dragHoverStateIndex end
LMG.SetDragHoverStateIndex = function(v) dragHoverStateIndex = v end
LMG.ScaleX = scaleX
LMG.ScaleY = scaleY
LMG.RegisterContent = registerContent
LMG.AttachTooltip = attachTooltip
LMG.ToggleCollapsed = toggleCollapsed
LMG.GetCollapsedState = function() return isCollapsed end
LMG.ApplyLayout = applyLayout
LMG.GetSymbols = function() return SYMS end
LMG.AddSymbol = addSymbol

LMG.ToggleMinimap = function()
    local minimapDB = LMG.GetMinimapDB and LMG.GetMinimapDB()
    if not minimapDB or not LDBIcon then
        return
    end
    minimapDB.hide = not minimapDB.hide
    if minimapDB.hide then
        LDBIcon:Hide(ADDON_NAME)
    else
        LDBIcon:Show(ADDON_NAME)
    end
    notifyInfo("Minimap button " .. (minimapDB.hide and "hidden." or "shown."))
end

LMG.UI = UI
LMG.DB_NAME = DB_NAME
LMG.SetAddonDB = function(db) addonDB = db end
LMG.GetAddonDB = function() return addonDB end
LMG.ApplyDBSettings = function(window, settings)
    UI.width = math.max(UI.minWidth, math.min(UI.maxWidth, tonumber(window and window.width) or UI.width))
    UI.height = math.max(UI.minHeight, math.min(UI.maxHeight, tonumber(window and window.height) or UI.height))
    UI.windowAnchor = (window and window.point) or UI.windowAnchor
    UI.windowRelativePoint = (window and window.relativePoint) or UI.windowRelativePoint
    UI.windowOffsetX = tonumber(window and window.x) or UI.windowOffsetX
    UI.windowOffsetY = tonumber(window and window.y) or UI.windowOffsetY
    isCollapsed = not not (window and window.collapsed)

    AUTO_FILL_SLOT5 = not not (settings and settings.autoFill)
    PREVENT_DUPLICATES = not not (settings and settings.preventDuplicates)
    LOCK_AFTER_SEND = not not (settings and settings.lockAfterSend)
    alsoSendRW = not not (settings and settings.alsoSendRW)
    if settings then
        settings.changelogDismissedVersion = settings.changelogDismissedVersion or ""
        manualDifficultyOverride = settings.difficultyMode or "auto"
    end
end
LMG.CollectWindowState = function()
    local data = {
        width = UI.width,
        height = UI.height,
        collapsed = isCollapsed,
        point = UI.windowAnchor,
        relativePoint = UI.windowRelativePoint,
        x = UI.windowOffsetX,
        y = UI.windowOffsetY,
    }
    if win and win.GetPoint then
        local point, _, relativePoint, x, y = win:GetPoint(1)
        data.point = point or data.point
        data.relativePoint = relativePoint or data.relativePoint
        data.x = x or data.x
        data.y = y or data.y
    end
    return data
end
LMG.CollectSettingsState = function()
    return {
        autoFill = AUTO_FILL_SLOT5,
        preventDuplicates = PREVENT_DUPLICATES,
        lockAfterSend = LOCK_AFTER_SEND,
        alsoSendRW = alsoSendRW,
        difficultyMode = manualDifficultyOverride or "auto",
    }
end

LMG.GetAutoClearSeconds = function() return AUTO_CLEAR_SECONDS end
LMG.StateHasAnyEntries = stateHasAnyEntries
LMG.ClearState = clearState
LMG.Redraw = redraw
LMG.SetPatternLocked = function(v) isPatternLocked = not not v end
LMG.HandleSlashCommand = handleSlashCommand
LMG.EnsureWindowBuilt = ensureWindowBuilt
LMG.ToggleWindow = toggleWindow
LMG.AddonName = ADDON_NAME
LMG.TexPath = TEX


-----------------------------------------------------------------------
-- Event bridge exports
--
-- These wrappers keep Events.lua thin and allow event wiring to stay
-- separate from gameplay / UI logic without changing behavior.
-----------------------------------------------------------------------
LMG.InitializeCurrentPatternSlotCount = function()
    currentPatternSlotCount = getPatternSlotCountForCurrentDifficulty()
end

LMG.ShowChangelogIfNeeded = showChangelogIfNeeded
LMG.HandleRosterOrZoneChange = autoHandleTargetRaid
