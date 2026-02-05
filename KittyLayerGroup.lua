local addonPrefix = "CatgirlTracker"
local myName = UnitName("player")
local myShortName = myName and myName:match("^[^%-]+") or myName
local LAYER_MODULE = "LayerInvite"

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
end

local layerInviteFrame = nil
local ownerInviteFrame = nil
local pendingTimers = {}
local loginAnnounced = false

local function ShortName(name)
    if not name then return name end
    return name:match("^[^%-]+")
end

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function IsModuleEnabled()
    return not CCT_IsModuleEnabled or CCT_IsModuleEnabled(LAYER_MODULE)
end

local function GetOwnerFromNote()
    if not IsInGuild() then
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and ShortName(name) == myShortName then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            local owner = source and source:match("owner=([^,]+)") or nil
            return ShortName(owner)
        end
    end
end

local function IsOwnerSender(senderShort)
    local ownerShort = GetOwnerFromNote()
    if not ownerShort or not senderShort then
        return false
    end
    return ownerShort:lower() == senderShort:lower()
end

local function GetCurrentLayer()
    local nwbLayer = tonumber(_G.NWB_CurrentLayer)
    if nwbLayer and nwbLayer > 0 then
        return nwbLayer
    end
    return nil
end

local function IsGrouped()
    if IsInRaid and IsInRaid() then
        return true
    end
    if IsInGroup and IsInGroup() then
        return true
    end
    if GetNumGroupMembers then
        return GetNumGroupMembers() > 0
    end
    return false
end

local function SendGuildMessage(text)
    if not text or text == "" then return end
    if IsInGuild() then
        SendChatMessage(text, "GUILD")
    end
end

local function SafeInvite(target)
    if not target or target == "" then
        return false
    end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(target)
        return true
    end
    if InviteUnit then
        InviteUnit(target)
        return true
    end
    return false
end

local function SafeLeaveParty()
    if C_PartyInfo and C_PartyInfo.LeaveParty then
        C_PartyInfo.LeaveParty()
        return true
    end
    if LeaveParty then
        LeaveParty()
        return true
    end
    return false
end

local function SendAddonGuildMessage(text)
    if not text or text == "" then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        if C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
        end
        C_ChatInfo.SendAddonMessage(addonPrefix, text, "GUILD")
    end
end

local function GetBondingMessage(key)
    if CCT_Msg then
        return CCT_Msg(key)
    end
    if key == "LAYER_OWNER_INVITE_SENT" then
        return "Invited you to my group nya~"
    end
    if key == "LAYER_OWNER_NEED_LEAVE" then
        return "curespbonding: I'm in a group and need to leave before inviting you nya~"
    end
    return "curespbonding"
end

local function GetLayerMessage(key, ...)
    if CCT_Msg then
        local msg = CCT_Msg(key, ...)
        if msg and msg ~= key then
            return msg
        end
    end
    local defaults = {
        LAYER_LIST_RESPONSE = "%s is on layer %s",
        LAYER_LIST_MISSING = "%s Missing Nova World Buffs or not Determined Yet",
        LAYER_INVITE_FULL = "Tryed to invite \"%s\" but has kitty brain and does not realise The group is already full nya !",
        LAYER_INVITE_NOT_OWNER = "Tryed to invite \"%s\" but is not even the owner of their group kitty brain strikes again nya ....",
        LAYER_INVITE_PROMISE = "%s is curently in a group but promises to invite you to layer change in %d minutes nya !",
        LAYER_INVITE_LEAVE = "%s was good Kitty and invited \"%s\" to a new layer nya !",
        LAYER_INVITE_BUSY = "Sorry %s does not have time to invite you right now nya.....",
        LAYER_INVITE_SUCCESS = "%s was sucefully invited to the requested layer.",
        LAYER_LOGIN_ANNOUNCE = "Uses CatGirlTracker V1.2 get it in our nya Discord. Use Llist  and then Linv to get layer invite even without Addonn nya!. but the Addon can do a lot nya more~",
    }
    local template = defaults[key]
    if not template then
        return tostring(key or "")
    end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, template, ...)
        if ok then
            return formatted
        end
    end
    return template
end

local function SendOwnerBondingWhisper(key, target)
    if not target then return end
    SendChatMessage(GetBondingMessage(key), "WHISPER", nil, target)
end

local function CancelPendingTimer(requesterShort)
    if not requesterShort then return end
    local entry = pendingTimers[requesterShort]
    if entry and entry.timer and entry.timer.Cancel then
        entry.timer:Cancel()
    end
    pendingTimers[requesterShort] = nil
end

local function CancelAllPendingTimers()
    for requesterShort, entry in pairs(pendingTimers) do
        if entry and entry.timer and entry.timer.Cancel then
            entry.timer:Cancel()
        end
        pendingTimers[requesterShort] = nil
    end
