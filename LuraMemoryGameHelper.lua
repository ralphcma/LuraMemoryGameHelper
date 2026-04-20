-- ============================================================
-- Lura Memory Game Helper
-- Version: 1.4.4
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

local ADDON_NAME = "LuraMemoryGameHelper"
local ADDON_VERSION = "1.4.4"
local SAY_PREFIX = "[LMG]"
local TEX = "Interface\\AddOns\\LuraMemoryGameHelper\\Textures\\"
local MAX = 5

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
    return math.floor((value * UI.width / BASE_UI.width) + 0.5)
end

local function scaleY(value)
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
local slots = {}
local getArcButtonFromFocusRegion


local redraw
local applyRaidDifficultyPatternMode
local dragSourceStateIndex = nil
local dragHoverStateIndex = nil
local undoState = nil
local redoState = nil
local lastFullPattern = nil
local isPatternLocked = false
local changelogFrame = nil
local DB_NAME = "LuraMemoryGameHelperDB"

local DEFAULT_DB = {
    window = {
        width = UI.width,
        height = UI.height,
        point = UI.windowAnchor,
        relativePoint = UI.windowRelativePoint,
        x = UI.windowOffsetX,
        y = UI.windowOffsetY,
        collapsed = false,
    },
    settings = {
        autoFill = true,
        preventDuplicates = true,
        lockAfterSend = false,
        alsoSendRW = false,
        changelogDismissedVersion = "",
        difficultyMode = "auto",
    }
}


local function ensureSubTable(root, key)
    if type(root[key]) ~= "table" then
        root[key] = {}
    end
    return root[key]
end

local function initializeDB()
    if type(_G[DB_NAME]) ~= "table" then
        _G[DB_NAME] = {}
    end

    local db = _G[DB_NAME]
    local window = ensureSubTable(db, "window")
    local settings = ensureSubTable(db, "settings")

    for k, v in pairs(DEFAULT_DB.window) do
        if window[k] == nil then
            window[k] = v
        end
    end

    for k, v in pairs(DEFAULT_DB.settings) do
        if settings[k] == nil then
            settings[k] = v
        end
    end

    UI.width = math.max(UI.minWidth, math.min(UI.maxWidth, tonumber(window.width) or UI.width))
    UI.height = math.max(UI.minHeight, math.min(UI.maxHeight, tonumber(window.height) or UI.height))
    UI.windowAnchor = window.point or UI.windowAnchor
    UI.windowRelativePoint = window.relativePoint or UI.windowRelativePoint
    UI.windowOffsetX = tonumber(window.x) or UI.windowOffsetX
    UI.windowOffsetY = tonumber(window.y) or UI.windowOffsetY
    isCollapsed = not not window.collapsed

    AUTO_FILL_SLOT5 = not not settings.autoFill
    PREVENT_DUPLICATES = not not settings.preventDuplicates
    LOCK_AFTER_SEND = not not settings.lockAfterSend
    alsoSendRW = not not settings.alsoSendRW
    settings.changelogDismissedVersion = settings.changelogDismissedVersion or ""
    manualDifficultyOverride = settings.difficultyMode or "auto"
end

local function saveWindowState()
    if not _G[DB_NAME] or type(_G[DB_NAME]) ~= "table" then
        return
    end

    local db = _G[DB_NAME]
    local window = ensureSubTable(db, "window")
    window.width = UI.width
    window.height = UI.height
    window.collapsed = isCollapsed

    if win and win.GetPoint then
        local point, _, relativePoint, x, y = win:GetPoint(1)
        window.point = point or UI.windowAnchor
        window.relativePoint = relativePoint or UI.windowRelativePoint
        window.x = x or UI.windowOffsetX
        window.y = y or UI.windowOffsetY
    else
        window.point = UI.windowAnchor
        window.relativePoint = UI.windowRelativePoint
        window.x = UI.windowOffsetX
        window.y = UI.windowOffsetY
    end
end

local function saveSettingsState()
    if not _G[DB_NAME] or type(_G[DB_NAME]) ~= "table" then
        return
    end

    local db = _G[DB_NAME]
    local settings = ensureSubTable(db, "settings")
    settings.autoFill = AUTO_FILL_SLOT5
    settings.preventDuplicates = PREVENT_DUPLICATES
    settings.lockAfterSend = LOCK_AFTER_SEND
    settings.alsoSendRW = alsoSendRW
    settings.changelogDismissedVersion = settings.changelogDismissedVersion or ""
    settings.difficultyMode = manualDifficultyOverride or "auto"
end

local function notifyInfo(msg)
    print("|cff8cd1ffLMG:|r " .. msg)
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
    local db = _G[DB_NAME]
    return db and db.settings and db.settings.changelogDismissedVersion ~= ADDON_VERSION
end

local function setChangelogDismissedForCurrentVersion(shouldDismiss)
    local db = _G[DB_NAME]
    if not db or not db.settings then
        return
    end
    db.settings.changelogDismissedVersion = shouldDismiss and ADDON_VERSION or ""
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
        saveSettingsState()
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
    redraw()
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
    saveWindowState()
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
        redraw()
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

local function clearState()
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

