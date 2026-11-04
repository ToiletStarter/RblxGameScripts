# Steal Or Die Observer

A read-only Steal Or Die observer built around EasyESP and EasyUI Style 2. The observer starts with its clickgui hidden so it does not cover the game. RightShift opens the controls when needed.

## Manual load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ToiletStarter/RblxGameScripts/refs/heads/main/steal_or_die_observer.luau"))()
```

The script loads local `EasyESP.luau` and `EasyUi_style_2.luau` copies first, then falls back to the repository's pinned path.

## Included visuals

- Player boxes, names, health, distance, off-screen arrows, radar, optional skeletons, tracers, and player list
- Entity identification from live `EntityKind`, `State`, `Stimulus`, `HeardByMe`, `PlayerEntity`, `Nav`, `DbgRoute`, and related client-visible attributes
- Entity HUD with state, stimulus, target when the game exposes a target field, owner, navigation text, and an observed movement trail
- Kinematic future-position preview based on the entity's current velocity; this is labeled as prediction, not server navigation
- Loot markers from `Workspace.LootItems`, `Workspace.MyLoot`, `Workspace.Corpses`, and `Workspace.Gadgets`, including item key, rarity, value, weight, XP, and spot ID when exposed
- Exit markers from live `ExitPoint` parts and lit exit signs, plus a nearest-exit HUD line
- `getgenv().__SOD_OBSERVER.snapshot()`, `rescan()`, and `unload()` lifecycle functions

## Controls

RightShift opens the hidden Style 2 controls. The Visuals window controls player, loot, exit, and entity overlays. The Entity window controls trail length, prediction time, and passive telemetry. The Status window exposes counts, nearest exit, refresh, and unload. Right-clicking a control opens its context menu with value editing, reset, and keybind assignment.

## EasyUI Style 2 context menus

Every interactive Style 2 widget supports a right-click context menu. Built-in controls include toggles, sliders, dropdowns, text inputs, buttons, colors, reset, and keybind capture. Developers can append entries with the widget's `context` option:

```lua
section:Toggle({
    text = "Players",
    default = true,
    context = function(widget, ui)
        return {
            {
                kind = "slider",
                text = "Range",
                min = 250,
                max = 6000,
                step = 250,
                suffix = "m",
                get = function()
                    return range
                end,
                set = function(value)
                    range = value
                end,
            },
            {
                kind = "button",
                text = "Rescan",
                set = function()
                    rescan()
                end,
            },
        }
    end,
})
```

Custom entries support `toggle`, `slider`, `dropdown`, `textbox` or `input`, `button`, `color`, `keybind`, `label`, and `note`. Set `keybind` on a widget or use the context menu's `Set keybind` action to bind its default activation behavior.

## Read-only boundary

This script does not fire remotes, install hooks, synthesize input, change movement, change weapon state, pick up loot, change lighting, make walls transparent, or mutate world state. Fly, noclip, fullbright, wall transparency, and similar gameplay modifications are intentionally not included. Missing client-visible target or path data is shown as `unknown`; observed trails and velocity projection are not claims about server AI.

## Unload

```lua
local g = (getgenv and getgenv()) or shared or _G
if g.__SOD_OBSERVER and g.__SOD_OBSERVER.unload then
    g.__SOD_OBSERVER.unload()
end
```

## Dependencies

The bundled libraries are credited to the maintained EasyESP and EasyUI Style 2 sources in `ToiletStarter/CantStopMakingReposForThis`. The older `perimeter_zero_esp.luau` file remains in the repository as a separate Perimeter Zero consumer.
