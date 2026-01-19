local addonName = "CatGirlControlCenter"
local f = CreateFrame("Frame")
local kittyname = UnitName("player"):match("^[^%-]+") -- short name only

SLASH_CGCC1 = "/cgcc"

local function RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Find who you're the owner of (based on officer note format: owner=Holykitten,...)
local function GetAssignedCatgirl()
    RequestGuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(i)
        if name and officerNote then
            local ownerName = officerNote:match("owner=([^,]+)")
            if ownerName and ownerName:match("^[^%-]+") == kittyname then
                return name
            end
        end
    end
    return nil
end

-- Whisper to kitten
local function WhisperToKitten(kitten, command)
    if kitten then
        SendChatMessage(command, "WHISPER", nil, kitten)
    end
end

-- Create control panel UI
local function ShowControlPanel(kitten)
    local frame = CreateFrame("Frame", "CatGirlControlPanel", UIParent, "BackdropTemplate")

    frame:SetSize(260, 700) -- Increased height
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -10)
    frame.title:SetText("🐾 Catgirl Control")

    frame.kittenName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.kittenName:SetPoint("TOP", 0, -30)
    frame.kittenName:SetText("Kitten: " .. kitten)

    local function CreateButton(label, yOffset, command)
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(180, 20)
        btn:SetPoint("TOP", 0, yOffset)
        btn:SetText(label)
        btn:SetScript("OnClick", function() WhisperToKitten(kitten, command) end)
    end

    local function CreateDelayRow(yOffset, label, msgTemplate)
        local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        box:SetSize(25, 20)
        box:SetPoint("TOPLEFT", 20, yOffset)
        box:SetAutoFocus(false)
        box:SetText("1.5")

        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(160, 20)
        btn:SetPoint("TOPLEFT", box, "TOPRIGHT", 10, 0)
        btn:SetText(label)

        btn:SetScript("OnClick", function()
            local val = tonumber(box:GetText())
            if val and val > 0 then
                local minutes = math.floor(val * 60 + 0.5)
                local msg = msgTemplate:format(val, minutes)
                WhisperToKitten(kitten, msg)
            else
                print("|cffff5555[CatGirlControlCenter]|r Invalid number.")
            end
        end)
    end

    local y = -55

    -- Leash
    CreateButton("Leash", y, "leash"); y = y - 25
    CreateButton("Unleash", y, "unleash"); y = y - 35

    -- Masks and gags
    CreateButton("Cute Kitten Mask", y, "Your owner gave you a cute~ Kitten Mask ~UwU~ It gives you an irresistible urge to Nya in every sentence."); y = y - 25
    CreateButton("Small Gag", y, "Your owner has fitted a small silken gag over your mouth. Speech is now garbled."); y = y - 25
    CreateButton("Heavy Gag", y, "Your owner has secured a heavy gag in place. You can no longer speak."); y = y - 25
    CreateButton("Kitty Mask With Gag!", y, "Your owner put a gag and a Kitten Mask on you! You must have been a really naughty cat!"); y = y - 25
    CreateButton("Ungag", y, "Your gag has been removed by your owner. You can speak freely again."); y = y - 25

    -- Remove gag in X hours
    CreateDelayRow(y, "Remove in X Hours", "Your owner set your gag to unlock in %.1f hours (%d) minutes."); y = y - 35

    -- Earmuffs
    CreateButton("Kitten Earmuffs", y, "Your owner put kitten earmuffs on you."); y = y - 25
    CreateButton("Heavy Earmuffs", y, "Your owner put heavy earmuffs on you, Nyo!!!"); y = y - 25
    CreateButton("Remove Earmuffs", y, "Your owner removed your earmuffs. Puhhh~"); y = y - 25

    -- Remove earmuffs in X hours
    CreateDelayRow(y, "Remove in X Hours", "Your owner set your earmuffs to unlock in %.1f hours (%d) minutes."); y = y - 35

    -- Blindfolds
    CreateButton("Light Blindfold", y, "Your owner put a light blindfold on you."); y = y - 25
    CreateButton("Cute Kitty Blindfold", y, "Your owner put a cute kitty blindfold on you."); y = y - 25
    CreateButton("Full Blindfold", y, "Your owner put a full blindfold on you."); y = y - 25
    CreateButton("Remove Blindfold", y, "Your owner removed your blindfold."); y = y - 25

    -- Remove blindfold in X hours
    CreateDelayRow(y, "Remove in X Hours", "Your owner set your blindfold to unlock in %.1f hours (%d) minutes."); y = y - 35

    -- Bell
    CreateButton("Attach Bell", y, "You hear a soft *click* as your owner attaches a tiny bell to your collar. Every step now jingles~"); y = y - 25
    CreateButton("Remove Bell", y, "With a gentle touch, your owner removes the bell from your collar. It's quiet again... for now."); y = y - 25

    -- Remove bell in X hours
    CreateDelayRow(y, "Remove in X Hours", "Your owner set your bell to unlock in %.1f hours (%d) minutes."); y = y - 45

    -- Close
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(180, 20)
    closeBtn:SetPoint("TOP", 0, y)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
end

-- Slash command handler
SlashCmdList["CGCC"] = function()
    if not IsInGuild() then
        print("|cffff5555[CatGirlControlCenter]|r You are not in a guild.")
        return
    end

    RequestGuildRoster()
    C_Timer.After(1.0, function()
        local kitten = GetAssignedCatgirl()
        if kitten then
            ShowControlPanel(kitten)
        else
            print("|cffff5555[CatGirlControlCenter]|r You don't own a kitten yet!")
        end
    end)
end

CCT_AutoPrint("CatGirlControlCenter loaded.")
