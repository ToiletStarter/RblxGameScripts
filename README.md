# Perimeter Zero ESP

A read-only Perimeter Zero observer built around EasyESP and EasyUI Style 2.
The menu is hidden on startup so the observer can run without blocking the game.
Press RightShift to open the Style 2 controls.

## Manual load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/RblxGameScripts/refs/heads/main/perimeter_zero_esp.luau"))()
```

The script fetches its bundled libraries from this repository and falls back to executor workspace copies when available.

## Included visuals

- Player and NPC boxes, names, health, distance, visibility checks, radar, off-screen arrows, optional tracers, skeletons, chams, and player list
- Held weapon name, ammo type, visible magazine count, magazine maximum, reload state, fire mode, damage, penetration, and durability when the game exposes those fields
- Reserve ammo when a player's replicated `AmmoStorage` exposes it; otherwise the value remains `unknown`
- Dropped-item markers sourced from `Workspace.SPH_Workspace.Drops` and classified through the game's `ReplicatedStorage.ToolsStorage` catalog
- Container and corpse markers with loot state, cooldown, prompt lock state, and corpse owner when available
- Extraction markers for all live points with state, item-required status, extraction time, and distance
- A nearest-extraction HUD line for the closest point
- Interactable markers backed by actual workspace `ProximityPrompt` instances
- Future-ready markers for `RadiationZones`, `AirdropPositions`, and `LockedRooms` when those folders populate
- `getgenv().__PZ_ESP.snapshot()` and `getgenv().__PZ_ESP.unload()` lifecycle functions

## Controls

RightShift opens the hidden Style 2 controls. The Players window controls player and NPC visuals. The World window controls drops, containers, extractions, interactables, special world markers, and the nearest-extraction HUD. The Status window exposes passive telemetry, prompt-cache refresh, and unload.

## Read-only boundary

This script does not fire remotes, install hooks, synthesize input, change movement, change weapon state, pick up loot, or mutate world state. It reports client-visible values only. A missing client-visible value is shown as unknown rather than inferred.

## Unload

```lua
local g = (getgenv and getgenv()) or shared or _G
if g.__PZ_ESP and g.__PZ_ESP.unload then
    g.__PZ_ESP.unload()
end
```

## Dependencies

The bundled libraries are credited to the maintained EasyESP and EasyUI Style 2 sources in `ToiletStarter/CantStopMakingReposForThis`.
