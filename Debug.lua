-- Shared debug toggle for CatgirlTracker automatic chat output.
CCT_DebugEnabled = CCT_DebugEnabled or false

function CCT_IsDebugEnabled()
    return CCT_DebugEnabled == true
end

function CCT_SetDebugEnabled(state)
    CCT_DebugEnabled = state and true or false
end

function CCT_ToggleDebug()
    CCT_DebugEnabled = not CCT_DebugEnabled
    print("|cffffcc00[CatgirlTracker Debug]:|r " .. (CCT_DebugEnabled and "ON" or "OFF"))
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
