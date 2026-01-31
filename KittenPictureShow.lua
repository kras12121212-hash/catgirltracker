local kittyname = UnitName("player")
local shortName = kittyname and kittyname:match("^[^%-]+") or kittyname

local CGCC_TEXTURE_PATH = "Interface\\AddOns\\CatgirlTracker\\Textures\\cgcc\\"
local POPUP_IMAGE_SIZE = 232
local BINDS_ICON_SIZE = 40
local BINDS_ICON_PADDING = 6
local BINDS_WINDOW_PADDING = 8

local bindsFrame = nil
local bindsIconContainer = nil
local bindsIconTextures = {}
local popupFrame = nil
local popupToken = 0
local isKitten = false
local logInitialized = false
local lastLogSize = 0
local updateTicker = nil

local TOY_DEFS = {
    { id = "dildo", icon = "Textures/Dildo.tga" },
    { id = "inflatable_butplug", icon = "Textures/InflatableButplug.tga" },
    { id = "inflatable_dildo", icon = "Textures/InflatableDildo.tga" },
    { id = "small_butplug", icon = "Textures/SmallButplug.tga" },
    { id = "large_butplug", icon = "Textures/LargeButplug.tga" },
    { id = "taill_butplug", icon = "Textures/TaillButplug.tga" },
    { id = "vibes_pussy", icon = "Textures/Vibes.tga" },
    { id = "vibes_nipples", icon = "Textures/Vibes.tga" },
    { id = "vibes_ears", icon = "Textures/Vibes.tga" },
    { id = "nipple_piercings", icon = "Textures/Piercings.tga" },
    { id = "ear_piercings", icon = "Textures/Piercings.tga" },
    { id = "pussy_lipps_piercings", icon = "Textures/Piercings.tga" },
}

local function ToyEventName(id)
    return "Toy_" .. id
end

CatgirlBehaviorDB = CatgirlBehaviorDB or {}
CatgirlBehaviorDB.BehaviorLog = CatgirlBehaviorDB.BehaviorLog or {}
CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}

local function GetBehaviorLog()
    CatgirlBehaviorDB.BehaviorLog[kittyname] = CatgirlBehaviorDB.BehaviorLog[kittyname] or {}
    return CatgirlBehaviorDB.BehaviorLog[kittyname]
end

local function BuildControlIconPath(fileName)
    if not fileName or fileName == "" then
        return nil
    end
    if fileName:find("[/\\]") then
        return "Interface\\AddOns\\CatgirlTracker\\" .. fileName:gsub("/", "\\")
    end
    return CGCC_TEXTURE_PATH .. fileName
end

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function GetOwnerFromNote()
    if not IsInGuild or not IsInGuild() then
        return nil
    end
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, note, officerNote = GetGuildRosterInfo(i)
        if name and name:match("^[^%-]+") == shortName then
            local source = nil
            if type(officerNote) == "string" and officerNote ~= "" then
                source = officerNote
            elseif type(note) == "string" and note ~= "" then
                source = note
            end
            local ownerName = source and source:match("owner=([^,]+)")
            if ownerName and ownerName ~= "" then
                return ownerName
            end
        end
    end
end

local function FindLastEvent(log, eventName)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == eventName then
            return entry
        end
    end
end

local function GetLeashState(log)
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.event == "KittenLeash" then
            return "Leashed"
        elseif entry.event == "KittenUnleash" then
            return "Unleashed"
        end
    end
    return "Unknown"
end

