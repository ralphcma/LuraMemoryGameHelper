local ADDON_NAME, LMG = ...

local function applyLayout()
    local win = LMG.GetWindow and LMG.GetWindow()
    local UI = LMG.UI
    local scaleX = LMG.ScaleX
    local scaleY = LMG.ScaleY
    local isCollapsed = LMG.GetCollapsedState and LMG.GetCollapsedState() or false
    local MAX = LMG.GetMaxSymbols and LMG.GetMaxSymbols() or 5
    local arcIcons = LMG.GetArcIcons and LMG.GetArcIcons() or {}
    local slots = LMG.GetSlots and LMG.GetSlots() or {}
    local state = LMG.GetState and LMG.GetState() or {}
    local syms = LMG.GetSymbols and LMG.GetSymbols() or {}

    if not win then return end

    if LMG.RecomputeSlots then
        LMG.RecomputeSlots()
    end

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

            if isCollapsed or not (LMG.IsStateSlotActive and LMG.IsStateSlotActive(stateIndex)) then
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
        local sepPoints = LMG.BuildSeparatorPoints and LMG.BuildSeparatorPoints() or {}

        for i, sep in ipairs(win.arcSeparators) do
            sep:SetSize(scaleX(UI.separatorSize), scaleY(UI.separatorSize))
            sep:ClearAllPoints()
            sep:SetPoint("CENTER", win, "TOP", sepPoints[i].x, sepPoints[i].y)
            if isCollapsed or not (LMG.IsSeparatorActive and LMG.IsSeparatorActive(i)) then
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
        if LMG.RefreshDifficultyDropdown then LMG.RefreshDifficultyDropdown() end
    end

    if win.symbolButtons then
        local bSize = scaleX(UI.symbolButtonSize)
        local gap = scaleX(UI.symbolButtonGap)
        local rowWidth = #syms * bSize + (#syms - 1) * gap
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

LMG.ApplyLayout = applyLayout
