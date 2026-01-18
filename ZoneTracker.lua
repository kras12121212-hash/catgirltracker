local zoneFrame = CreateFrame("Frame")
local lastZone = nil
local kittyname = UnitName("player")


CatgirlZoneDB = CatgirlZoneDB or {}
CatgirlZoneDB.ZoneLog = CatgirlZoneDB.ZoneLog or {}
CatgirlZoneDB.ZoneLog[kittyname] = CatgirlZoneDB.ZoneLog[kittyname] or {}

local function logZone()
    local zone = GetRealZoneText() or GetZoneText()
    local _, instanceType = IsInInstance()

    if zone and zone ~= "" and zone ~= lastZone then
        lastZone = zone
        table.insert(CatgirlZoneDB.ZoneLog[kittyname], {
            timestamp = date("%Y-%m-%d %H:%M"),
            zone = zone,
            instanceType = instanceType or "none",
            synced = 0
        })
        print("|cff33ff99CatgirlTracker:|r Entered zone: " .. zone)
    end
end

local delayFrame = CreateFrame("Frame")
delayFrame:Hide()
delayFrame:SetScript("OnUpdate", function(self, elapsed)
    self.timer = self.timer - elapsed
    if self.timer <= 0 then
        self:Hide()
        logZone()
    end
end)

local function delayedLog(delay)
    delayFrame.timer = delay or 1
    delayFrame:Show()
end

zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

zoneFrame:SetScript("OnEvent", function(_, event)
    delayedLog(1)
end)

print("Catgirl ZoneTracker loaded.")