local function GetAppliedBindIconFiles(log)
    local icons = {}
    if not log or type(log) ~= "table" then
        return icons
    end

    local function addIcon(fileName)
        if fileName then
            table.insert(icons, fileName)
        end
    end

    local gagEntry = FindLastEvent(log, "KittenGag")
    local gagState = gagEntry and gagEntry.Gagstate
    if gagState == "Gag" then
        addIcon("Heavy-gag-232-with-bg_ergebnis.tga")
    elseif gagState == "LightGag" then
        addIcon("small-gag-232-with-bg_ergebnis.tga")
    elseif gagState == "FullBlock" then
        addIcon("kitty-mask-with-gag-232-with-bg_ergebnis.tga")
    elseif gagState == "NyaMask" then
        addIcon("cute-kitty-mask-232-with-bg_ergebnis.tga")
    elseif type(gagState) == "string" and gagState:match("^Inflatable") then
        addIcon("Inflatable-gag-232-with-bg_ergebnis.tga")
    end

    local blindEntry = FindLastEvent(log, "KittenBlindfold")
    local blindState = blindEntry and blindEntry.BlindfoldState
    if blindState == "light" then
        addIcon("Light-Blindfold-232-with-bg_ergebnis.tga")
    elseif blindState == "mask" then
        addIcon("Cute-Kitty-Blindfold-232-with-bg_ergebnis.tga")
    elseif blindState == "full" then
        addIcon("Heavy-Blindfold-232-with-bg_ergebnis.tga")
    end

    local earEntry = FindLastEvent(log, "KittenEarmuffs")
    local earState = earEntry and earEntry.state
    if earState == "KittenEarmuffs" then
        addIcon("Kitten-Earmuffs-bg_ergebnis.tga")
    elseif earState == "HeavyEarmuffs" then
        addIcon("Heav-Earmuffs-bg_ergebnis.tga")
    end

    local mittensEntry = FindLastEvent(log, "PawMittens")
    local mittenState = mittensEntry and mittensEntry.state
    if mittenState == "locked" or mittenState == "heavy" then
        addIcon("locking-paw-mitten-232-with-bg_ergebnis.tga")
    elseif mittenState == "squeaking" or mittenState == "squeking" then
        addIcon("paw-mitten-232-with-bg_ergebnis.tga")
    end

    local heelsEntry = FindLastEvent(log, "KittenHeels")
    local heelsState = heelsEntry and heelsEntry.state
    if heelsState == "maid" then
        addIcon("maid-heell-232-with-bg_ergebnis.tga")
    elseif heelsState == "high" then
        addIcon("heell-232-with-bg_ergebnis.tga")
    elseif heelsState == "ballet" then
        addIcon("balletheel-232-with-bg_ergebnis.tga")
    end

    local bellEntry = FindLastEvent(log, "BellState")
    if bellEntry and bellEntry.state then
        addIcon("bell-232-with-bg_ergebnis.tga")
    end

    local tailEntry = FindLastEvent(log, "TailBellState")
    if tailEntry and tailEntry.state then
        addIcon("tail-bell-232-with-bg_ergebnis.tga")
    end

    local trackingEntry = FindLastEvent(log, "TrackingJewel")
    if trackingEntry and trackingEntry.state then
        addIcon("jewel-232-with-bg_ergebnis.tga")
    end

    local beltEntry = FindLastEvent(log, "ChastityBelt")
    if beltEntry and beltEntry.state == true then
        addIcon("Chastitybelt.tga")
    end

    local braEntry = FindLastEvent(log, "ChastityBra")
    if braEntry and braEntry.state == true then
        addIcon("chastitybra.tga")
    end

    for _, toy in ipairs(TOY_DEFS) do
        local toyEntry = FindLastEvent(log, ToyEventName(toy.id))
        if toyEntry and toyEntry.state == true then
            addIcon(toy.icon)
        end
    end

    if GetLeashState(log) == "Leashed" then
        addIcon("leash-232-with-gb_ergebnis.tga")
    end

    return icons
end

