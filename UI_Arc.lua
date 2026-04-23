local ADDON_NAME, LMG = ...

local function makeInnerSeparator(parent, yOffsetFromTop, alpha)
    local UI = LMG.UI
    local TEX = LMG.TexPath
    local scaleX = LMG.ScaleX
    local scaleY = LMG.ScaleY
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(TEX .. "thin_separator.tga")
    sep:SetSize(UI.width - (scaleX(UI.outerPad) * 2), scaleY(UI.thinSeparatorHeight))
    sep:SetPoint("TOP", parent, "TOP", 0, yOffsetFromTop)
    sep:SetAlpha(alpha or 1)
    return sep
end

local function buildArcDisplay()
    local win = LMG.GetWindow and LMG.GetWindow()
    local UI = LMG.UI
    local TEX = LMG.TexPath
    local scaleX = LMG.ScaleX
    local scaleY = LMG.ScaleY
    local MAX = LMG.GetMaxSymbols and LMG.GetMaxSymbols() or 5
    local slots = LMG.GetSlots and LMG.GetSlots()
    local arcIcons = LMG.GetArcIcons and LMG.GetArcIcons()
    local state = LMG.GetState and LMG.GetState()
    local autoFilled = LMG.GetAutoFilled and LMG.GetAutoFilled()
    if not win then return end

    local topSep = LMG.RegisterContent and LMG.RegisterContent(makeInnerSeparator(win, UI.topSeparatorTopOffset, 1)) or makeInnerSeparator(win, UI.topSeparatorTopOffset, 1)
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
            if not (LMG.IsStateSlotActive and LMG.IsStateSlotActive(self.stateIndex)) then
                return
            end

            if LMG.GetDragSourceStateIndex and LMG.GetDragSourceStateIndex() then
                if LMG.SetDragHoverStateIndex then LMG.SetDragHoverStateIndex(self.stateIndex) end
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
            if LMG.GetDragHoverStateIndex and LMG.GetDragHoverStateIndex() == self.stateIndex then
                if LMG.SetDragHoverStateIndex then LMG.SetDragHoverStateIndex(nil) end
            end
            self:SetScale(1.0)
            if self.placeholder and not state[self.stateIndex] then
                self.placeholder:SetAlpha(0.24)
            end
            GameTooltip:Hide()
        end)

        btn:SetScript("OnDragStart", function(self)
            if not (LMG.CanEditPattern and LMG.CanEditPattern()) or not (LMG.IsStateSlotActive and LMG.IsStateSlotActive(self.stateIndex)) then
                return
            end

            if state[self.stateIndex] then
                if LMG.SetDragSourceStateIndex then LMG.SetDragSourceStateIndex(self.stateIndex) end
                if LMG.SetDragHoverStateIndex then LMG.SetDragHoverStateIndex(self.stateIndex) end
                self:SetAlpha(0.4)
                self:SetScale(1.08)
            end
        end)

        btn:SetScript("OnDragStop", function(self)
            if LMG.GetPatternLocked and LMG.GetPatternLocked() then
                if LMG.SetDragSourceStateIndex then LMG.SetDragSourceStateIndex(nil) end
                if LMG.SetDragHoverStateIndex then LMG.SetDragHoverStateIndex(nil) end
                for _, b in ipairs(arcIcons) do
                    if b then
                        b:SetAlpha(1)
                        b:SetScale(1.0)
                    end
                end
                if LMG.NotifyLocked then LMG.NotifyLocked() end
                return
            end

            local sourceIndex = LMG.GetDragSourceStateIndex and LMG.GetDragSourceStateIndex()
            local targetIndex = LMG.GetDragHoverStateIndex and LMG.GetDragHoverStateIndex()

            if LMG.SetDragSourceStateIndex then LMG.SetDragSourceStateIndex(nil) end
            if LMG.SetDragHoverStateIndex then LMG.SetDragHoverStateIndex(nil) end

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
            local targetButton = LMG.GetArcButtonFromFocusRegion and LMG.GetArcButtonFromFocusRegion(focus)
            if targetButton then
                targetIndex = targetButton.stateIndex
            end

            if not targetIndex or targetIndex == sourceIndex or not (LMG.IsStateSlotActive and LMG.IsStateSlotActive(targetIndex)) then
                return
            end

            if LMG.SaveUndoState then LMG.SaveUndoState() end
            if LMG.ClearAutoFilledSlots then LMG.ClearAutoFilledSlots() end

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

            if LMG.AutoFillRemainingSlotIfNeeded then LMG.AutoFillRemainingSlotIfNeeded() end
            if LMG.SaveLastFullPatternIfComplete then LMG.SaveLastFullPatternIfComplete() end
            if LMG.Redraw then LMG.Redraw() end
        end)

        btn:SetScript("OnClick", function(self)
            if not (LMG.CanEditPattern and LMG.CanEditPattern()) or not (LMG.IsStateSlotActive and LMG.IsStateSlotActive(self.stateIndex)) then
                return
            end

            if state[self.stateIndex] then
                if LMG.SaveUndoState then LMG.SaveUndoState() end
                state[self.stateIndex] = nil
                autoFilled[self.stateIndex] = false
                if LMG.Redraw then LMG.Redraw() end
            end
        end)

        arcIcons[visualIndex] = LMG.RegisterContent and LMG.RegisterContent(btn) or btn
    end

    win.arcSeparators = {}
    local sepPoints = LMG.BuildSeparatorPoints and LMG.BuildSeparatorPoints() or {}

    for i = 1, 4 do
        local sep = LMG.RegisterContent and LMG.RegisterContent(win:CreateTexture(nil, "OVERLAY")) or win:CreateTexture(nil, "OVERLAY")
        sep:SetTexture(TEX .. "sym_separator.tga")
        sep:SetSize(scaleX(UI.separatorSize), scaleY(UI.separatorSize))
        sep:SetPoint("CENTER", win, "TOP", sepPoints[i].x, sepPoints[i].y)
        win.arcSeparators[i] = sep
    end

    local bossLabel = LMG.RegisterContent and LMG.RegisterContent(win:CreateTexture(nil, "OVERLAY")) or win:CreateTexture(nil, "OVERLAY")
    bossLabel:SetTexture(TEX .. "bosslabel.tga")
    bossLabel:SetSize(scaleX(UI.bossWidth), scaleY(UI.bossHeight))
    bossLabel:SetPoint("CENTER", win, "TOP", 0, UI.bossLabelY)
    win.bossTex = bossLabel
