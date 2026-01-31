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

-- Submissiveness heat flip configuration.
-- If the kitten's submissiveness is at or above a threshold, negative heat deltas that are
-- not more negative than the mapped value are flipped to positive heat.
-- Example: [70] = -11 means at submissiveness >= 70, deltas from -11..-1 become +11..+1.
if cfg.submissivenessHeatFlip == nil then
    cfg.submissivenessHeatFlip = {
        [10] = -1,
        [20] = -2,
        [30] = -3,
        [40] = -5,
        [50] = -7,
        [60] = -10,
        [70] = -11,
        [80] = -13,
        [90] = -15,
        [100] = -20,
    }
end

-- Toy heat configuration.
-- base: heat added while the toy is applied.
-- vibe/inflate: per-stage heat while vibration/inflation is active (stage 1-5).
-- shock: one-time heat change applied on shock (can be negative).
if cfg.toys == nil then
    cfg.toys = {
        dildo = {
            label = "Dildo",
            base = { intervalSeconds = 90, heat = 1 },
            vibe = {
                { intervalSeconds = 30, heat = 1 },
                { intervalSeconds = 25, heat = 2 },
                { intervalSeconds = 20, heat = 3 },
                { intervalSeconds = 15, heat = 4 },
                { intervalSeconds = 10, heat = 5 },
            },
            shock = { -5, -10, -15 },
        },
        inflatable_butplug = {
            label = "Inflatable Butplug",
            base = { intervalSeconds = 90, heat = 1 },
            inflate = {
                { intervalSeconds = 60, heat = 1 },
                { intervalSeconds = 50, heat = 2 },
                { intervalSeconds = 40, heat = 3 },
                { intervalSeconds = 30, heat = 4 },
                { intervalSeconds = 20, heat = 5 },
            },
        },
        inflatable_dildo = {
            label = "Inflatable Dildo",
            base = { intervalSeconds = 90, heat = 1 },
            inflate = {
                { intervalSeconds = 60, heat = 1 },
                { intervalSeconds = 50, heat = 2 },
                { intervalSeconds = 40, heat = 3 },
                { intervalSeconds = 30, heat = 4 },
                { intervalSeconds = 20, heat = 5 },
            },
        },
        small_butplug = {
            label = "Small Butplug",
            base = { intervalSeconds = 90, heat = 1 },
        },
        large_butplug = {
            label = "Large Butplug",
            base = { intervalSeconds = 90, heat = 1 },
        },
        taill_butplug = {
            label = "Taill Butplug",
            base = { intervalSeconds = 90, heat = 1 },
        },
        vibes_pussy = {
            label = "Vibes Pussy",
            base = { intervalSeconds = 90, heat = 1 },
            vibe = {
                { intervalSeconds = 30, heat = 1 },
                { intervalSeconds = 25, heat = 2 },
                { intervalSeconds = 20, heat = 3 },
                { intervalSeconds = 15, heat = 4 },
                { intervalSeconds = 10, heat = 5 },
            },
        },
        vibes_nipples = {
            label = "Vibes Nipples",
            base = { intervalSeconds = 90, heat = 1 },
            vibe = {
                { intervalSeconds = 30, heat = 1 },
                { intervalSeconds = 25, heat = 2 },
                { intervalSeconds = 20, heat = 3 },
                { intervalSeconds = 15, heat = 4 },
                { intervalSeconds = 10, heat = 5 },
            },
        },
        vibes_ears = {
            label = "Vibes Ears",
            base = { intervalSeconds = 90, heat = 1 },
            vibe = {
                { intervalSeconds = 30, heat = 1 },
                { intervalSeconds = 25, heat = 2 },
                { intervalSeconds = 20, heat = 3 },
                { intervalSeconds = 15, heat = 4 },
                { intervalSeconds = 10, heat = 5 },
            },
            shock = { -5, -10, -15 },
        },
        nipple_piercings = {
            label = "Nipple Piercings",
            base = { intervalSeconds = 90, heat = 1 },
            vibe = {
                { intervalSeconds = 30, heat = 1 },
                { intervalSeconds = 25, heat = 2 },
                { intervalSeconds = 20, heat = 3 },
                { intervalSeconds = 15, heat = 4 },
                { intervalSeconds = 10, heat = 5 },
            },
            shock = { -5, -10, -15 },
        },
        ear_piercings = {
            label = "Ear Piercings",
            base = { intervalSeconds = 90, heat = 1 },
            vibe = {
                { intervalSeconds = 30, heat = 1 },
                { intervalSeconds = 25, heat = 2 },
                { intervalSeconds = 20, heat = 3 },
                { intervalSeconds = 15, heat = 4 },
                { intervalSeconds = 10, heat = 5 },
            },
            shock = { -5, -10, -15 },
        },
        pussy_lipps_piercings = {
            label = "Pussy Lipps Piercings",
            base = { intervalSeconds = 90, heat = 1 },
            vibe = {
                { intervalSeconds = 30, heat = 1 },
                { intervalSeconds = 25, heat = 2 },
                { intervalSeconds = 20, heat = 3 },
                { intervalSeconds = 15, heat = 4 },
                { intervalSeconds = 10, heat = 5 },
            },
            shock = { -5, -10, -15 },
        },
    }