local function GetAppliedIconForEntry(entry)
    if not entry or not entry.event then
        return nil
    end

    if entry.event == "KittenGag" then
        local state = entry.Gagstate
        if state == "Gag" then
            return "Heavy-gag-232-with-bg_ergebnis.tga"
        elseif state == "LightGag" then
            return "small-gag-232-with-bg_ergebnis.tga"
        elseif state == "FullBlock" then
            return "kitty-mask-with-gag-232-with-bg_ergebnis.tga"
        elseif state == "NyaMask" then
            return "cute-kitty-mask-232-with-bg_ergebnis.tga"
        elseif type(state) == "string" and state:match("^Inflatable") then
            return "Inflatable-gag-232-with-bg_ergebnis.tga"
        end

    elseif entry.event == "KittenBlindfold" then
        local state = entry.BlindfoldState
        if state == "light" then
            return "Light-Blindfold-232-with-bg_ergebnis.tga"
        elseif state == "mask" then
            return "Cute-Kitty-Blindfold-232-with-bg_ergebnis.tga"
        elseif state == "full" then
            return "Heavy-Blindfold-232-with-bg_ergebnis.tga"
        end

    elseif entry.event == "KittenEarmuffs" then
        local state = entry.state
        if state == "KittenEarmuffs" then
            return "Kitten-Earmuffs-bg_ergebnis.tga"
        elseif state == "HeavyEarmuffs" then
            return "Heav-Earmuffs-bg_ergebnis.tga"
        end

    elseif entry.event == "PawMittens" then
        local state = entry.state
        if state == "locked" or state == "heavy" then
            return "locking-paw-mitten-232-with-bg_ergebnis.tga"
        elseif state == "squeaking" or state == "squeking" then
            return "paw-mitten-232-with-bg_ergebnis.tga"
        end

    elseif entry.event == "KittenHeels" then
        local state = entry.state
        if state == "maid" then
            return "maid-heell-232-with-bg_ergebnis.tga"
        elseif state == "high" then
            return "heell-232-with-bg_ergebnis.tga"
        elseif state == "ballet" then
            return "balletheel-232-with-bg_ergebnis.tga"
        end

    elseif entry.event == "BellState" then
        if entry.state == true then
            return "bell-232-with-bg_ergebnis.tga"
        end

    elseif entry.event == "TailBellState" then
        if entry.state == true then
            return "tail-bell-232-with-bg_ergebnis.tga"
        end

    elseif entry.event == "TrackingJewel" then
        if entry.state == true then
            return "jewel-232-with-bg_ergebnis.tga"
        end

    elseif entry.event == "ChastityBelt" then
        if entry.state == true then
            return "Chastitybelt.tga"
        end

    elseif entry.event == "ChastityBra" then
        if entry.state == true then
            return "chastitybra.tga"
        end

    elseif entry.event and entry.event:match("^Toy_") then
        for _, toy in ipairs(TOY_DEFS) do
            if entry.event == ToyEventName(toy.id) and entry.state == true then
                return toy.icon
            end
        end

    elseif entry.event == "KittenLeash" then
        return "leash-232-with-gb_ergebnis.tga"
    end

    return nil
end

local function EnsurePopupFrame()
    if popupFrame then
        return popupFrame
    end

    popupFrame = CreateFrame("Frame", "CatgirlKittenBindPopup", UIParent, "BackdropTemplate")
    popupFrame:SetSize(POPUP_IMAGE_SIZE + 8, POPUP_IMAGE_SIZE + 8)
    popupFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    popupFrame:SetFrameStrata("TOOLTIP")
    popupFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popupFrame:SetBackdropColor(0, 0, 0, 0.75)

    popupFrame.texture = popupFrame:CreateTexture(nil, "ARTWORK")
    popupFrame.texture:SetSize(POPUP_IMAGE_SIZE, POPUP_IMAGE_SIZE)
    popupFrame.texture:SetPoint("CENTER")
    popupFrame:Hide()

    return popupFrame
end

local function ShowPopup(iconFile)
    if not iconFile then return end
    local frame = EnsurePopupFrame()
    frame.texture:SetTexture(BuildControlIconPath(iconFile))
    frame:Show()

    popupToken = popupToken + 1
    local token = popupToken
    C_Timer.After(5, function()
        if popupToken == token and popupFrame then
            popupFrame:Hide()
        end
    end)
end

local function GetBindsWindowPosition()
    CatgirlSettingsDB = CatgirlSettingsDB or {}
    CatgirlSettingsDB.kittenBindsWindow = CatgirlSettingsDB.kittenBindsWindow or {}
    CatgirlSettingsDB.kittenBindsWindow[shortName] = CatgirlSettingsDB.kittenBindsWindow[shortName] or {}
    return CatgirlSettingsDB.kittenBindsWindow[shortName]
end

local function ApplySavedBindsWindowPosition(frame)
    if not frame then return end
    local db = GetBindsWindowPosition()
    if not db.point then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -200)
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x or 0, db.y or 0)
end

