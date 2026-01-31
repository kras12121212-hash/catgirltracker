-- Central configuration for Kitten Heat tracking.
CCT_HeatConfig = CCT_HeatConfig or {}
local cfg = CCT_HeatConfig

cfg.decay = cfg.decay or {}
if cfg.decay.totalSeconds == nil then
    cfg.decay.totalSeconds = 20 * 60
end
if cfg.decay.ratio100to10 == nil then
    cfg.decay.ratio100to10 = 5
end

cfg.updateInterval = cfg.updateInterval or 0.25
cfg.syncIntervalSeconds = cfg.syncIntervalSeconds or 10
cfg.syncMinDelta = cfg.syncMinDelta or 1

cfg.bar = cfg.bar or {}
cfg.bar.width = cfg.bar.width or 240
cfg.bar.height = cfg.bar.height or 18
cfg.bar.texture = cfg.bar.texture or "Interface\\TARGETINGFRAME\\UI-StatusBar"
cfg.bar.font = cfg.bar.font or "GameFontHighlightSmall"
cfg.bar.locked = cfg.bar.locked or false

cfg.colors = cfg.colors or {}
cfg.colors.low = cfg.colors.low or { 0.0, 0.45, 1.0 }
cfg.colors.mid = cfg.colors.mid or { 1.0, 0.35, 0.75 }
cfg.colors.high = cfg.colors.high or { 1.0, 0.0, 0.0 }

cfg.orgasm = cfg.orgasm or {}
cfg.orgasm.texture = cfg.orgasm.texture or "Interface\\AddOns\\CatgirlTracker\\Textures\\orgasm.toc"
cfg.orgasm.flashDuration = cfg.orgasm.flashDuration or 0.6
cfg.orgasm.alpha = cfg.orgasm.alpha or 0.9

-- Controls that add heat while active.
-- intervalSeconds: how often heat is added while the control is active.
-- heat: how much to add each interval.
if cfg.controls == nil then
    cfg.controls = {
        { key = "heels_maid", label = "Maid Heels", event = "KittenHeels", stateField = "state", activeValues = { "maid" }, intervalSeconds = 60, heat = 2 },
        { key = "heels_high", label = "High Heels", event = "KittenHeels", stateField = "state", activeValues = { "high" }, intervalSeconds = 60, heat = 3 },
        { key = "heels_ballet", label = "Ballet Boots", event = "KittenHeels", stateField = "state", activeValues = { "ballet" }, intervalSeconds = 60, heat = 4 },

        { key = "mittens", label = "Paw Mittens", event = "PawMittens", stateField = "state", inactiveValues = { "removed", "none" }, intervalSeconds = 90, heat = 1 },
        { key = "gag", label = "Gag", event = "KittenGag", stateField = "Gagstate", inactiveValues = { "none", "UnGag" }, intervalSeconds = 90, heat = 1 },
        { key = "blindfold", label = "Blindfold", event = "KittenBlindfold", stateField = "BlindfoldState", inactiveValues = { "remove", "none" }, intervalSeconds = 90, heat = 1 },
        { key = "earmuffs_kitten", label = "Kitten Earmuffs", event = "KittenEarmuffs", stateField = "state", activeValues = { "KittenEarmuffs" }, intervalSeconds = 120, heat = 1 },
        { key = "earmuffs_heavy", label = "Heavy Earmuffs", event = "KittenEarmuffs", stateField = "state", activeValues = { "HeavyEarmuffs" }, intervalSeconds = 120, heat = 2 },

        { key = "bell", label = "Bell", event = "BellState", stateField = "state", activeWhenTrue = true, intervalSeconds = 180, heat = 1 },
        { key = "tailbell", label = "Tail Bell", event = "TailBellState", stateField = "state", activeWhenTrue = true, intervalSeconds = 180, heat = 1 },
        { key = "leash", label = "Leash", eventActive = "KittenLeash", eventInactive = "KittenUnleash", intervalSeconds = 60, heat = 2 },
    }
end
