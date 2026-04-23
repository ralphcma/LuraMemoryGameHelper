local ADDON_NAME, LMG = ...

local function buildCustomFrameBorder(parent)
    local UI = LMG.UI
    local scaleX = LMG.ScaleX
    local TEX = LMG.TexPath

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

local function buildMainFrame()
    local UI = LMG.UI
    local TEX = LMG.TexPath
    local win = CreateFrame("Frame", "LuraMemoryGameHelperWin", UIParent, "BackdropTemplate")
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
        if LMG.SaveWindowState then LMG.SaveWindowState() end
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
    win.luraArt = LMG.RegisterContent and LMG.RegisterContent(luraArt) or luraArt

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

        if win.SetSize then
            win:SetSize(UI.width, UI.height)
        end

        if LMG.ApplyLayout then LMG.ApplyLayout() end
        if LMG.SaveWindowState then LMG.SaveWindowState() end
    end)
    win.resizeHandle = resizeHandle

    if LMG.SetWindow then
        LMG.SetWindow(win)
    end
end

local function buildTitleBar()
    local win = LMG.GetWindow and LMG.GetWindow()
    local TEX = LMG.TexPath
    local scaleX = LMG.ScaleX
    local scaleY = LMG.ScaleY
    local UI = LMG.UI
    if not win then return end

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() if LMG.HideWindow then LMG.HideWindow() end end)

    local minBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    minBtn:SetSize(22, 18)
    minBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -26, -6)
    minBtn:SetText("-")
    minBtn:SetScript("OnClick", function() if LMG.ToggleCollapsed then LMG.ToggleCollapsed() end end)
    if LMG.AttachTooltip then
        LMG.AttachTooltip(minBtn, "ANCHOR_TOP", function()
            return (LMG.GetCollapsedState and LMG.GetCollapsedState()) and "Expand" or "Minimize"
        end)
    end
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
    win.statusText = LMG.RegisterContent and LMG.RegisterContent(statusText) or statusText
end

LMG.BuildMainFrame = buildMainFrame
LMG.BuildTitleBar = buildTitleBar