local function stateHasAnyEntries()
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
redraw = function()
    for visualIndex = 1, MAX do
        local btn = arcIcons[visualIndex]
        local stateIndex = MAX - visualIndex + 1

        if btn then
            btn.tex:SetTexture(nil)
            btn:SetAlpha(1)

            if isCollapsed or not isStateSlotActive(stateIndex) then
                btn:Hide()
                if btn.placeholder then
                    btn.placeholder:Hide()
                end
            else
                btn:Show()
                if btn.placeholder then
                    btn.placeholder:Show()
                end
            end
        end
    end

    if isCollapsed then
        return
    end

    for _, stateIndex in ipairs(getActiveSlotIndices()) do
        local entry = state[stateIndex]
        if entry then
            local visualIndex = MAX - stateIndex + 1
            local btn = arcIcons[visualIndex]
            if btn then
                btn.tex:SetTexture(entry.tex)
                btn:Show()
                if btn.placeholder then
                    btn.placeholder:Hide()
                end
                if autoFilled[stateIndex] then
                    btn:SetAlpha(0.75)
                else
                    btn:SetAlpha(1)
                end
            end
        end
    end

    if win and win.arcSeparators then
        for i, sep in ipairs(win.arcSeparators) do
            if isSeparatorActive(i) then
                sep:Show()
            else
                sep:Hide()
            end
        end
    end

    if win and win.statusText then
        if isPatternLocked then
            win.statusText:SetText("Pattern Helper  •  Locked")
            win.statusText:SetTextColor(1.0, 0.35, 0.35, 0.95)
        else
            win.statusText:SetText("Pattern Helper")
            win.statusText:SetTextColor(0.85, 0.85, 0.92, 0.90)
        end
    end
end

local function patternToText(pattern)
    local parts = {}
    for _, i in ipairs(getActiveSlotIndices()) do
        local entry = pattern[i]
        if entry then
            parts[#parts + 1] = entry.label
        end
    end
    return (#parts > 0) and table.concat(parts, " > ") or "(empty)"
end

local function currentPatternText()
    return patternToText(state)
end

-- ============================================================
-- Convert chat text back into a packed decoded array
-- ============================================================
local function textToPattern(text)
    local decoded = {}

    for rawPart in tostring(text):gmatch("([^>]+)") do
        local sym = getSymByLabel(rawPart)
        if sym then
            decoded[#decoded + 1] = sym
            if #decoded >= MAX then
                break
            end
        end
    end

    return decoded
end

-- ============================================================
-- Convert labels to raid-warning output text
-- ============================================================
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
    for _, i in ipairs(getActiveSlotIndices()) do
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

-- ============================================================
-- Permission check for broadcasting actions
-- ============================================================
local function playerCanBroadcast()
    if testMode then
        return true
    end

    if not IsInRaid() then
        return false
    end

    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function maybeSendRW()
    if not alsoSendRW or not stateHasAnyEntries() then
        return
    end

    local rwText = buildRWText()
    if rwText then
        SendChatMessage(rwText, "RAID_WARNING")
    end
end

-- ============================================================
-- Enable / disable controls based on permissions
-- ============================================================
local function updateBroadcastControls()
    if not win then return end

    local enabled = playerCanBroadcast()

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
            saveSettingsState()
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
        redraw()
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

    redraw()
    saveWindowState()
end

local function toggleCollapsed()
    setCollapsed(not isCollapsed)
end

-- ============================================================
-- Pattern actions
-- ============================================================
local function doClear(sendChat)
    clearState()
    isPatternLocked = false
    redraw()
    if sendChat then
        SendChatMessage(SAY_PREFIX .. " CLEAR", "SAY")
    end
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

    redraw()
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
            redraw()
            return
        end
    end
end

-- ============================================================
-- Decorative custom frame border
-- ============================================================
local function buildCustomFrameBorder(parent)
    local inset = scaleX(UI.frameInset)
    local edge = scaleX(UI.frameEdge)
    local corner = scaleX(UI.cornerSize)

    local tl = parent:CreateTexture(nil, "OVERLAY")
    tl:SetTexture(TEX .. "frame_corner_tl.tga")
    tl:SetSize(corner, corner)
    tl:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)

    local tr = parent:CreateTexture(nil, "OVERLAY")
    tr:SetTexture(TEX .. "frame_corner_tr.tga")
    tr:SetSize(corner, corner)
    tr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)

    local bl = parent:CreateTexture(nil, "OVERLAY")
    bl:SetTexture(TEX .. "frame_corner_bl.tga")
    bl:SetSize(corner, corner)
    bl:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)

    local br = parent:CreateTexture(nil, "OVERLAY")
    br:SetTexture(TEX .. "frame_corner_br.tga")
    br:SetSize(corner, corner)
    br:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)

    local top = parent:CreateTexture(nil, "OVERLAY")
    top:SetTexture(TEX .. "frame_border_top.tga")
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT", -1, 0)
    top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 1, 0)
    top:SetHeight(edge)

    local bottom = parent:CreateTexture(nil, "OVERLAY")
    bottom:SetTexture(TEX .. "frame_border_bottom.tga")
    bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", -1, 0)
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 1, 0)
    bottom:SetHeight(edge)

    local left = parent:CreateTexture(nil, "OVERLAY")
    left:SetTexture(TEX .. "frame_border_left.tga")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 1)
    left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, -1)
    left:SetWidth(edge)

    local right = parent:CreateTexture(nil, "OVERLAY")
    right:SetTexture(TEX .. "frame_border_right.tga")
    right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 1)
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, -1)
    right:SetWidth(edge)

    parent.customBorder = {
        tl = tl, tr = tr, bl = bl, br = br,
        top = top, bottom = bottom, left = left, right = right,
    }
end

