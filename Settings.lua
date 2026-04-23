local ADDON_NAME, LMG = ...

local settingsFrame = nil

local function refreshSettingsControls()
    if not settingsFrame then
        return
    end

    if settingsFrame.autoFillCB then
        settingsFrame.autoFillCB:SetChecked(LMG.GetAutoFill and LMG.GetAutoFill() or false)
    end
    if settingsFrame.dupCB then
        settingsFrame.dupCB:SetChecked(LMG.GetPreventDuplicates and LMG.GetPreventDuplicates() or false)
    end
    if settingsFrame.lockCB then
        settingsFrame.lockCB:SetChecked(LMG.GetLockAfterSend and LMG.GetLockAfterSend() or false)
    end
    if settingsFrame.rwCB then
        local enabled = LMG.PlayerCanBroadcast and LMG.PlayerCanBroadcast() or false
        settingsFrame.rwCB:SetChecked(LMG.GetAlsoSendRW and LMG.GetAlsoSendRW() or false)
        settingsFrame.rwCB:SetEnabled(enabled)
        settingsFrame.rwCB:SetAlpha(enabled and 1 or 0.5)
    end
    if settingsFrame.modeDropdown then
        local mode = LMG.GetManualDifficultyOverride and LMG.GetManualDifficultyOverride() or "auto"
        local label = "Auto"
        if mode == "normal" then
            label = "Normal (3)"
        elseif mode == "heroic" then
            label = "Heroic (5)"
        elseif mode == "mythic" then
            label = "Mythic (5)"
        end
        UIDropDownMenu_SetText(settingsFrame.modeDropdown, label)
    end
end

local function toggleSettingsWindow()
    if not settingsFrame then
        return
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        refreshSettingsControls()
        settingsFrame:Show()
    end
end

local function buildSettingsWindow()
    if settingsFrame then
        return
    end

    local f = CreateFrame("Frame", "LuraMemoryGameHelperSettings", UIParent, "BackdropTemplate")
    f:SetSize(380, 270)
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
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Lura Memory Game Helper - Settings")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)

    local function createCheckbox(label, x, y, onClick)
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        cb.text:SetText(label)
        cb:SetScript("OnClick", onClick)
        return cb
    end

    f.autoFillCB = createCheckbox("Enable Autofill", 18, -42, function(self)
        if LMG.SetAutoFill then LMG.SetAutoFill(self:GetChecked() and true or false) end
        if LMG.SaveSettingsState then LMG.SaveSettingsState() end
    end)

    f.dupCB = createCheckbox("Prevent Duplicates", 18, -72, function(self)
        if LMG.SetPreventDuplicates then LMG.SetPreventDuplicates(self:GetChecked() and true or false) end
        if LMG.SaveSettingsState then LMG.SaveSettingsState() end
    end)

    f.lockCB = createCheckbox("Lock After Send", 18, -102, function(self)
        if LMG.SetLockAfterSend then LMG.SetLockAfterSend(self:GetChecked() and true or false) end
        if LMG.SaveSettingsState then LMG.SaveSettingsState() end
    end)

    f.rwCB = createCheckbox("Also Send Raid Warning", 18, -132, function(self)
        if not (LMG.PlayerCanBroadcast and LMG.PlayerCanBroadcast()) then
            self:SetChecked(false)
            return
        end
        if LMG.SetAlsoSendRW then LMG.SetAlsoSendRW(self:GetChecked() and true or false) end
        if LMG.SaveSettingsState then LMG.SaveSettingsState() end
        local win = LMG.GetWindow and LMG.GetWindow()
        if win and win.rwCheckbox and win.rwCheckbox.checkedTex then
            win.rwCheckbox.checkedTex:SetShown(LMG.GetAlsoSendRW and LMG.GetAlsoSendRW() or false)
        end
    end)

    local modeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -175)
    modeLabel:SetText("Difficulty Mode")

    local dd = CreateFrame("Frame", "LuraMMGSettingsDropdown", f, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", f, "TOPLEFT", 130, -164)
    UIDropDownMenu_SetWidth(dd, 150)
    UIDropDownMenu_Initialize(dd, function(self, level)
        local function addEntry(label, mode)
            local info = UIDropDownMenu_CreateInfo()
            info.text = label
            info.func = function()
                if LMG.SetManualDifficultyOverride then
                    LMG.SetManualDifficultyOverride(mode)
                end
                if LMG.SaveSettingsState then LMG.SaveSettingsState() end
                if LMG.RefreshDifficultyDropdown then LMG.RefreshDifficultyDropdown() end
                if LMG.ApplyRaidDifficultyPatternMode then LMG.ApplyRaidDifficultyPatternMode() end
                refreshSettingsControls()
            end
            info.checked = ((LMG.GetManualDifficultyOverride and LMG.GetManualDifficultyOverride() or "auto") == mode)
            UIDropDownMenu_AddButton(info, level)
        end

        addEntry("Auto", "auto")
        addEntry("Normal (3)", "normal")
        addEntry("Heroic (5)", "heroic")
        addEntry("Mythic (5)", "mythic")
    end)
    f.modeDropdown = dd

    local testBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    testBtn:SetSize(110, 24)
    testBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
    testBtn:SetText("Toggle Test")
    testBtn:SetScript("OnClick", function()
        local current = LMG.GetTestMode and LMG.GetTestMode() or false
        if LMG.SetTestMode then LMG.SetTestMode(not current) end
        if LMG.NotifyInfo then
            LMG.NotifyInfo("Test Mode: " .. ((not current) and "ENABLED" or "DISABLED"))
        end
        if LMG.UpdateBroadcastControls then LMG.UpdateBroadcastControls() end
        refreshSettingsControls()
    end)

    local changelogBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    changelogBtn:SetSize(110, 24)
    changelogBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    changelogBtn:SetText("Changelog")
    changelogBtn:SetScript("OnClick", function()
        if LMG.BuildChangelogFrame then LMG.BuildChangelogFrame() end
        local changelogFrame = LMG.GetChangelogFrame and LMG.GetChangelogFrame()
        if changelogFrame and changelogFrame.dismissCheck and changelogFrame.dismissCheck.checkedTex then
            changelogFrame.dismissCheck.checkedTex:SetShown(false)
        end
        if changelogFrame then
            changelogFrame:Show()
        end
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("LEFT", changelogBtn, "RIGHT", 10, 0)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    settingsFrame = f
    refreshSettingsControls()
end

LMG.BuildSettingsWindow = buildSettingsWindow
LMG.ToggleSettingsWindow = toggleSettingsWindow
LMG.RefreshSettingsControls = refreshSettingsControls
