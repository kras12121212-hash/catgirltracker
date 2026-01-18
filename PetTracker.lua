local npcFound = false
local function OnAddonActionForbidden(addonName, functionName) -- gets only called if a error was thrown by target unit cat
	if (addonName == 'CatgirlTracker') then
		npcFound = true
	end
end
local unitTargetFrame = CreateFrame("FRAME");

unitTargetFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")  --blizzar internal call that trggers once my addon throws a interface error
unitTargetFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_ACTION_FORBIDDEN" then
		OnAddonActionForbidden(...)
	end
end)

local function ShowBigMessage(msg) -- Call for big message
    -- Make it BIG
    RaidWarningFrame:SetScale(2.0)  -- Double the size

    -- Set custom font size for both slots
    RaidWarningFrameSlot1:SetFont("Fonts\\FRIZQT__.TTF", 40, "OUTLINE")
    RaidWarningFrameSlot2:SetFont("Fonts\\FRIZQT__.TTF", 40, "OUTLINE")

    -- Repeatedly show the message every 5 seconds for 20 seconds
    local totalTime = 20
    local interval = 5
    local elapsed = 0

    -- First show immediately
    RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])

    C_Timer.NewTicker(interval, function()
        elapsed = elapsed + interval
        if elapsed < totalTime then
            RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
        end
    end)
end


local function CloseErrorPopUp() --function to suppress error popup
	if (StaticPopup_HasDisplayedFrames()) then
        for idx = STATICPOPUP_NUMDIALOGS,1,-1 do
            local dialog = _G["StaticPopup"..idx]
            local OnCancel = dialog.OnCancel;
			local noCancelOnEscape = dialog.noCancelOnEscape;
			if ( OnCancel and not noCancelOnEscape) then
				OnCancel(dialog);
			end
			StaticPopupSpecial_Hide(dialog)
        end
    end
end

-- list of cats to check for
local catNames = {
    "Black Tabby",
    "Siamese",
    "White Kitten",
    "Silver Tabby",
    "Bombay",
    "Cornish Rex",
    "Orange Tabby"
}

local RCat = false
local FCat = false

local function WarnFirst()
    if (RCat) then
    FCat = true -- failed cat sets to true and it stops checking for this session since the cat was forgoten
    ShowBigMessage("You forgot you Cat -20 CatGirlPoints")
    else
    RCat = true -- sets that a reminder was displayed for cat next pass without cat is failure
    ShowBigMessage("Think of your Cat nya!!, You have 5 Minutes")
    end
end

local function checkkitten()
    anycatfound = false -- we set that no cat was found yet before we loop trough all possible cats
    for _, catName in ipairs(catNames) do
        MuteSoundFile(567490)
        MuteSoundFile(567464)
        npcFound = false
        TargetUnit(catName)
        if (npcFound) then
            anycatfound = true -- if any of the cats hits that point this gets set to true so warn first never is executed
            -- Hide error message
            -- WATCH OUT! This might produce taint
            print("|cffffcc00[CatGirlTracker]:|r Good Kitty your cat was found.")
            CloseErrorPopUp()
            UnmuteSoundFile(567490)
            UnmuteSoundFile(567464)
            RCat = false -- we reset the remind cat function if a cat was found at some point 
        else
        -- print("|cffffcc00[CatGirlTracker]:|r we are in cat check false loop")
        end
	end
    if not anycatfound then
    WarnFirst()
    end
end

function isPlayerDead() -- we only check for cat if player is allive 
    return UnitIsDeadOrGhost("player")
end


-- ctimer means first check for cat is afther 5 minutes
-- then there will be a warning and they have another 5 minutes to spawn there cat before they get punished

C_Timer.NewTicker(300, function() -- check every 5 minutes
    if not isPlayerDead() and not FCat then
        checkkitten()
    end
end)
print("CatgirlPetTracker loaded!.")