local function makeTexturedActionButton(parent, width, height, point, relTo, relPoint, x, y, upTex, downTex, tooltipText, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    btn:SetPoint(point, relTo, relPoint, x, y)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(upTex)
    btn.bg = bg
    btn.bg:SetVertexColor(1, 1, 1, 0.96)

    btn:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" and self.bg then
            self.bg:SetTexture(downTex or upTex)
        end
    end)

    btn:SetScript("OnMouseUp", function(self)
        if self.bg then
            self.bg:SetTexture(upTex)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        self:SetScale(1.03)
        if self.bg then
            self.bg:SetVertexColor(1, 1, 1, 1)
        end
        if tooltipText and tooltipText ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetScale(1.0)
        if self.bg then
            self.bg:SetTexture(upTex)
            self.bg:SetVertexColor(1, 1, 1, 0.96)
        end
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", onClick)

    if tooltipText and tooltipText ~= "" then
        attachTooltip(btn, "ANCHOR_TOP", tooltipText)
    end

    return btn
end

local function makeInnerSeparator(parent, yOffsetFromTop, alpha)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(TEX .. "thin_separator.tga")
    sep:SetSize(UI.width - (scaleX(UI.outerPad) * 2), scaleY(UI.thinSeparatorHeight))
    sep:SetPoint("TOP", parent, "TOP", 0, yOffsetFromTop)
    sep:SetAlpha(alpha or 1)
    return sep
end

local function makeSeparatorAroundButtons(parent, buttonsFrame, topOffset, bottomOffset, inset, topAlpha, bottomAlpha)
    local width = buttonsFrame:GetWidth() + (inset * 2)

    local topSep = parent:CreateTexture(nil, "ARTWORK")
    topSep:SetTexture(TEX .. "thin_separator.tga")
    topSep:SetSize(width, scaleY(UI.thinSeparatorHeight))
    topSep:SetPoint("BOTTOM", buttonsFrame, "TOP", 0, topOffset)
    topSep:SetAlpha(topAlpha or 1)

    local bottomSep = parent:CreateTexture(nil, "ARTWORK")
    bottomSep:SetTexture(TEX .. "thin_separator.tga")
    bottomSep:SetSize(width, scaleY(UI.thinSeparatorHeight))
    bottomSep:SetPoint("TOP", buttonsFrame, "BOTTOM", 0, bottomOffset)
    bottomSep:SetAlpha(bottomAlpha or 1)

    return topSep, bottomSep
end


local function getDifficultyModeLabel(mode)
    if mode == "normal" then
        return "Normal (3)"
    elseif mode == "heroic" then
        return "Heroic (5)"
    elseif mode == "mythic" then
        return "Mythic (5)"
    end
    return "Auto"
end

local function refreshDifficultyDropdown()
    if not win or not win.difficultyDropdown then
        return
    end

    local textLabel = getDifficultyModeLabel(manualDifficultyOverride)
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(win.difficultyDropdown, textLabel)
    elseif win.difficultyDropdown.Text then
        win.difficultyDropdown.Text:SetText(textLabel)
    end
end

local function setDifficultyMode(mode)
    manualDifficultyOverride = mode
    saveSettingsState()
    applyRaidDifficultyPatternMode()
    refreshDifficultyDropdown()
    notifyInfo("Difficulty mode set to " .. getDifficultyModeLabel(mode) .. ".")
end

local function buildDifficultyDropdown()
    local dd = CreateFrame("Frame", "LMG_DifficultyDropdown", win, "UIDropDownMenuTemplate")
    dd:ClearAllPoints()
    dd:SetPoint("TOP", win, "TOP", 0, UI.difficultyDropdownY)
    UIDropDownMenu_SetWidth(dd, UI.difficultyDropdownWidth)
    UIDropDownMenu_JustifyText(dd, "CENTER")

    UIDropDownMenu_Initialize(dd, function(self, level)
        local function addEntry(label, mode)
            local info = UIDropDownMenu_CreateInfo()
            info.text = label
            info.func = function()
                setDifficultyMode(mode)
            end
            info.checked = (manualDifficultyOverride == mode)
            UIDropDownMenu_AddButton(info, level)
        end

        addEntry("Auto", "auto")
        addEntry("Normal (3)", "normal")
        addEntry("Heroic (5)", "heroic")
        addEntry("Mythic (5)", "mythic")
    end)

    win.difficultyDropdown = registerContent(dd)
    refreshDifficultyDropdown()
end

local function buildMainFrame()
    win = CreateFrame("Frame", "LuraMemoryGameHelperWin", UIParent, "BackdropTemplate")
    win:SetSize(UI.width, UI.height)
    win:SetPoint(
        UI.windowAnchor,
        UI.windowRelativeTo,
        UI.windowRelativePoint,
        UI.windowOffsetX,
        UI.windowOffsetY
    )

    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetResizable(true)

    if win.SetResizeBounds then
        win:SetResizeBounds(UI.minWidth, UI.minHeight, UI.maxWidth, UI.maxHeight)
    end

    win:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        UI.windowAnchor = point or UI.windowAnchor
        UI.windowRelativePoint = relativePoint or UI.windowRelativePoint
        UI.windowOffsetX = x or UI.windowOffsetX
        UI.windowOffsetY = y or UI.windowOffsetY
        saveWindowState()
    end)

    win:SetFrameStrata("HIGH")
    win:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    win:SetBackdropColor(0.02, 0.02, 0.05, 0.72)
    win:SetBackdropBorderColor(0, 0, 0, 0)

    local innerGlow = win:CreateTexture(nil, "BACKGROUND")
    innerGlow:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    innerGlow:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -18)
    innerGlow:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -18, 18)
    innerGlow:SetVertexColor(0.10, 0.10, 0.18, 0.20)
    win.innerGlow = innerGlow

    buildCustomFrameBorder(win)

    local luraArt = win:CreateTexture(nil, "BACKGROUND")
    luraArt:SetTexture(TEX .. "Lura.tga")
    luraArt:SetBlendMode("BLEND")
    luraArt:SetAlpha(UI.luraArtAlpha or 0.85)
    win.luraArt = registerContent(luraArt)

    local resizeHandle = CreateFrame("Button", nil, win)
    resizeHandle:SetSize(20, 20)
    resizeHandle:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 2)
    resizeHandle:EnableMouse(true)
    resizeHandle:RegisterForDrag("LeftButton")
    resizeHandle:SetScript("OnDragStart", function()
        win:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()

        local w = math.floor(win:GetWidth() + 0.5)
        local h = math.floor(win:GetHeight() + 0.5)

        w = math.max(UI.minWidth, math.min(UI.maxWidth, w))
        h = math.max(UI.minHeight, math.min(UI.maxHeight, h))

        UI.width = w
        UI.height = h

        applyLayout()
        saveWindowState()
    end)
    win.resizeHandle = resizeHandle
