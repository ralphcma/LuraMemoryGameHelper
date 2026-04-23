local ADDON_NAME, LMG = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local launcher
local registeredThisSession = false

local function initMinimap()
    if not LDB or not LDBIcon then
        return false
    end

    local minimap = LMG.GetMinimapDB and LMG.GetMinimapDB()
    if not minimap then
        return false
    end

    -- Never persist session-only registration state in SavedVariables.
    minimap.__registered = nil

    if not launcher then
        launcher = LDB:NewDataObject(ADDON_NAME, {
            type = "launcher",
            text = "Lura Memory Game Helper",
            icon = (LMG.TexPath or "Interface\\AddOns\\LuraMemoryGameHelper\\Textures\\") .. "sym_circle.tga",
            OnClick = function(_, button)
                if LMG.EnsureWindowBuilt then
                    LMG.EnsureWindowBuilt()
                end
                if button == "RightButton" then
                    if LMG.ToggleSettingsWindow then
                        LMG.ToggleSettingsWindow()
                    end
                else
                    if LMG.ToggleWindow then
                        LMG.ToggleWindow()
                    end
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:SetText("Lura Memory Game Helper", 1, 1, 1)
                tooltip:AddLine("Left-Click: Toggle main window", 1, 0.82, 0)
                tooltip:AddLine("Right-Click: Open settings", 1, 0.82, 0)
                tooltip:Show()
            end,
        })
    end

    if not registeredThisSession then
        LDBIcon:Register(ADDON_NAME, launcher, minimap)
        registeredThisSession = true
    end

    if minimap.hide then
        LDBIcon:Hide(ADDON_NAME)
    else
        LDBIcon:Show(ADDON_NAME)
    end

    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    initMinimap()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
