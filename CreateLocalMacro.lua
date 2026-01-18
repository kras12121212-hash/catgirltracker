-- CatOnlyMacro.lua
-- Creates/updates ONE GENERAL macro whose body contains ONLY:
--/use Cat Carrier (Cornish Rex)--
-- /use Cat Carrier (...)
-- …for the common Vanilla/TBC cat carriers.
--
-- No #showtooltip, no /click, no secure buttons, nothing else.
-- Lots of debug so you can see exactly what got written.

local PFX = "|cffffcc00[CatOnlyMacro]:|r "
local function dprint(...) print(PFX .. string.join(" ", tostringall(...))) end

local MACRO_NAME = "CatNya"
local ICON = "INV_Misc_QuestionMark"

-- Common Vanilla/TBC cat carriers (English names).
-- Add/remove lines as you like.
local CAT_CARRIERS = {
  "Cat Carrier (Cornish Rex)",
  "Cat Carrier (Siamese)",
  "Cat Carrier (Orange Tabby)",
  "Cat Carrier (Silver Tabby)",
  "Cat Carrier (Black Tabby)",
  "Cat Carrier (Bombay)",
  "Cat Carrier (White Kitten)",
}

local function BuildMacroBody()
  local lines = {}
  for _, itemName in ipairs(CAT_CARRIERS) do
    lines[#lines + 1] = "/use " .. itemName
  end
  return table.concat(lines, "\n")
end

local function DumpMacroCounts()
  local g, c = GetNumMacros()
  dprint("GetNumMacros => general:", g, "char:", c,
    "MAX_ACCOUNT_MACROS:", tostring(_G.MAX_ACCOUNT_MACROS),
    "MAX_CHARACTER_MACROS:", tostring(_G.MAX_CHARACTER_MACROS))
  return g, c
end

local function EnsureGeneralMacro()
  dprint("EnsureGeneralMacro() InCombatLockdown:", InCombatLockdown() and "YES" or "NO")
  if InCombatLockdown() then
    dprint("Blocked: cannot CreateMacro/EditMacro in combat. Will retry after combat.")
    return false
  end

  DumpMacroCounts()

  local body = BuildMacroBody()
  dprint("Desired macro body length:", tostring(body:len()))
  dprint("Desired macro body:\n" .. body)

  local idx = GetMacroIndexByName(MACRO_NAME)
  dprint("GetMacroIndexByName('" .. MACRO_NAME .. "') =>", tostring(idx))

  local ok, ret = pcall(function()
    if idx and idx > 0 then
      EditMacro(idx, MACRO_NAME, ICON, body)
      return idx
    else
      -- nil => GENERAL macro (shows under General Macros tab)
      return CreateMacro(MACRO_NAME, ICON, body, nil)
    end
  end)

  dprint("Create/Edit pcall ok:", tostring(ok), "ret:", tostring(ret))

  local idx2 = GetMacroIndexByName(MACRO_NAME)
  dprint("Search after => idx:", tostring(idx2))
  if idx2 and idx2 > 0 then
    local n, ic, b = GetMacroInfo(idx2)
    dprint("Readback name/icon:", tostring(n), tostring(ic))
    dprint("Readback body length:", b and tostring(b:len()) or "<nil>")
    dprint("Readback body:\n" .. (b or "<nil>"))
    dprint("SUCCESS: Open /macro -> General Macros -> '" .. MACRO_NAME .. "'")
    return true
  end

  dprint("FAILED: macro not found after Create/Edit.")
  dprint("Most likely causes: general macro slots full, or API blocked.")
  return false
end

-- Run on login (and retry after combat if needed)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
  dprint("Event:", event)
  if event == "PLAYER_LOGIN" then
    EnsureGeneralMacro()
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- retry if it failed earlier due to combat lockdown
    EnsureGeneralMacro()
  end
end)

dprint("Loaded CatOnlyMacro.lua")