end

local function buildTitleBar()
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", hideWindow)

    local minBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    minBtn:SetSize(22, 18)
    minBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -26, -6)
    minBtn:SetText("-")
    minBtn:SetScript("OnClick", toggleCollapsed)
    attachTooltip(minBtn, "ANCHOR_TOP", function()
        return isCollapsed and "Expand" or "Minimize"
    end)
    win.minBtn = minBtn

    local title = win:CreateTexture(nil, "OVERLAY")
    title:SetTexture(TEX .. "title.tga")
    title:SetSize(scaleX(UI.titleWidth), scaleY(UI.titleHeight))
    title:SetPoint("TOP", win, "TOP", 0, UI.titleOffsetY)
    win.titleTex = title

    local statusText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOP", title, "BOTTOM", 0, -6)
    statusText:SetTextColor(0.85, 0.85, 0.92, 0.90)
    statusText:SetText("Pattern Helper")
    win.statusText = registerContent(statusText)
end

local function buildArcDisplay()
    local topSep = registerContent(makeInnerSeparator(win, UI.topSeparatorTopOffset, 1))
    win.topInnerSeparator = topSep

    for visualIndex = 1, MAX do
        local btn = CreateFrame("Button", nil, win)
        btn:SetSize(scaleX(UI.arcIconSize), scaleY(UI.arcIconSize))
        btn:SetPoint("CENTER", win, "TOP", slots[visualIndex].x, slots[visualIndex].y)
        btn:Hide()

        local tex = btn:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        btn.tex = tex

        local placeholder = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        placeholder:SetPoint("CENTER", btn, "CENTER", 0, 0)
        placeholder:SetText("•")
        placeholder:SetAlpha(0.24)
        btn.placeholder = placeholder

        btn.stateIndex = MAX - visualIndex + 1
        btn:RegisterForDrag("LeftButton")

        btn:SetScript("OnEnter", function(self)
            if not isStateSlotActive(self.stateIndex) then
                return
            end

            if dragSourceStateIndex then
                dragHoverStateIndex = self.stateIndex
            end

            self:SetScale(1.06)
            if self.placeholder and not state[self.stateIndex] then
                self.placeholder:SetAlpha(0.40)
            end

            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local entry = state[self.stateIndex]
            if entry then
                GameTooltip:SetText("Click to clear. Drag to move/swap " .. entry.label, 1, 1, 1)
            else
                GameTooltip:SetText("Empty slot", 1, 1, 1)
            end
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            if dragHoverStateIndex == self.stateIndex then
                dragHoverStateIndex = nil
            end
            self:SetScale(1.0)
            if self.placeholder and not state[self.stateIndex] then
                self.placeholder:SetAlpha(0.24)
            end
            GameTooltip:Hide()
        end)

        btn:SetScript("OnDragStart", function(self)
            if not canEditPattern() or not isStateSlotActive(self.stateIndex) then
                return
            end

            if state[self.stateIndex] then
                dragSourceStateIndex = self.stateIndex
                dragHoverStateIndex = self.stateIndex
                self:SetAlpha(0.4)
                self:SetScale(1.08)
            end
        end)

        btn:SetScript("OnDragStop", function(self)
            if isPatternLocked then
                dragSourceStateIndex = nil
                dragHoverStateIndex = nil
                for _, b in ipairs(arcIcons) do
                    if b then
                        b:SetAlpha(1)
                        b:SetScale(1.0)
                    end
                end
                notifyLocked()
                return
            end

            local sourceIndex = dragSourceStateIndex
            local targetIndex = dragHoverStateIndex

            dragSourceStateIndex = nil
            dragHoverStateIndex = nil

            for _, b in ipairs(arcIcons) do
                if b then
                    b:SetAlpha(1)
                    b:SetScale(1.0)
                end
            end

            if not sourceIndex or not state[sourceIndex] then
                return
            end

            local focus = GetMouseFocus and GetMouseFocus() or nil
            local targetButton = getArcButtonFromFocusRegion(focus)
            if targetButton then
                targetIndex = targetButton.stateIndex
            end

            if not targetIndex or targetIndex == sourceIndex or not isStateSlotActive(targetIndex) then
                return
            end

            saveUndoState()
            clearAutoFilledSlots()

            if not state[sourceIndex] then
                return
            end

            if state[targetIndex] then
                state[sourceIndex], state[targetIndex] = state[targetIndex], state[sourceIndex]
                autoFilled[sourceIndex], autoFilled[targetIndex] = autoFilled[targetIndex], autoFilled[sourceIndex]
            else
                state[targetIndex] = state[sourceIndex]
                autoFilled[targetIndex] = autoFilled[sourceIndex]
                state[sourceIndex] = nil
                autoFilled[sourceIndex] = false
            end

            autoFillRemainingSlotIfNeeded()
            saveLastFullPatternIfComplete()
            redraw()
        end)

        btn:SetScript("OnClick", function(self)
            if not canEditPattern() or not isStateSlotActive(self.stateIndex) then
                return
            end

            if state[self.stateIndex] then
                saveUndoState()
                state[self.stateIndex] = nil
                autoFilled[self.stateIndex] = false
                redraw()
            end
        end)

        arcIcons[visualIndex] = registerContent(btn)
    end

    win.arcSeparators = {}

    local sepPoints = buildSeparatorPoints()

    for i = 1, 4 do
        local sep = registerContent(win:CreateTexture(nil, "OVERLAY"))
        sep:SetTexture(TEX .. "sym_separator.tga")
        sep:SetSize(scaleX(UI.separatorSize), scaleY(UI.separatorSize))
        sep:SetPoint("CENTER", win, "TOP", sepPoints[i].x, sepPoints[i].y)
        win.arcSeparators[i] = sep
    end

    local bossLabel = registerContent(win:CreateTexture(nil, "OVERLAY"))
    bossLabel:SetTexture(TEX .. "bosslabel.tga")
    bossLabel:SetSize(scaleX(UI.bossWidth), scaleY(UI.bossHeight))
    bossLabel:SetPoint("CENTER", win, "TOP", 0, UI.bossLabelY)
    win.bossTex = bossLabel
