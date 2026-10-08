# OctoMapReveal

World map reveal that matches the OctoWoW client: every unexplored area shows
in the right place, including Moonwhisper Coast and the other new zones and
subzones.

It is not a reveal addon by itself. It gives the reveal module you already use
the client's own list of map overlays:

- **ShaguTweaks-extras** — "Reveal World Map" (the one with the *Reveal
  Unexplored* checkbox on the map)
- **ShaguTweaks-mods** — "WorldMap Reveal"

Turn on one of those; OctoMapReveal does the rest. Running both at once makes
them draw over each other, and the map checkbox stops working. pfUI's map
reveal is not covered: it keeps its table inside pfUI's own environment.

## Why

OctoWoW's client (`patch-4.mpq`) redraws every world map overlay — 707 of them
on 53 maps. The reveal modules ship hardcoded tables written for older
clients. On this client:

- every map drew its overlays at the wrong size and position,
- 29 tile requests fell back to leftover 1.12 art, so redrawn zones got a
  patchwork of old and new,
- 45 overlays were missing: all 17 on Moonwhisper Coast, and new subzones such
  as Sparkwater Port, Ruins of Zul'Rasaz and the Ironforge Airfields.

`Overlays.lua` is generated from the client's own `WorldMapOverlay.dbc`, the
same table the game uses to draw the areas you have explored, so the two always
line up.

## Install

Put this folder in `Interface\AddOns` as `OctoMapReveal` (or
`git clone https://github.com/Salahaja/OctoMapReveal`), enable it, and enable
one reveal module.

## After a client patch

If the client's map changes, regenerate the table. WoW has to be closed — it
locks its archives.

```
set ELECTRON_RUN_AS_NODE=1
electron tools/dbcdump.js "<WoW>\Data" WorldMapOverlay > tools/data/WorldMapOverlay.json
electron tools/dbcdump.js "<WoW>\Data" WorldMapArea > tools/data/WorldMapArea.json
python tools/build.py
lua tools/test_reveal.lua "<WoW>\Interface\AddOns" both fix
```

`dbcdump.js` and `mpqget.js` read the archives with
[stormlib-node](https://www.npmjs.com/package/stormlib-node) built for
Electron's ABI; point `STORMLIB_NODE` at it. The newest archive carrying a file
wins, in the client's order (lettered patches, then numbered, then
`patch.MPQ`, then the base archives).

`test_reveal.lua` loads the real ShaguTweaks modules against a stubbed world
map with half of every map explored, and checks each drawn tile against what
the game itself would draw. `fix` / `nofix` runs it with and without this
addon (`extras`, `mods` or `both` picks the modules).

## Credits

Shagu, for ShaguTweaks, pfUI and the reveal code these tables feed. MIT, see
`LICENSE`.
