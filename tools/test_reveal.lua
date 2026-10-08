-- Loads the real ShaguTweaks reveal modules against a stubbed 1.12 world map,
-- draws every map with about half its overlays explored, and checks each tile
-- against what the client's own WorldMapFrame_Update would draw from the DBC.
--   lua tools/test_reveal.lua <AddOns dir> <extras|mods|both> <fix|nofix>
local addons, which, fix = arg[1], arg[2], arg[3] == "fix"
coroutine = nil
mod = math.fmod
local BS = string.char(92)
local unpack = table.unpack or unpack

-- client data (also used as the ground truth)
dofile("OctoMapReveal/Overlays.lua")
local truth = OctoMapReveal_Overlays
OctoMapReveal_Overlays = nil

-- stub UI objects: any unknown method is a no-op
local function object(name)
  local o = { name = name, shown = false, points = {} }
  local methods = {
    SetWidth = function(s, w) s.w = w end, SetHeight = function(s, h) s.h = h end,
    SetTexCoord = function(s, a, b, c, d) s.tc = { a, b, c, d } end,
    ClearAllPoints = function(s) s.points = {} end,
    SetPoint = function(s, p, rel, rp, x, y)
      if type(rel) == "number" then x, y = rel, rp end
      s.points[1] = { x, y }
    end,
    SetTexture = function(s, t) s.tex = t end,
    SetVertexColor = function(s, r) s.vc = r end,
    Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
    SetScript = function(s, k, f) s[k] = f end, GetChecked = function(s) return s.checked end,
    SetChecked = function(s, c) s.checked = c end,
    RegisterEvent = function(s, e) s.events = s.events or {}; s.events[e] = true end,
    CreateTexture = function(s, n) local t = object(n); if n and n ~= "" then _G[n] = t end; return t end,
  }
  return setmetatable(o, { __index = function(t, k) return methods[k] or (string.match(k, "^%u") and function() end or nil) end })
end
local frames = {}
function CreateFrame(kind, name, parent, template)
  local f = object(name); f.parent = parent
  if name then _G[name] = f; _G[name .. "Text"] = object(name .. "Text") end
  table.insert(frames, f)
  return f
end
WorldMapFrame, WorldMapButton, WorldMapDetailFrame = object("WorldMapFrame"), object("WorldMapButton"), object("WorldMapDetailFrame")
WorldMapTooltip, GameTooltip = object("WorldMapTooltip"), object("GameTooltip")
TargetHPText, TargetHPPercText = object(), object() -- the client has Turtle's target frame
NUM_WORLDMAP_OVERLAYS = 0

-- explored state: every other overlay of each map
local current
function GetMapInfo() return current, 668, 1002 end
local function explored(map)
  local out = {}
  for i, e in ipairs(truth[map] or {}) do if math.fmod(i, 2) == 1 then table.insert(out, e) end end
  return out
end
function GetNumMapOverlays() return #explored(current) end
function GetMapOverlayInfo(i)
  local e = explored(current)[i]
  local n, w, h, x, y = string.match(e, "^([^:]+):(%d+):(%d+):(%d+):(%d+)")
  return "Interface" .. BS .. "WorldMap" .. BS .. current .. BS .. n, tonumber(w), tonumber(h), tonumber(x), tonumber(y), 0, 0
end

-- the expected tiles, by the client's own algorithm
local function tiles(map, list, bright)
  local out = {}
  for _, e in ipairs(list) do
    local n, w, h, x, y = string.match(e, "^([^:]+):(%d+):(%d+):(%d+):(%d+)")
    w, h, x, y = tonumber(w), tonumber(h), tonumber(x), tonumber(y)
    local wide, tall = math.ceil(w / 256), math.ceil(h / 256)
    for j = 1, tall do
      local ph = j < tall and 256 or (math.fmod(h, 256) == 0 and 256 or math.fmod(h, 256))
      for k = 1, wide do
        local pw = k < wide and 256 or (math.fmod(w, 256) == 0 and 256 or math.fmod(w, 256))
        local tex = "Interface" .. BS .. "WorldMap" .. BS .. map .. BS .. n .. ((j - 1) * wide + k)
        out[tex] = string.format("%dx%d@%d,%d %s", pw, ph, x + 256 * (k - 1), -(y + 256 * (j - 1)), bright and bright[n] and "lit" or "dim")
      end
    end
  end
  return out