end

local function buildActionButtons()
    local totalWidth = (scaleX(UI.actionButtonWidth) * 2) + scaleX(UI.actionButtonGap)
    local buttonsFrame = CreateFrame("Frame", nil, win)
    buttonsFrame:SetSize(totalWidth, scaleY(UI.actionButtonHeight))
    buttonsFrame:SetPoint("BOTTOM", win, "BOTTOM", 0, UI.actionButtonY)
    registerContent(buttonsFrame)
    win.buttonsFrame = buttonsFrame

    local clearBtn = makeTexturedActionButton(
        buttonsFrame,
        scaleX(UI.actionButtonWidth),
        scaleY(UI.actionButtonHeight),
        "LEFT", buttonsFrame, "LEFT", 0, 0,
        TEX .. "btn_clear.tga",
        TEX .. "btn_clear_down.tga",
        "Clear the local pattern and announce [LMG] CLEAR in /say",
        function()
            if not playerCanBroadcast() then return end
            saveUndoState()
            doClear(true)
        end
    )
    win.clearBtn = clearBtn
    registerContent(clearBtn)

    local sendBtn = makeTexturedActionButton(
        buttonsFrame,
        scaleX(UI.actionButtonWidth),
        scaleY(UI.actionButtonHeight),
        "LEFT", clearBtn, "RIGHT", scaleX(UI.actionButtonGap), 0,
        TEX .. "btn_send.tga",
        TEX .. "btn_send_down.tga",
        "Send pattern in /say (visible to everyone nearby)",
        function()
            if not playerCanBroadcast() then return end
            sendPattern()
        end
    )
    win.sendBtn = sendBtn
    registerContent(sendBtn)

    local topSep, bottomSep = makeSeparatorAroundButtons(
        win,
        buttonsFrame,
        8,
        -8,
        0,
        1,
        1
    )
    win.buttonsTopSeparator = topSep
    win.buttonsBottomSeparator = bottomSep
    registerContent(topSep)
    registerContent(bottomSep)
end