end

-- Discipline heat configuration.
-- heat: one-time heat change when a discipline action is used (strength 1-N).
if cfg.discipline == nil then
    cfg.discipline = {
        spank_hand = { label = "Spank Hand", heat = { 1, 2, 3, 4, 5 } },
        pinch = { label = "Pinch", heat = { 1, 2, 3 } },
        vibrating_wand = { label = "Vibrating Wand", heat = { 1, 2, 3 } },
        shock_wand = { label = "Shock Wand", heat = { 1, 2, 3, 4, 5 } },
        crop = { label = "Crop", heat = { 1, 2, 3 } },
        paddle = { label = "Paddle", heat = { 1, 2, 3 } },
        heart_crop = { label = "Heart Crop", heat = { 1, 2, 3 } },
        whip = { label = "Whip", heat = { 1, 2, 3 } },
    }
end

local function ToyEventName(id)
    return "Toy_" .. id
end

local function ToyVibeEventName(id)
    return "Toy_" .. id .. "_Vibe"
end

local function ToyInflateEventName(id)
    return "Toy_" .. id .. "_Inflate"
end

local function AddToyControls(list)
    if type(cfg.toys) ~= "table" then
        return
    end
    for id, toy in pairs(cfg.toys) do
        if type(toy) == "table" then
            if toy.base then
                table.insert(list, {
                    key = "toy_" .. id .. "_base",
                    label = toy.label or ("Toy " .. id),
                    event = ToyEventName(id),
                    activeWhenTrue = true,
                    intervalSeconds = toy.base.intervalSeconds,
                    heat = toy.base.heat,
                })
            end
            if type(toy.vibe) == "table" then
                for stage, def in ipairs(toy.vibe) do
                    table.insert(list, {
                        key = "toy_" .. id .. "_vibe_" .. stage,
                        label = (toy.label or ("Toy " .. id)) .. " Vibe " .. stage,
                        event = ToyVibeEventName(id),
                        activeValues = { stage },
                        intervalSeconds = def.intervalSeconds,
                        heat = def.heat,
                    })
                end
            end
            if type(toy.inflate) == "table" then
                for stage, def in ipairs(toy.inflate) do
                    table.insert(list, {
                        key = "toy_" .. id .. "_inflate_" .. stage,
                        label = (toy.label or ("Toy " .. id)) .. " Inflate " .. stage,
                        event = ToyInflateEventName(id),
                        activeValues = { stage },
                        intervalSeconds = def.intervalSeconds,
                        heat = def.heat,
                    })
                end
            end
        end
    end
end

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
    AddToyControls(cfg.controls)
end