end

local function redraw()
    local MAX = LMG.GetMaxSymbols and LMG.GetMaxSymbols() or 5
    local arcIcons = LMG.GetArcIcons and LMG.GetArcIcons()
    local state = LMG.GetState and LMG.GetState()
    local autoFilled = LMG.GetAutoFilled and LMG.GetAutoFilled()
    local win = LMG.GetWindow and LMG.GetWindow()
    local isCollapsed = LMG.GetCollapsedState and LMG.GetCollapsedState() or false

    for visualIndex = 1, MAX do
        local btn = arcIcons[visualIndex]
        local stateIndex = MAX - visualIndex + 1

        if btn then
            btn.tex:SetTexture(nil)
            btn:SetAlpha(1)

            if isCollapsed or not (LMG.IsStateSlotActive and LMG.IsStateSlotActive(stateIndex)) then
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

    for _, stateIndex in ipairs(LMG.GetActiveSlotIndices and LMG.GetActiveSlotIndices() or {}) do
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
            if LMG.IsSeparatorActive and LMG.IsSeparatorActive(i) then
                sep:Show()
            else
                sep:Hide()
            end
        end
    end

    if win and win.statusText then
        if LMG.GetPatternLocked and LMG.GetPatternLocked() then
            win.statusText:SetText("Pattern Helper  •  Locked")
            win.statusText:SetTextColor(1.0, 0.35, 0.35, 0.95)
        else
            win.statusText:SetText("Pattern Helper")
            win.statusText:SetTextColor(0.85, 0.85, 0.92, 0.90)
        end
    end
end

LMG.BuildArcDisplay = buildArcDisplay
LMG.Redraw = redraw
