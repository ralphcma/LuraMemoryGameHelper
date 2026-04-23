local ADDON_NAME, LMG = ...

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

    if tooltipText and tooltipText ~= "" and LMG.AttachTooltip then
        LMG.AttachTooltip(btn, "ANCHOR_TOP", tooltipText)
    end

    return btn
end

local function makeSeparatorAroundButtons(parent, buttonsFrame, topOffset, bottomOffset, inset, topAlpha, bottomAlpha)
    local UI = LMG.UI
    local TEX = LMG.TexPath
    local scaleY = LMG.ScaleY

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
    local win = LMG.GetWindow and LMG.GetWindow()
    if not win or not win.difficultyDropdown then
        return
    end

    local mode = LMG.GetManualDifficultyOverride and LMG.GetManualDifficultyOverride() or "auto"
    local textLabel = getDifficultyModeLabel(mode)
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(win.difficultyDropdown, textLabel)
    elseif win.difficultyDropdown.Text then
        win.difficultyDropdown.Text:SetText(textLabel)
    end
end

local function setDifficultyMode(mode)
    if LMG.SetManualDifficultyOverride then LMG.SetManualDifficultyOverride(mode) end
    if LMG.SaveSettingsState then LMG.SaveSettingsState() end
    if LMG.ApplyRaidDifficultyPatternMode then LMG.ApplyRaidDifficultyPatternMode() end
    refreshDifficultyDropdown()
    if LMG.NotifyInfo then
        LMG.NotifyInfo("Difficulty mode set to " .. getDifficultyModeLabel(mode) .. ".")
    end
end

local function buildDifficultyDropdown()
    local win = LMG.GetWindow and LMG.GetWindow()
    local UI = LMG.UI
    if not win then return end

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
            info.checked = ((LMG.GetManualDifficultyOverride and LMG.GetManualDifficultyOverride() or "auto") == mode)
            UIDropDownMenu_AddButton(info, level)
        end

        addEntry("Auto", "auto")
        addEntry("Normal (3)", "normal")
        addEntry("Heroic (5)", "heroic")
        addEntry("Mythic (5)", "mythic")
    end)

    win.difficultyDropdown = LMG.RegisterContent and LMG.RegisterContent(dd) or dd
    refreshDifficultyDropdown()
end

local function buildActionButtons()
    local win = LMG.GetWindow and LMG.GetWindow()
    local UI = LMG.UI
    local TEX = LMG.TexPath
    local scaleX = LMG.ScaleX
    local scaleY = LMG.ScaleY
    if not win then return end

    local totalWidth = (scaleX(UI.actionButtonWidth) * 2) + scaleX(UI.actionButtonGap)
    local buttonsFrame = CreateFrame("Frame", nil, win)
    buttonsFrame:SetSize(totalWidth, scaleY(UI.actionButtonHeight))
    buttonsFrame:SetPoint("BOTTOM", win, "BOTTOM", 0, UI.actionButtonY)
    if LMG.RegisterContent then LMG.RegisterContent(buttonsFrame) end
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
            if LMG.PlayerCanBroadcast and not LMG.PlayerCanBroadcast() then return end
            if LMG.SaveUndoState then LMG.SaveUndoState() end
            if LMG.DoClear then LMG.DoClear(true) end
        end
    )
    win.clearBtn = clearBtn
    if LMG.RegisterContent then LMG.RegisterContent(clearBtn) end

    local sendBtn = makeTexturedActionButton(
        buttonsFrame,
        scaleX(UI.actionButtonWidth),
        scaleY(UI.actionButtonHeight),
        "LEFT", clearBtn, "RIGHT", scaleX(UI.actionButtonGap), 0,
        TEX .. "btn_send.tga",
        TEX .. "btn_send_down.tga",
        "Send pattern in /say (visible to everyone nearby)",
        function()
            if LMG.PlayerCanBroadcast and not LMG.PlayerCanBroadcast() then return end
            if LMG.SendPattern then LMG.SendPattern() end
        end
    )
    win.sendBtn = sendBtn
    if LMG.RegisterContent then LMG.RegisterContent(sendBtn) end

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
    if LMG.RegisterContent then
        LMG.RegisterContent(topSep)
        LMG.RegisterContent(bottomSep)
    end
end

local function buildRWCheckbox()
    local win = LMG.GetWindow and LMG.GetWindow()
    local UI = LMG.UI
    local TEX = LMG.TexPath
    local scaleX = LMG.ScaleX
    local scaleY = LMG.ScaleY
    if not win then return end

    local cb = CreateFrame("Button", "LuraMemoryGameHelperRWCheck", win)
    cb:SetSize(scaleX(UI.checkboxSize), scaleY(UI.checkboxSize))
    cb:SetPoint("CENTER", win, "BOTTOM", -68, UI.checkboxY)
    if LMG.RegisterContent then LMG.RegisterContent(cb) end
    win.rwCheckbox = cb

    local uncheckedTex = cb:CreateTexture(nil, "BACKGROUND")
    uncheckedTex:SetTexture(TEX .. "checkbox_unchecked.tga")
    uncheckedTex:SetAllPoints()
    cb.uncheckedTex = uncheckedTex

    local checkedTex = cb:CreateTexture(nil, "ARTWORK")
    checkedTex:SetTexture(TEX .. "checkbox_checked.tga")
    checkedTex:SetAllPoints()
    cb.checkedTex = checkedTex
    cb.checkedTex:SetShown(LMG.GetAlsoSendRW and LMG.GetAlsoSendRW() or false)

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
        if LMG.PlayerCanBroadcast and not LMG.PlayerCanBroadcast() then return end
        local value = not (LMG.GetAlsoSendRW and LMG.GetAlsoSendRW() or false)
        if LMG.SetAlsoSendRW then LMG.SetAlsoSendRW(value) end
        self.checkedTex:SetShown(value)
        if LMG.SaveSettingsState then LMG.SaveSettingsState() end
    end)

    cb.label = win:CreateTexture(nil, "OVERLAY")
    cb.label:SetTexture(TEX .. "checkbox_text.tga")
    cb.label:SetSize(scaleX(UI.checkboxLabelWidth), scaleY(UI.checkboxLabelHeight))
    cb.label:SetPoint("LEFT", cb, "RIGHT", scaleX(UI.checkboxLabelOffsetX), 0)
    if LMG.RegisterContent then LMG.RegisterContent(cb.label) end
end

local function buildSymbolButtons()
    local win = LMG.GetWindow and LMG.GetWindow()
    local UI = LMG.UI
    local scaleX = LMG.ScaleX
    local syms = LMG.GetSymbols and LMG.GetSymbols() or {}
    if not win then return end

    local bSize = scaleX(UI.symbolButtonSize)
    local gap = scaleX(UI.symbolButtonGap)
    local rowWidth = #syms * bSize + (#syms - 1) * gap
    local x0 = -(rowWidth / 2) + bSize / 2

    win.symbolButtons = {}

    for i, sym in ipairs(syms) do
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
            if LMG.AddSymbol then LMG.AddSymbol(sym) end
        end)

        win.symbolButtons[i] = btn
        if LMG.RegisterContent then LMG.RegisterContent(btn) end
    end
end

LMG.RefreshDifficultyDropdown = refreshDifficultyDropdown
LMG.BuildActionButtons = buildActionButtons
LMG.BuildRWCheckbox = buildRWCheckbox
LMG.BuildDifficultyDropdown = buildDifficultyDropdown
LMG.BuildSymbolButtons = buildSymbolButtons