local function buildRWCheckbox()
    local cb = CreateFrame("Button", "LuraMemoryGameHelperRWCheck", win)
    cb:SetSize(scaleX(UI.checkboxSize), scaleY(UI.checkboxSize))
    cb:SetPoint("CENTER", win, "BOTTOM", -68, UI.checkboxY)
    registerContent(cb)
    win.rwCheckbox = cb

    local uncheckedTex = cb:CreateTexture(nil, "BACKGROUND")
    uncheckedTex:SetTexture(TEX .. "checkbox_unchecked.tga")
    uncheckedTex:SetAllPoints()
    cb.uncheckedTex = uncheckedTex

    local checkedTex = cb:CreateTexture(nil, "ARTWORK")
    checkedTex:SetTexture(TEX .. "checkbox_checked.tga")
    checkedTex:SetAllPoints()
    cb.checkedTex = checkedTex
    cb.checkedTex:SetShown(alsoSendRW)

    cb:SetScript("OnEnter", function(self)
        self:SetScale(1.04)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Also send the pattern as a real raid warning message.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    cb:SetScript("OnLeave", function(self)
        self:SetScale(1.0)
        GameTooltip:Hide()
    end)

    cb:SetScript("OnClick", function(self)
        if not playerCanBroadcast() then return end
        alsoSendRW = not alsoSendRW
        self.checkedTex:SetShown(alsoSendRW)
        saveSettingsState()
    end)

    cb.label = win:CreateTexture(nil, "OVERLAY")
    cb.label:SetTexture(TEX .. "checkbox_text.tga")
    cb.label:SetSize(scaleX(UI.checkboxLabelWidth), scaleY(UI.checkboxLabelHeight))
    cb.label:SetPoint("LEFT", cb, "RIGHT", scaleX(UI.checkboxLabelOffsetX), 0)
    registerContent(cb.label)

end

local function buildSymbolButtons()
    local bSize = scaleX(UI.symbolButtonSize)
    local gap = scaleX(UI.symbolButtonGap)
    local rowWidth = #SYMS * bSize + (#SYMS - 1) * gap
    local x0 = -(rowWidth / 2) + bSize / 2

    win.symbolButtons = {}

    for i, sym in ipairs(SYMS) do
        local btn = CreateFrame("Button", nil, win)
        btn:SetSize(bSize, bSize)
        btn:SetPoint(
            "BOTTOMLEFT",
            win,
            "BOTTOMLEFT",
            (UI.width / 2 + x0 + (i - 1) * (bSize + gap)) - bSize / 2,
            UI.symbolButtonY
        )

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(sym.tex)

        btn:SetAlpha(0.96)

        btn:SetScript("OnEnter", function(self)
            self:SetScale(1.08)
            self:SetAlpha(1.0)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(sym.label, 1, 1, 1)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetScale(1.0)
            self:SetAlpha(0.96)
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            addSymbol(sym)
        end)

        win.symbolButtons[i] = btn
        registerContent(btn)
    end
end

function applyLayout()
    if not win then return end

    recomputeSlots()

    win:SetSize(UI.width, isCollapsed and UI.collapsedHeight or UI.height)

    if win.customBorder then
        local inset = scaleX(UI.frameInset)
        local edge = scaleX(UI.frameEdge)
        local corner = scaleX(UI.cornerSize)

        win.customBorder.tl:SetSize(corner, corner)
        win.customBorder.tl:ClearAllPoints()
        win.customBorder.tl:SetPoint("TOPLEFT", win, "TOPLEFT", inset, -inset)

        win.customBorder.tr:SetSize(corner, corner)
        win.customBorder.tr:ClearAllPoints()
        win.customBorder.tr:SetPoint("TOPRIGHT", win, "TOPRIGHT", -inset, -inset)

        win.customBorder.bl:SetSize(corner, corner)
        win.customBorder.bl:ClearAllPoints()
        win.customBorder.bl:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", inset, inset)

        win.customBorder.br:SetSize(corner, corner)
        win.customBorder.br:ClearAllPoints()
        win.customBorder.br:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -inset, inset)

        win.customBorder.top:ClearAllPoints()
        win.customBorder.top:SetPoint("TOPLEFT", win.customBorder.tl, "TOPRIGHT", -1, 0)
        win.customBorder.top:SetPoint("TOPRIGHT", win.customBorder.tr, "TOPLEFT", 1, 0)
        win.customBorder.top:SetHeight(edge)

        win.customBorder.bottom:ClearAllPoints()
        win.customBorder.bottom:SetPoint("BOTTOMLEFT", win.customBorder.bl, "BOTTOMRIGHT", -1, 0)
        win.customBorder.bottom:SetPoint("BOTTOMRIGHT", win.customBorder.br, "BOTTOMLEFT", 1, 0)
        win.customBorder.bottom:SetHeight(edge)

        win.customBorder.left:ClearAllPoints()
        win.customBorder.left:SetPoint("TOPLEFT", win.customBorder.tl, "BOTTOMLEFT", 0, 1)
        win.customBorder.left:SetPoint("BOTTOMLEFT", win.customBorder.bl, "TOPLEFT", 0, -1)
        win.customBorder.left:SetWidth(edge)

        win.customBorder.right:ClearAllPoints()
        win.customBorder.right:SetPoint("TOPRIGHT", win.customBorder.tr, "BOTTOMRIGHT", 0, 1)
        win.customBorder.right:SetPoint("BOTTOMRIGHT", win.customBorder.br, "TOPRIGHT", 0, -1)
        win.customBorder.right:SetWidth(edge)
    end

    if win.titleTex then
        win.titleTex:SetSize(scaleX(UI.titleWidth), scaleY(UI.titleHeight))
        win.titleTex:ClearAllPoints()
        win.titleTex:SetPoint("TOP", win, "TOP", 0, UI.titleOffsetY)
    end

    if win.statusText then
        win.statusText:ClearAllPoints()
        win.statusText:SetPoint("TOP", win.titleTex, "BOTTOM", 0, -6)
    end

    if win.topInnerSeparator then
        win.topInnerSeparator:SetSize(UI.width - (scaleX(UI.outerPad) * 2), scaleY(UI.thinSeparatorHeight))
        win.topInnerSeparator:ClearAllPoints()
        win.topInnerSeparator:SetPoint("TOP", win, "TOP", 0, UI.topSeparatorTopOffset)
    end

    if win.bossTex then
        win.bossTex:SetSize(scaleX(UI.bossWidth), scaleY(UI.bossHeight))
        win.bossTex:ClearAllPoints()
        win.bossTex:SetPoint("CENTER", win, "TOP", 0, UI.bossLabelY)
    end

    if win.luraArt then
        win.luraArt:SetSize(scaleX(UI.luraArtWidth), scaleY(UI.luraArtHeight))
        win.luraArt:ClearAllPoints()
        win.luraArt:SetPoint("CENTER", win, "TOP", 0, UI.luraArtY)
        win.luraArt:SetAlpha(UI.luraArtAlpha or 0.85)
    end

    for i = 1, MAX do
        local btn = arcIcons[i]
        if btn then
            local stateIndex = MAX - i + 1
            btn:SetSize(scaleX(UI.arcIconSize), scaleY(UI.arcIconSize))
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", win, "TOP", slots[i].x, slots[i].y)

            if isCollapsed or not isStateSlotActive(stateIndex) then
                btn:Hide()
                if btn.placeholder then
                    btn.placeholder:Hide()
                end
            else
                btn:Show()
                if btn.placeholder and not state[stateIndex] then
                    btn.placeholder:Show()
                end
            end
        end
    end

    if win.arcSeparators then
        local sepPoints = buildSeparatorPoints()

        for i, sep in ipairs(win.arcSeparators) do
            sep:SetSize(scaleX(UI.separatorSize), scaleY(UI.separatorSize))
            sep:ClearAllPoints()
            sep:SetPoint("CENTER", win, "TOP", sepPoints[i].x, sepPoints[i].y)
            if isCollapsed or not isSeparatorActive(i) then
                sep:Hide()
            else
                sep:Show()
            end
        end
    end

    if win.buttonsFrame then
        local totalWidth = (scaleX(UI.actionButtonWidth) * 2) + scaleX(UI.actionButtonGap)
        win.buttonsFrame:SetSize(totalWidth, scaleY(UI.actionButtonHeight))
        win.buttonsFrame:ClearAllPoints()
        win.buttonsFrame:SetPoint("BOTTOM", win, "BOTTOM", 0, UI.actionButtonY)
    end

    if win.clearBtn then
        win.clearBtn:SetSize(scaleX(UI.actionButtonWidth), scaleY(UI.actionButtonHeight))
        win.clearBtn:ClearAllPoints()
        win.clearBtn:SetPoint("LEFT", win.buttonsFrame, "LEFT", 0, 0)
    end

    if win.sendBtn then
        win.sendBtn:SetSize(scaleX(UI.actionButtonWidth), scaleY(UI.actionButtonHeight))
        win.sendBtn:ClearAllPoints()
        win.sendBtn:SetPoint("LEFT", win.clearBtn, "RIGHT", scaleX(UI.actionButtonGap), 0)
    end

    if win.buttonsTopSeparator then
        win.buttonsTopSeparator:SetSize(win.buttonsFrame:GetWidth(), scaleY(UI.thinSeparatorHeight))
        win.buttonsTopSeparator:ClearAllPoints()
        win.buttonsTopSeparator:SetPoint("BOTTOM", win.buttonsFrame, "TOP", 0, 8)
    end

    if win.buttonsBottomSeparator then
        win.buttonsBottomSeparator:SetSize(win.buttonsFrame:GetWidth(), scaleY(UI.thinSeparatorHeight))
        win.buttonsBottomSeparator:ClearAllPoints()
        win.buttonsBottomSeparator:SetPoint("TOP", win.buttonsFrame, "BOTTOM", 0, -8)
    end

    if win.rwCheckbox then
        win.rwCheckbox:SetSize(scaleX(UI.checkboxSize), scaleY(UI.checkboxSize))
        win.rwCheckbox:ClearAllPoints()
        win.rwCheckbox:SetPoint("CENTER", win, "BOTTOM", -68, UI.checkboxY)
    end

    if win.rwCheckbox and win.rwCheckbox.label then
        win.rwCheckbox.label:SetSize(scaleX(UI.checkboxLabelWidth), scaleY(UI.checkboxLabelHeight))
        win.rwCheckbox.label:ClearAllPoints()
        win.rwCheckbox.label:SetPoint("LEFT", win.rwCheckbox, "RIGHT", scaleX(UI.checkboxLabelOffsetX), 0)
    end

    if win.difficultyDropdown then
        win.difficultyDropdown:ClearAllPoints()
        win.difficultyDropdown:SetPoint("TOP", win, "TOP", 0, UI.difficultyDropdownY)
        UIDropDownMenu_SetWidth(win.difficultyDropdown, UI.difficultyDropdownWidth)
        refreshDifficultyDropdown()
    end

    if win.symbolButtons then
        local bSize = scaleX(UI.symbolButtonSize)
        local gap = scaleX(UI.symbolButtonGap)
        local rowWidth = #SYMS * bSize + (#SYMS - 1) * gap
        local x0 = -(rowWidth / 2) + bSize / 2

        for i, btn in ipairs(win.symbolButtons) do
            btn:SetSize(bSize, bSize)
            btn:ClearAllPoints()
            btn:SetPoint(
                "BOTTOMLEFT",
                win,
                "BOTTOMLEFT",
                (UI.width / 2 + x0 + (i - 1) * (bSize + gap)) - bSize / 2,
                UI.symbolButtonY
            )
        end
    end
