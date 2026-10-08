-- The reveal modules ship hardcoded overlay tables from older clients. On this
-- client those draw the redrawn overlays at the wrong size and place, mix in
-- leftover 1.12 tiles, and know nothing of Moonwhisper Coast. Swap their table
-- contents for the client's own (Overlays.lua, generated from the DBC).
local data = OctoMapReveal_Overlays
local filled = setmetatable({}, { __mode = "k" })

-- refill in place: the modules keep a reference to the table they were given
local function refill(t)
  if type(t) ~= "table" or t == data or filled[t] then return end
  for k in pairs(t) do t[k] = nil end
  for k, v in pairs(data) do t[k] = v end
  filled[t] = true
end

local function apply()
  -- ShaguTweaks-extras "Reveal World Map": filled at load, read on first map update
  if ShaguTweaks then refill(ShaguTweaks.MapOverlayData) end
  -- ShaguTweaks-mods "WorldMap Reveal" (assigned when the module enables;
  -- ShaguPlates sets the same global at load)
  refill(pfMapOverlayData)
end

apply()

-- ShaguTweaks enables its modules on VARIABLES_LOADED (its handler runs before
-- ours, since it loaded first); the map check covers anything enabled later
local watcher = CreateFrame("Frame", nil, WorldMapFrame)
watcher:RegisterEvent("VARIABLES_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", apply)
watcher:SetScript("OnShow", apply)
