from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / "voxel_esp.luau").read_text(encoding="utf-8")
ui = (root / "libs" / "EasyUi_style_2.luau").read_text(encoding="utf-8")

checks = [
    ("voxel consumer exists", (root / "voxel_esp.luau").is_file()),
    ("session lifecycle exists", all(value in source for value in ["__VOXEL_ESP_V1", "function session.snapshot", "function session.unload", "VOXEL_ESP_GUI"])),
    ("voxel roots are mapped", all(value in source for value in ["Interactable", "PickUps", "Containers", "ExfilFlare", "Airdrops", "Zombies"])),
    ("event-backed caches exist", all(value in source for value in ["ChildAdded", "ChildRemoved", "cacheList", "selectedCache"])),
    ("player visuals are enabled by default", all(value in source for value in ["players = true", "boxes = true", "names = true", "health = true", "arrows = true"])),
    ("world clutter is opt-in", all(value in source for value in ["world = false", "loot = false", "containers = false", "airdrops = false"])),
    ("two-column UI layout exists", source.count(":Grid(2)") >= 8),
    ("per-channel player ranges exist", all(value in source for value in ["playerBoxRange", "playerNameRange", "playerHealthRange", "playerDistanceRange", "playerSkeletonRange", "playerTracerRange", "playerArrowRange"])),
    ("loot categories are separate", all(value in source for value in ["lootWeapons", "lootAmmo", "lootMedical", "lootFood", "lootDropped", "lootOther"])),
    ("nearest-first budgets exist", all(value in source for value in ["lootLimit", "worldLimit", "table.sort(ranked", "return a.distance < b.distance"])),
    ("config persistence exists", all(value in source for value in ["voxel_esp", "autoload.txt", "version = 1", "saveConfig", "setAutoload"])),
    ("live status exists", all(value in source for value in ["VOXEL_ESP_LOAD", "getStats", "Read-only client-visible ESP"])),
    ("fullbright is opt-in and restorable", all(value in source for value in ["fullbright = false", "function applyFullbright", "function restoreLighting", "GetPropertyChangedSignal(property)", "localAppearanceOverrides"])),
    ("passive boundary", all(token not in source for token in ["FireServer", "InvokeServer", "hookmetamethod", "hookfunction", "keypress", "mouse1click", "mousemoverel", "WalkSpeed =", "JumpPower =", "CFrame ="])),
    ("drag uses a target", all(value in ui for value in ["dragTarget", "RunService.RenderStepped", "math.clamp(dt * 18"])),
    ("drag does not tween window position", "tween(frame, DRAG, { Position" not in ui),
    ("drag visibility does not alpha tween", "tween(frame, SPRING, { Position = position, BackgroundTransparency" not in ui and "tween(frame, QUICK, { Position = UDim2.fromOffset(position.X.Offset, position.Y.Offset + 6)" not in ui),
    ("platform button tint is disabled", ui.count("AutoButtonColor = false") >= 17),
]

failed = [name for name, passed in checks if not passed]
if failed:
    raise SystemExit("voxel ESP checks failed: " + ", ".join(failed))

print(f"voxel ESP checks passed: {len(checks)}")