end

local function buildWindow()
    if win then return end
    recomputeSlots()
    buildMainFrame()
    buildTitleBar()
    buildArcDisplay()
    buildActionButtons()
    buildRWCheckbox()
    buildDifficultyDropdown()
    buildSymbolButtons()
    applyLayout()
    updateBroadcastControls()
    if win.rwCheckbox and win.rwCheckbox.checkedTex then
        win.rwCheckbox.checkedTex:SetShown(alsoSendRW)
    end
    if isCollapsed then
        setCollapsed(true)
    end
end

local function ensureWindowBuilt()
    if not win then
        buildWindow()
    end
end

applyRaidDifficultyPatternMode = function()
    local newSlotCount = getPatternSlotCountForCurrentDifficulty()
    if newSlotCount == currentPatternSlotCount then
        if win then
            redraw()
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
        redraw()
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
            redraw()
            refreshDifficultyDropdown()
        end
        if win and autoInitialized then
            hideWindow()
        end
    end
end

local function parsePayload(msg)
    local payload = msg and msg:match("^%[LMG%]%s*(.+)$")
    if not payload then
        return nil
    end

    payload = trim(payload)

    if payload == "CLEAR" then
        return "clear"
    end

    local patternText = payload:match("^PATTERN:%s*(.+)$")
    if patternText then
        return "pattern", patternText
    end

    return nil