end

local function BroadcastInviteSent(requesterShort, layer)
    if not requesterShort then return end
    local message = string.format(
        "LayerInviteSent, requester:%s, inviter:%s, layer:%s",
        requesterShort,
        myShortName or "unknown",
        tostring(layer or "nil")
    )
    SendAddonGuildMessage(message)
end

local function InviteRequesterNow(requesterFull, requesterShort, layer)
    if not requesterFull or not requesterShort then return end
    SafeInvite(requesterFull)
    BroadcastInviteSent(requesterShort, layer)
end

local function ScheduleInvite(requesterFull, requesterShort, layer, minutes)
    if not requesterFull or not requesterShort then return end
    CancelPendingTimer(requesterShort)

    local minutesValue = tonumber(minutes) or 0
    if minutesValue < 0 then minutesValue = 0 end

    local delaySeconds = minutesValue * 60
    pendingTimers[requesterShort] = {
        timer = C_Timer.NewTimer(delaySeconds, function()
            pendingTimers[requesterShort] = nil
            InviteRequesterNow(requesterFull, requesterShort, layer)
        end),
        requesterFull = requesterFull,
        layer = layer,
        minutes = minutesValue,
    }
end

local function GetInviteBlockReason()
    if IsInGroup and IsInGroup() then
        local isLeader = UnitIsGroupLeader and UnitIsGroupLeader("player")
        local isAssistant = UnitIsGroupAssistant and UnitIsGroupAssistant("player")
        if not (isLeader or isAssistant) then
            return "not_owner"
        end
        local members = GetNumGroupMembers and GetNumGroupMembers() or 0
        if IsInRaid and IsInRaid() then
            if members >= 40 then
                return "full"
            end
        else
            if members >= 5 then
                return "full"
            end
        end
    end
    return nil
end

local function EnsureOwnerInviteFrame()
    if ownerInviteFrame then return ownerInviteFrame end

    ownerInviteFrame = CreateFrame("Frame", "CatgirlOwnerGroupInviteFrame", UIParent, "BackdropTemplate")
    ownerInviteFrame:SetSize(460, 130)
    ownerInviteFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    ownerInviteFrame:SetMovable(true)
    ownerInviteFrame:EnableMouse(true)
    ownerInviteFrame:RegisterForDrag("LeftButton")
    ownerInviteFrame:SetScript("OnDragStart", ownerInviteFrame.StartMoving)
    ownerInviteFrame:SetScript("OnDragStop", ownerInviteFrame.StopMovingOrSizing)

    ownerInviteFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    ownerInviteFrame:SetBackdropColor(0, 0, 0, 0.85)

    local title = ownerInviteFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Owner Group Invite")

    ownerInviteFrame.infoText = ownerInviteFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ownerInviteFrame.infoText:SetPoint("TOP", title, "BOTTOM", 0, -6)
    ownerInviteFrame.infoText:SetText("Owner group invite requested by Tracking Jewel.")

    ownerInviteFrame.actionButton = CreateFrame("Button", nil, ownerInviteFrame, "UIPanelButtonTemplate")
    ownerInviteFrame.actionButton:SetSize(420, 22)
    ownerInviteFrame.actionButton:SetPoint("TOP", ownerInviteFrame.infoText, "BOTTOM", 0, -12)
    ownerInviteFrame.actionButton:SetText("Leave group Owner Group Invite detected by Tracking Jewl")

    ownerInviteFrame.actionButton:SetScript("OnClick", function()
        local target = ownerInviteFrame.ownerFull
        if not target then
            ownerInviteFrame:Hide()
            return
        end
        local function DoInvite()
            SafeInvite(target)
            SendOwnerBondingWhisper("LAYER_OWNER_INVITE_SENT", target)
        end
        if IsGrouped() then
            SafeLeaveParty()
            C_Timer.After(0.8, DoInvite)
        else
            DoInvite()
        end
        ownerInviteFrame:Hide()
    end)

    ownerInviteFrame:Hide()
    return ownerInviteFrame
end

