-- Shared debug toggle for CatgirlTracker automatic chat output.
CatgirlSettingsDB = CatgirlSettingsDB or {}
CatgirlSettingsDB.modules = CatgirlSettingsDB.modules or {}

local defaultModules = {
    HeadPetTracker = true,
    InnSlackerTracker = true,
    PetTracker = true,
}

for name, defaultValue in pairs(defaultModules) do
    if CatgirlSettingsDB.modules[name] == nil then
        CatgirlSettingsDB.modules[name] = defaultValue
    end
end

if CatgirlSettingsDB.debugEnabled == nil then
    CatgirlSettingsDB.debugEnabled = false
end

CCT_DebugEnabled = CatgirlSettingsDB.debugEnabled

function CCT_IsDebugEnabled()
    return CCT_DebugEnabled == true
end

function CCT_SetDebugEnabled(state)
    CCT_DebugEnabled = state and true or false
    CatgirlSettingsDB.debugEnabled = CCT_DebugEnabled
end

function CCT_ToggleDebug()
    CCT_SetDebugEnabled(not CCT_DebugEnabled)
    print("|cffffcc00[CatgirlTracker Debug]:|r " .. (CCT_DebugEnabled and "ON" or "OFF"))
end

local moduleWatchers = {}

function CCT_IsModuleEnabled(name)
    if not name then return true end
    if not CatgirlSettingsDB.modules then return true end
    if CatgirlSettingsDB.modules[name] == nil then
        CatgirlSettingsDB.modules[name] = true
    end
    return CatgirlSettingsDB.modules[name] == true
end

function CCT_SetModuleEnabled(name, enabled)
    if not name then return end
    CatgirlSettingsDB.modules[name] = enabled and true or false
    local watchers = moduleWatchers[name]
    if watchers then
        for _, callback in ipairs(watchers) do
            pcall(callback, CatgirlSettingsDB.modules[name])
        end
    end
end

function CCT_RegisterModuleWatcher(name, callback)
    if not name or type(callback) ~= "function" then return end
    moduleWatchers[name] = moduleWatchers[name] or {}
    table.insert(moduleWatchers[name], callback)
end

function CCT_AutoPrint(...)
    if not CCT_DebugEnabled then return end
    print(...)
end

function CCT_RaidNotice(msg)
    if not msg or msg == "" then return end
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
end

SLASH_CCTDEBUG1 = "/cctdebug"
SlashCmdList["CCTDEBUG"] = function()
    CCT_ToggleDebug()
end