end

local function handleSayMessage(msg, author)
    -- Ignore our own addon-formatted /say messages to avoid local state races.
    local playerName = UnitName("player")
    if author and playerName and author:match("^" .. playerName) then
        return
    end

    local kind, value = parsePayload(msg)

    if kind == "clear" then
        doClear(false)
        return
    end

    if kind == "pattern" then
        local decoded = textToPattern(value)
        if #decoded > 0 then
            local lockedBeforeSync = isPatternLocked
            setStateFromDecoded(decoded)
            autoFillRemainingSlotIfNeeded()
            saveLastFullPatternIfComplete()
            isPatternLocked = lockedBeforeSync
            if win and not win:IsShown() then
                win:Show()
            end
            redraw()
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("CHAT_MSG_SAY")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")

ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            initializeDB()
            currentPatternSlotCount = getPatternSlotCountForCurrentDifficulty()
            print("|cff8cd1ffLura Memory Game Helper|r loaded! Type |cffffd700/lmg|r to open.")
            showChangelogIfNeeded()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if win then
            updateBroadcastControls()
        end
        autoHandleTargetRaid()
        return
    end

    if event == "CHAT_MSG_SAY" then
        local msg, author = ...
        handleSayMessage(msg, author)
    end
end)

SLASH_LURAMEMORYGAMEHELPER1 = "/lmg"
SLASH_LURAMEMORYGAMEHELPER2 = "/memorygame"
SLASH_LURAMEMORYGAMEHELPER3 = "/luramemory"

local commands = {
    clear = function()
        if not playerCanBroadcast() then return end
        saveUndoState()
        doClear(true)
    end,
    say = function()
        if not playerCanBroadcast() then return end
        sendPattern()
    end,
    show = function()
        showWindow(true)
    end,
    hide = function()
        hideWindow()
    end,
    test = function()
        testMode = not testMode
        notifyInfo("Test Mode: " .. (testMode and "ENABLED" or "DISABLED"))
        updateBroadcastControls()
    end,
    undo = function()
        if restoreUndoState() then
            notifyInfo("Undo applied.")
        else
            notifyInfo("Nothing to undo.")
        end
    end,
    redo = function()
        if restoreRedoState() then
            notifyInfo("Redo applied.")
        else
            notifyInfo("Nothing to redo.")
        end
    end,
    lock = function()
        isPatternLocked = true
        notifyInfo("Pattern locked.")
        redraw()
    end,
    unlock = function()
        isPatternLocked = false
        notifyInfo("Pattern unlocked.")
        redraw()
    end,
    locksend = function()
        notifyInfo("Lock-after-send is currently " .. (LOCK_AFTER_SEND and "ON" or "OFF") .. ". Use /lmg locksend on|off or /lmg sendlock on|off.")
    end,
    sendlock = function()
        notifyInfo("Lock-after-send is currently " .. (LOCK_AFTER_SEND and "ON" or "OFF") .. ". Use /lmg locksend on|off or /lmg sendlock on|off.")
    end,
    changelog = function()
        buildChangelogFrame()
        changelogFrame.dismissCheck.checkedTex:SetShown(false)
        changelogFrame:Show()
    end,
    restorefull = function()
        if restoreLastFullPattern() then
            notifyInfo("Restored last full pattern.")
        else
            notifyInfo("No saved full pattern to restore.")
        end
    end,
}

SlashCmdList["LURAMEMORYGAMEHELPER"] = function(msg)
    local normalized = normalize(msg)
    local cmd, arg = normalized:match("^(%S+)%s*(.-)$")
    cmd = cmd or ""
    arg = arg or ""

    ensureWindowBuilt()
    updateBroadcastControls()

    if normalized == "" then
        toggleWindow()
        return
    end

    local fn = commands[normalized] or commands[cmd]

    if cmd == "locksend" and arg ~= "" then
        if arg == "on" then
            LOCK_AFTER_SEND = true
            saveSettingsState()
            notifyInfo("Lock-after-send enabled.")
            return
        elseif arg == "off" then
            LOCK_AFTER_SEND = false
            isPatternLocked = false
            saveSettingsState()
            notifyInfo("Lock-after-send disabled.")
            redraw()
            return
        end
elseif cmd == "autofill" and arg ~= "" then
        if arg == "on" then
            AUTO_FILL_SLOT5 = true
            saveSettingsState()
            notifyInfo("Autofill enabled.")
            return
        elseif arg == "off" then
            AUTO_FILL_SLOT5 = false
            saveSettingsState()
            notifyInfo("Autofill disabled.")
            return
        end
    elseif cmd == "duplicates" and arg ~= "" then
        if arg == "on" then
            PREVENT_DUPLICATES = true
            saveSettingsState()
            notifyInfo("Duplicate prevention enabled.")
            return
        elseif arg == "off" then
            PREVENT_DUPLICATES = false
            saveSettingsState()
            notifyInfo("Duplicate prevention disabled.")
            return
        end
    end

    if fn then
        fn()
    else
        toggleWindow()
    end
end