local function EnsureLayerInviteFrame()
    if layerInviteFrame then return layerInviteFrame end

    layerInviteFrame = CreateFrame("Frame", "CatgirlLayerInviteFrame", UIParent, "BackdropTemplate")
    layerInviteFrame:SetSize(460, 230)
    layerInviteFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
    layerInviteFrame:SetMovable(true)
    layerInviteFrame:EnableMouse(true)
    layerInviteFrame:RegisterForDrag("LeftButton")
    layerInviteFrame:SetScript("OnDragStart", layerInviteFrame.StartMoving)
    layerInviteFrame:SetScript("OnDragStop", layerInviteFrame.StopMovingOrSizing)

    layerInviteFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    layerInviteFrame:SetBackdropColor(0, 0, 0, 0.85)

    local title = layerInviteFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Layer Invite Request")

    layerInviteFrame.infoText = layerInviteFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layerInviteFrame.infoText:SetPoint("TOP", title, "BOTTOM", 0, -6)
    layerInviteFrame.infoText:SetText("Layer request pending.")

    local minutesLabel = layerInviteFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minutesLabel:SetPoint("TOPLEFT", 20, -70)
    minutesLabel:SetText("Invite in (minutes)")

    layerInviteFrame.minutesBox = CreateFrame("EditBox", nil, layerInviteFrame, "InputBoxTemplate")
    layerInviteFrame.minutesBox:SetSize(50, 20)
    layerInviteFrame.minutesBox:SetPoint("LEFT", minutesLabel, "RIGHT", 8, 0)
    layerInviteFrame.minutesBox:SetAutoFocus(false)
    if layerInviteFrame.minutesBox.SetNumeric then
        layerInviteFrame.minutesBox:SetNumeric(true)
    end
    layerInviteFrame.minutesBox:SetText("5")

    local inviteInButton = CreateFrame("Button", nil, layerInviteFrame, "UIPanelButtonTemplate")
    inviteInButton:SetSize(110, 22)
    inviteInButton:SetPoint("TOPLEFT", minutesLabel, "BOTTOMLEFT", 0, -10)
    inviteInButton:SetText("Invite in")

    local tryInviteButton = CreateFrame("Button", nil, layerInviteFrame, "UIPanelButtonTemplate")
    tryInviteButton:SetSize(200, 22)
    tryInviteButton:SetPoint("TOPLEFT", inviteInButton, "BOTTOMLEFT", 0, -8)
    tryInviteButton:SetText("Try Invite to Current Group")

    local leaveInviteButton = CreateFrame("Button", nil, layerInviteFrame, "UIPanelButtonTemplate")
    leaveInviteButton:SetSize(200, 22)
    leaveInviteButton:SetPoint("TOPLEFT", tryInviteButton, "BOTTOMLEFT", 0, -8)
    leaveInviteButton:SetText("Leave group and Invite")

    local busyButton = CreateFrame("Button", nil, layerInviteFrame, "UIPanelButtonTemplate")
    busyButton:SetSize(200, 22)
    busyButton:SetPoint("TOPLEFT", leaveInviteButton, "BOTTOMLEFT", 0, -8)
    busyButton:SetText("Bussy kitten no time")

    inviteInButton:SetScript("OnClick", function()
        if not layerInviteFrame.requesterShort or not layerInviteFrame.requesterFull then
            return
        end
        local minutes = tonumber(layerInviteFrame.minutesBox:GetText()) or 0
        if minutes < 0 then minutes = 0 end
        SendGuildMessage(GetLayerMessage("LAYER_INVITE_PROMISE", myShortName or "Kitty", minutes))
        ScheduleInvite(layerInviteFrame.requesterFull, layerInviteFrame.requesterShort, layerInviteFrame.requestedLayer, minutes)
    end)

    tryInviteButton:SetScript("OnClick", function()
        if not layerInviteFrame.requesterShort or not layerInviteFrame.requesterFull then
            return
        end
        local reason = GetInviteBlockReason()
        if reason == "full" then
            SendGuildMessage(GetLayerMessage("LAYER_INVITE_FULL", layerInviteFrame.requesterShort))
            return
        end
        if reason == "not_owner" then
            SendGuildMessage(GetLayerMessage("LAYER_INVITE_NOT_OWNER", layerInviteFrame.requesterShort))
            return
        end
        local ok = SafeInvite(layerInviteFrame.requesterFull)
        if ok then
            BroadcastInviteSent(layerInviteFrame.requesterShort, layerInviteFrame.requestedLayer)
            layerInviteFrame:Hide()
        end
    end)

    leaveInviteButton:SetScript("OnClick", function()
        if not layerInviteFrame.requesterShort or not layerInviteFrame.requesterFull then
            layerInviteFrame:Hide()
            return
        end
        CancelPendingTimer(layerInviteFrame.requesterShort)
        local function DoInvite()
            InviteRequesterNow(layerInviteFrame.requesterFull, layerInviteFrame.requesterShort, layerInviteFrame.requestedLayer)
        end
        if IsGrouped() then
            SafeLeaveParty()
            C_Timer.After(0.8, DoInvite)
        else
            DoInvite()
        end
        SendGuildMessage(GetLayerMessage("LAYER_INVITE_LEAVE", myShortName or "Kitty", layerInviteFrame.requesterShort))
        layerInviteFrame:Hide()
    end)

    busyButton:SetScript("OnClick", function()
        if not layerInviteFrame.requesterShort then
            layerInviteFrame:Hide()
            return
        end
        CancelPendingTimer(layerInviteFrame.requesterShort)
        SendGuildMessage(GetLayerMessage("LAYER_INVITE_BUSY", myShortName or "Kitty"))
        layerInviteFrame:Hide()
    end)

    layerInviteFrame:Hide()
    return layerInviteFrame