local function SaveBindsWindowPosition(frame)
    if not frame then return end
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then return end
    local db = GetBindsWindowPosition()
    db.point = point
    db.relativePoint = relativePoint
    db.x = xOfs
    db.y = yOfs
end

local function EnsureBindsWindow()
    if bindsFrame then
        return bindsFrame
    end

    bindsFrame = CreateFrame("Frame", "CatgirlKittenBindsWindow", UIParent, "BackdropTemplate")
    bindsFrame:SetFrameStrata("LOW")
    bindsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    bindsFrame:SetBackdropColor(0, 0, 0, 0.6)
    bindsFrame:SetMovable(true)
    bindsFrame:EnableMouse(true)
    bindsFrame:RegisterForDrag("LeftButton")
    bindsFrame:SetScript("OnDragStart", bindsFrame.StartMoving)
    bindsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveBindsWindowPosition(self)
    end)

    ApplySavedBindsWindowPosition(bindsFrame)

    bindsIconContainer = CreateFrame("Frame", nil, bindsFrame)
    bindsIconContainer:SetPoint("TOPLEFT", BINDS_WINDOW_PADDING, -BINDS_WINDOW_PADDING)
    bindsIconContainer:SetSize(1, 1)

    return bindsFrame
end

local function UpdateBindsWindow(log)
    if not bindsFrame then
        return
    end

    local iconFiles = GetAppliedBindIconFiles(log)
    local iconCount = iconFiles and #iconFiles or 0
    local displayCount = iconCount > 0 and iconCount or 1

    local width = BINDS_WINDOW_PADDING * 2
        + (displayCount * BINDS_ICON_SIZE)
        + ((displayCount - 1) * BINDS_ICON_PADDING)
    local height = BINDS_WINDOW_PADDING * 2 + BINDS_ICON_SIZE

    bindsFrame:SetSize(width, height)

    bindsIconContainer:SetSize(width - BINDS_WINDOW_PADDING * 2, BINDS_ICON_SIZE)

    for i, fileName in ipairs(iconFiles or {}) do
        local tex = bindsIconTextures[i]
        if not tex then
            tex = bindsIconContainer:CreateTexture(nil, "ARTWORK")
            bindsIconTextures[i] = tex
        end
        tex:ClearAllPoints()
        tex:SetPoint("LEFT", bindsIconContainer, "LEFT", (i - 1) * (BINDS_ICON_SIZE + BINDS_ICON_PADDING), 0)
        tex:SetSize(BINDS_ICON_SIZE, BINDS_ICON_SIZE)
        tex:SetTexture(BuildControlIconPath(fileName))
        tex:Show()
    end

    for i = iconCount + 1, #bindsIconTextures do
        bindsIconTextures[i]:Hide()
    end
end

local function ProcessLogUpdates()
    if not isKitten then
        return
    end

    local log = GetBehaviorLog()
    if type(log) ~= "table" then
        return
    end

    if not logInitialized then
        lastLogSize = #log
        logInitialized = true
        UpdateBindsWindow(log)
        return
    end

    local logSize = #log
    if logSize > lastLogSize then
        for i = lastLogSize + 1, logSize do
            local entry = log[i]
            local iconFile = GetAppliedIconForEntry(entry)
            if iconFile then
                ShowPopup(iconFile)
            end
        end
        lastLogSize = logSize
        UpdateBindsWindow(log)
    else
        UpdateBindsWindow(log)
    end
end

local function StartTicker()
    if updateTicker then return end
    updateTicker = C_Timer.NewTicker(1.0, ProcessLogUpdates)
end

local function StopTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

local function RefreshKittenState()
    local owner = GetOwnerFromNote()
    isKitten = owner and owner ~= ""
    if isKitten then
        EnsureBindsWindow()
        bindsFrame:Show()
        StartTicker()
        ProcessLogUpdates()
    else
        StopTicker()
        if bindsFrame then
            bindsFrame:Hide()
        end
        if popupFrame then
            popupFrame:Hide()
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GUILD_ROSTER_UPDATE")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1.0, RefreshKittenState)
    elseif event == "GUILD_ROSTER_UPDATE" then
        RefreshKittenState()
    end
end)
