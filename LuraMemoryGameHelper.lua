-- ============================================================
-- Lura Memory Game Helper
-- Version: 1.0.7
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
--   - Drag an arc icon onto another arc slot to swap/move it.
--   - /lmg undo restores the previous pattern state.
--   - /lmg unlock unlocks the pattern if lock-after-send is enabled.
-- ============================================================

local ADDON_NAME = "LuraMemoryGameHelper"
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

    bossLabelY = -108,
    bossWidth = 330,
    bossHeight = 58,

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

    symbolButtonSize = 54,
    symbolButtonGap = 8,
    symbolButtonY = 28,

    thinSeparatorHeight = 16,
}

local BASE_UI = {
    width = 395,
    height = 535,

    titleWidth = 300,
    titleHeight = 30,

    bossWidth = 330,
    bossHeight = 58,

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
local SHOW_AUTO_FILLED_DIMMED = true

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
local lastUndoState = nil
local isPatternLocked = false
local dragSourceIndex = nil

local win
local arcIcons = {}
local contentRegions = {}
local isCollapsed = false
local alsoSendRW = false
local testMode = false
local slots = {}

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
local function copyArray(src)
    local out = {}
    for i = 1, MAX do
        out[i] = src[i]
    end
    return out
end

local function pushUndoState()
    lastUndoState = {
        state = copyArray(state),
        autoFilled = copyArray(autoFilled),
        alsoSendRW = alsoSendRW,
        isPatternLocked = isPatternLocked,
    }
end

local function restoreUndoState()
    if not lastUndoState then
        return false
    end

    for i = 1, MAX do
        state[i] = lastUndoState.state[i]
        autoFilled[i] = lastUndoState.autoFilled[i]
    end
    alsoSendRW = lastUndoState.alsoSendRW
    isPatternLocked = lastUndoState.isPatternLocked
    lastUndoState = nil
    return true
end

local function clearStateTable()
    for i = 1, MAX do
        state[i] = nil
        autoFilled[i] = false
    end
end

local function clearState()
    clearStateTable()
    isPatternLocked = false
end

local function setStateFromDecoded(decoded)
    clearStateTable()
    local writeIndex = 1

    for i = 1, #decoded do
        if decoded[i] then
            state[writeIndex] = decoded[i]
            autoFilled[writeIndex] = false
            writeIndex = writeIndex + 1
            if writeIndex > MAX then
                break
            end
        end
    end
    isPatternLocked = false
end

local function stateHasAnyEntries()
    for i = 1, MAX do
        if state[i] then
            return true
        end
    end
    return false
end

local function stateContainsSymbol(sym)
    for i = 1, MAX do
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

local function clearAutoFilledSlot5IfPresent()
    if autoFilled[5] then
        state[5] = nil
        autoFilled[5] = false
    end
end

local function autoFillSlot5IfNeeded()
    clearAutoFilledSlot5IfPresent()

    if not AUTO_FILL_SLOT5 then
        return
    end

    if state[5] then
        return
    end

    for i = 1, 4 do
        if not state[i] then
            return
        end
    end

    local remaining = getRemainingUnusedSymbol()
    if remaining then
        state[5] = remaining
        autoFilled[5] = true
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
local function redraw()
    for visualIndex = 1, MAX do
        local btn = arcIcons[visualIndex]
        if btn then
            btn.tex:SetTexture(nil)
            btn:SetAlpha(1)
            btn:Hide()
        end
    end

    if isCollapsed then
        return
    end

    for stateIndex = 1, MAX do
        local entry = state[stateIndex]
        if entry then
            local visualIndex = MAX - stateIndex + 1
            local btn = arcIcons[visualIndex]
            if btn then
                btn.tex:SetTexture(entry.tex)
                if SHOW_AUTO_FILLED_DIMMED and autoFilled[stateIndex] then
                    btn:SetAlpha(0.72)
                else
                    btn:SetAlpha(1)
                end
                btn:Show()
            end
        end
    end

end

local function patternToText(pattern)
    local parts = {}
    for i = 1, MAX do
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
    for i = 1, MAX do
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
end

local function toggleCollapsed()
    setCollapsed(not isCollapsed)
end

-- ============================================================
-- Pattern actions
-- ============================================================
local function doClear(sendChat)
    if isPatternLocked and LOCK_AFTER_SEND then
        isPatternLocked = false
    end
    pushUndoState()
    clearState()
    redraw()
    if sendChat then
        SendChatMessage(SAY_PREFIX .. " CLEAR", "SAY")
    end
end

local function sendPattern()
    if not stateHasAnyEntries() then return end
    SendChatMessage(SAY_PREFIX .. " PATTERN: " .. currentPatternText(), "SAY")
    maybeSendRW()
    if LOCK_AFTER_SEND then
        isPatternLocked = true
    end
    redraw()
end

local function addSymbol(sym)
    if isPatternLocked then
        print("|cffff8080LMG:|r Pattern is locked. Clear or /lmg unlock first.")
        return
    end

    if PREVENT_DUPLICATES and stateContainsSymbol(sym) then
        print("|cffff8080LMG:|r " .. sym.label .. " is already used.")
        return
    end

    for i = 1, MAX do
        if not state[i] then
            pushUndoState()
            state[i] = sym
            autoFilled[i] = false
            autoFillSlot5IfNeeded()
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

    btn:SetScript("OnLeave", function(self)
        if self.bg then
            self.bg:SetTexture(upTex)
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
    end)

    win:SetScript("OnMouseUp", function()
        dragSourceIndex = nil
    end)

    win:SetFrameStrata("HIGH")
    win:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    win:SetBackdropColor(0.03, 0.03, 0.08, 0.50)
    win:SetBackdropBorderColor(0, 0, 0, 0)

    buildCustomFrameBorder(win)

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
end

local function buildArcDisplay()
    local topSep = registerContent(makeInnerSeparator(win, UI.topSeparatorTopOffset, 1))
    win.topInnerSeparator = topSep

    for visualIndex = 1, MAX do
        local btn = CreateFrame("Button", nil, win)
        btn:SetSize(scaleX(UI.arcIconSize), scaleY(UI.arcIconSize))
        btn:SetPoint("CENTER", win, "TOP", slots[visualIndex].x, slots[visualIndex].y)
        btn:Hide()
        btn:RegisterForClicks("LeftButtonUp")
        btn:EnableMouse(true)

        local tex = btn:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        btn.tex = tex

        btn.stateIndex = MAX - visualIndex + 1

        btn:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            if isPatternLocked then return end
            if state[self.stateIndex] then
                dragSourceIndex = self.stateIndex
            else
                dragSourceIndex = nil
            end
        end)

        btn:SetScript("OnMouseUp", function(self, button)
            if button ~= "LeftButton" then return end

            local sourceIndex = dragSourceIndex
            dragSourceIndex = nil

            if isPatternLocked then
                return
            end

            if not sourceIndex then
                return
            end

            local targetIndex = self.stateIndex

            if sourceIndex == targetIndex then
                if state[targetIndex] then
                    pushUndoState()
                    state[targetIndex] = nil
                    autoFilled[targetIndex] = false
                    autoFillSlot5IfNeeded()
                    redraw()
                end
                return
            end

            if not state[sourceIndex] then
                return
            end

            pushUndoState()
            state[sourceIndex], state[targetIndex] = state[targetIndex], state[sourceIndex]
            autoFilled[sourceIndex], autoFilled[targetIndex] = autoFilled[targetIndex], autoFilled[sourceIndex]
            autoFillSlot5IfNeeded()
            redraw()
        end)

        attachTooltip(btn, "ANCHOR_TOP", function()
            local entry = state[btn.stateIndex]
            if not entry then
                return isPatternLocked and "Empty slot (pattern locked)" or "Empty slot"
            end

            local suffix = autoFilled[btn.stateIndex] and " (auto-filled)" or ""
            if isPatternLocked then
                return entry.label .. suffix .. "\nPattern locked"
            end
            return entry.label .. suffix .. "\nClick to clear\nDrag to move / swap"
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

    cb:SetScript("OnClick", function(self)
        if not playerCanBroadcast() then return end
        alsoSendRW = not alsoSendRW
        self.checkedTex:SetShown(alsoSendRW)
    end)

    cb.label = win:CreateTexture(nil, "OVERLAY")
    cb.label:SetTexture(TEX .. "checkbox_text.tga")
    cb.label:SetSize(scaleX(UI.checkboxLabelWidth), scaleY(UI.checkboxLabelHeight))
    cb.label:SetPoint("LEFT", cb, "RIGHT", scaleX(UI.checkboxLabelOffsetX), 0)
    registerContent(cb.label)

    attachTooltip(cb, "ANCHOR_TOP", "Also send the pattern as a real raid warning message.")
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

        btn:SetScript("OnEnter", function(self)
            self:SetScale(1.05)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(sym.label, 1, 1, 1)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetScale(1.0)
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

    for i = 1, MAX do
        local btn = arcIcons[i]
        if btn then
            btn:SetSize(scaleX(UI.arcIconSize), scaleY(UI.arcIconSize))
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", win, "TOP", slots[i].x, slots[i].y)
        end
    end

    if win.arcSeparators then
        local sepPoints = buildSeparatorPoints()

        for i, sep in ipairs(win.arcSeparators) do
            sep:SetSize(scaleX(UI.separatorSize), scaleY(UI.separatorSize))
            sep:ClearAllPoints()
            sep:SetPoint("CENTER", win, "TOP", sepPoints[i].x, sepPoints[i].y)
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
    buildSymbolButtons()
    applyLayout()
    updateBroadcastControls()
end

local function ensureWindowBuilt()
    if not win then
        buildWindow()
    end
end

local function autoHandleTargetRaid()
    if inTargetRaid() then
        ensureWindowBuilt()
        if not win:IsShown() then
            showWindow(true)
        end
        autoInitialized = true
    else
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

local function handleSayMessage(msg)
    local kind, value = parsePayload(msg)

    if kind == "clear" then
        doClear(false)
        return
    end

    if kind == "pattern" then
        local decoded = textToPattern(value)
        if #decoded > 0 then
            setStateFromDecoded(decoded)
            autoFillSlot5IfNeeded()
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
            print("|cff8cd1ffLura Memory Game Helper|r loaded! Type |cffffd700/lmg|r to open.")
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
        local msg = ...
        handleSayMessage(msg)
    end
end)

SLASH_LURAMEMORYGAMEHELPER1 = "/lmg"
SLASH_LURAMEMORYGAMEHELPER2 = "/memorygame"
SLASH_LURAMEMORYGAMEHELPER3 = "/luramemory"

local commands = {
    clear = function()
        if not playerCanBroadcast() then return end
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
    undo = function()
        if restoreUndoState() then
            redraw()
            print("|cff8cd1ffLMG:|r Restored previous pattern state.")
        else
            print("|cffff8080LMG:|r Nothing to undo.")
        end
    end,
    unlock = function()
        isPatternLocked = false
        redraw()
        print("|cff8cd1ffLMG:|r Pattern unlocked.")
    end,
    test = function()
        testMode = not testMode
        print("|cff8cd1ffLMG Test Mode:|r " .. (testMode and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
        updateBroadcastControls()
    end,
}

SlashCmdList["LURAMEMORYGAMEHELPER"] = function(msg)
    local cmd = normalize(msg)

    ensureWindowBuilt()
    updateBroadcastControls()

    local fn = commands[cmd]

    if fn then
        fn()
    else
        toggleWindow()
    end
end