end

local function ShowLayerInviteFrame(requesterFull, requesterShort, layer)
    local frame = EnsureLayerInviteFrame()
    frame.requesterFull = requesterFull
    frame.requesterShort = requesterShort
    frame.requestedLayer = layer
    frame.infoText:SetText(string.format("%s requested layer %s.", requesterShort or "Unknown", tostring(layer or "?")))
    frame:Show()
end

local function HandleGuildMessage(msg, sender)
    if not msg or msg == "" then return end
    if not IsModuleEnabled() then return end

    local lower = msg:lower()
    lower = lower:match("^%s*(.-)%s*$")
    if lower == "llist" then
        local layer = GetCurrentLayer()
        if layer then
            local layerText = tostring(layer)
            SendGuildMessage(GetLayerMessage("LAYER_LIST_RESPONSE", myShortName or "Kitty", layerText))
        else
            SendGuildMessage(GetLayerMessage("LAYER_LIST_MISSING", myShortName or "Kitty"))
        end
        return
    end

    local requested = lower:match("^linv%s*(%d+)$")
    if not requested then
        return
    end

    local layer = GetCurrentLayer()
    if not layer or tonumber(requested) ~= tonumber(layer) then
        return
    end

    local requesterShort = ShortName(sender)
    if requesterShort and myShortName and requesterShort:lower() == myShortName:lower() then
        return
    end

    if IsGrouped() then
        ShowLayerInviteFrame(sender, requesterShort, layer)
    else
        InviteRequesterNow(sender, requesterShort, layer)
    end
end

local function HandleWhisper(msg, sender)
    if not msg or not sender then return end
    local msgLower = msg:lower()
    msgLower = msgLower:match("^%s*(.-)%s*$")
    if msgLower ~= "owner forces you to create a group" and msgLower ~= "forcekittygroup" then
        return
    end

    local senderShort = ShortName(sender)
    if not IsOwnerSender(senderShort) then
        return
    end

    if IsGrouped() then
        local frame = EnsureOwnerInviteFrame()
        frame.ownerFull = sender
        frame.ownerShort = senderShort
        frame.infoText:SetText("Owner group invite requested by Tracking Jewel.")
        frame:Show()
        SendOwnerBondingWhisper("LAYER_OWNER_NEED_LEAVE", sender)
    else
        SafeInvite(sender)
        SendOwnerBondingWhisper("LAYER_OWNER_INVITE_SENT", sender)
    end
end

local function HandleAddonMessage(prefix, msg, channel, sender)
    if prefix ~= addonPrefix then
        return
    end
    if not msg then
        return
    end

    local requester, inviter, layer = msg:match("^LayerInviteSent, requester:([^,]+), inviter:([^,]+), layer:([^,]+)")
    if not requester then
        return
    end

    local requesterShort = ShortName(requester)
    if requesterShort then
        CancelPendingTimer(requesterShort)
    end

    if layerInviteFrame and layerInviteFrame:IsShown() and layerInviteFrame.requesterShort and requesterShort then
        if layerInviteFrame.requesterShort:lower() == requesterShort:lower() then
            layerInviteFrame:Hide()
        end
    end

    if IsModuleEnabled() and requesterShort and myShortName and requesterShort:lower() == myShortName:lower() then
        SendGuildMessage(GetLayerMessage("LAYER_INVITE_SUCCESS", requesterShort))
    end
end

local function TrySendLoginMessage()
    if loginAnnounced then return end
    if not IsInGuild() then return end
    SendGuildMessage(GetLayerMessage("LAYER_LOGIN_ANNOUNCE"))
    loginAnnounced = true
end

if CCT_RegisterModuleWatcher then
    CCT_RegisterModuleWatcher(LAYER_MODULE, function(enabled)
        if not enabled then
            if layerInviteFrame then layerInviteFrame:Hide() end
            CancelAllPendingTimers()
        end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_GUILD")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_GUILD_UPDATE")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_GUILD" then
        local msg, sender = ...
        HandleGuildMessage(msg, sender)
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        HandleWhisper(msg, sender)
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        HandleAddonMessage(prefix, msg, channel, sender)
        return
    end

    if event == "PLAYER_LOGIN" then
        C_Timer.After(6, TrySendLoginMessage)
        return
    end

    if event == "PLAYER_GUILD_UPDATE" then
        C_Timer.After(6, TrySendLoginMessage)
        return
    end
end)
