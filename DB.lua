local ADDON_NAME, LMG = ...

local AceDB = LibStub and LibStub("AceDB-3.0", true)

local DEFAULT_DB = {
    profile = {
        window = {
            width = 395,
            height = 535,
            point = "CENTER",
            relativePoint = "CENTER",
            x = 200,
            y = 80,
            collapsed = false,
        },
        settings = {
            autoFill = true,
            preventDuplicates = true,
            lockAfterSend = false,
            alsoSendRW = false,
            changelogDismissedVersion = "",
            difficultyMode = "auto",
        },
        minimap = {
            hide = false,
            minimapPos = 220,
        },
    },
}

local function getProfile()
    local db = LMG.GetAddonDB and LMG.GetAddonDB()
    return db and db.profile or nil
end

local function getWindowDB()
    local profile = getProfile()
    return profile and profile.window or nil
end

local function getSettingsDB()
    local profile = getProfile()
    return profile and profile.settings or nil
end

local function getMinimapDB()
    local profile = getProfile()
    return profile and profile.minimap or nil
end

local function initializeDB()
    if not AceDB then
        error("AceDB-3.0 is required but was not found. Check your .toc library order.")
    end

    local db = AceDB:New(LMG.DB_NAME or "LuraMemoryGameHelperDB", DEFAULT_DB, true)
    if LMG.SetAddonDB then
        LMG.SetAddonDB(db)
    end

    if LMG.ApplyDBSettings then
        LMG.ApplyDBSettings(getWindowDB(), getSettingsDB())
    end
end

local function saveWindowState()
    local window = getWindowDB()
    if not window or not LMG.CollectWindowState then
        return
    end

    local current = LMG.CollectWindowState()
    for k, v in pairs(current) do
        window[k] = v
    end
end

local function saveSettingsState()
    local settings = getSettingsDB()
    if not settings or not LMG.CollectSettingsState then
        return
    end

    local current = LMG.CollectSettingsState()
    for k, v in pairs(current) do
        settings[k] = v
    end
    settings.changelogDismissedVersion = settings.changelogDismissedVersion or ""
end

LMG.InitializeDB = initializeDB
LMG.SaveWindowState = saveWindowState
LMG.SaveSettingsState = saveSettingsState
LMG.GetWindowDB = getWindowDB
LMG.GetSettingsDB = getSettingsDB
LMG.GetMinimapDB = getMinimapDB