end

-- the client's own overlay drawing (FrameXML WorldMapFrame_Update, overlay part)
function WorldMapFrame_Update()
  local count = 0
  for i = 1, GetNumMapOverlays() do
    local name, w, h, x, y = GetMapOverlayInfo(i)
    local wide, tall = math.ceil(w / 256), math.ceil(h / 256)
    for j = count + 1, count + wide * tall do
      if j > NUM_WORLDMAP_OVERLAYS then WorldMapDetailFrame:CreateTexture("WorldMapOverlay" .. j); NUM_WORLDMAP_OVERLAYS = j end
    end
    for j = 1, tall do
      for k = 1, wide do
        count = count + 1
        local t = _G["WorldMapOverlay" .. count]
        local pw = k < wide and 256 or (math.fmod(w, 256) == 0 and 256 or math.fmod(w, 256))
        local ph = j < tall and 256 or (math.fmod(h, 256) == 0 and 256 or math.fmod(h, 256))
        t:SetWidth(pw); t:SetHeight(ph); t:SetPoint("TOPLEFT", x + 256 * (k - 1), -(y + 256 * (j - 1)))
        t:SetTexture(name .. ((j - 1) * wide + k)); t:SetVertexColor(1, 1, 1, 1); t:Show()
      end
    end
  end
  for i = count + 1, NUM_WORLDMAP_OVERLAYS do _G["WorldMapOverlay" .. i]:Hide() end
end

-- ShaguTweaks core, as far as the modules need it
ShaguTweaks = { mods = {} }
ShaguTweaks.GetGlobalEnv = function() return _G end
ShaguTweaks.T = setmetatable({}, { __index = function(t, k) return k end })
ShaguTweaks.register = function(self, m) m.config = m.config or {}; ShaguTweaks.mods[m.title] = m; return m end
ShaguTweaks.hooksecurefunc = function(name, func)
  local orig = _G[name]
  _G[name] = function(a, b, c) local r = orig(a, b, c); func(a, b, c); return r end
end
string.gfind = string.gmatch

local load = function(rel) assert(loadfile(addons .. "/" .. rel))() end
if which ~= "mods" then load("ShaguTweaks-extras/mods/worldmap-reveal.lua") end
if which ~= "extras" then load("ShaguTweaks-mods/mods/worldmap-reveal.lua") end
local watcher
if fix then
  local before = #frames
  dofile("OctoMapReveal/Overlays.lua"); dofile("OctoMapReveal/OctoMapReveal.lua")
  watcher = frames[#frames]
end
-- VARIABLES_LOADED: ShaguTweaks enables the modules, then our handler runs
for _, m in pairs(ShaguTweaks.mods) do m:enable() end
if watcher then this = watcher; watcher.OnEvent() end

local bad, maps, checked = 0, 0, 0
local report = {}
for map in pairs(truth) do
  current = map
  local lit = {}
  for _, e in ipairs(explored(map)) do lit[string.match(e, "^[^:]+")] = true end
  this = WorldMapFrame
  WorldMapFrame_Update()
  local want = tiles(map, truth[map], lit)
  local got = {}
  for i = 1, NUM_WORLDMAP_OVERLAYS do
    local t = _G["WorldMapOverlay" .. i]
    if t.shown then
      local p = t.points[1] or { 0, 0 }
      got[t.tex] = string.format("%dx%d@%d,%d %s", t.w, t.h, p[1], p[2], t.vc == 1 and "lit" or "dim")
    end
  end
  local wrong = 0
  for tex, v in pairs(want) do
    checked = checked + 1
    if got[tex] ~= v then wrong = wrong + 1 end
  end
  for tex in pairs(got) do if not want[tex] then wrong = wrong + 1 end end
  if wrong > 0 then bad = bad + wrong; maps = maps + 1; table.insert(report, string.format("%s %d", map, wrong)) end
end
table.sort(report)
print(string.format("%-6s %-5s: %d of %d tiles wrong or stray on %d maps %s", which, fix and "fix" or "nofix",
  bad, checked, maps, maps > 0 and ("(" .. table.concat(report, ", ", 1, math.min(#report, 8)) .. (#report > 8 and ", ..." or "") .. ")") or ""))
os.exit(bad == 0 and 0 or 1)
