# Voxel ESP

`voxel_esp.luau` is a read-only EasyESP and EasyUI Style 2 consumer for the live Voxel client at place ID `6128781746`.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/RblxGameScripts/refs/heads/main/voxel_esp.luau"))()
```

The consumer loads local staged copies first:

- `easyesp/EasyESP.luau`
- `easyui/EasyUi_style_2.luau`
- `libs/EasyESP.luau`
- `libs/EasyUi_style_2.luau`

RightShift opens the menu. The menu starts hidden so the game view stays clear.

## Defaults

Player ESP starts enabled with boxes, names, health, distance, and off-screen arrows. World markers and loot are opt-in. Loot and container markers use nearest-first caps and independent ranges instead of putting every replicated object on screen.

The Visuals window is divided into two-column control groups. Player ranges are independent for boxes, names, health, distance, skeletons, tracers, and arrows.

## Live categories

- Players from the live Players roster
- Zombies from `Workspace.Zombies`
- Loot from `Workspace.Interactable.PickUps`
- Containers from `Workspace.Interactable.Containers`
- Exfil markers from `Workspace.ExfilFlare`
- Airdrop storage from `Workspace.Airdrops.Storage`

Loot filters are display categories derived from client-visible item names, attributes, tags, and value children. They are not server-authoritative inventory data. Container contents are not opened or inferred.

## Controls and persistence

- Right-click interactive controls for context actions
- RightShift, Insert, F6, or F7 menu binding
- Save config, reload config, enable autoload, clear autoload, and unload
- Config files live under `voxel_esp/` in the executor workspace
- The final default configuration keeps world-heavy categories disabled

## Boundary

The consumer does not invoke remotes, install hooks, synthesize input, move the character, change weapon state, or mutate the world. It only renders client-visible state and local Drawing/UI output.
