from pathlib import Path

root = Path(__file__).resolve().parents[1]
required = [
    root / "Hush" / "hush.luau",
    root / "tools" / "test_hush.py",
    root / "tools" / "hush_mock.luau",
    root / "tools" / "hush_tests.luau",
    root / "steal_or_die_observer.luau",
    root / "perimeter_zero_esp.luau",
    root / "blind_accessibility.luau",
    root / "libs" / "EasyESP.luau",
    root / "libs" / "EasyUi_style_2.luau",
    root / "tools" / "test_features.py",
    root / "tools" / "blind_screen_reader.py",
    root / "average_day_observer.luau",
    root / "chicago_wars_observer.luau",
    root / "world_esp.luau",
    root / "tools" / "test_world_esp.py",
    root / "voxel_esp.luau",
    root / "tools" / "test_voxel_esp.py",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing required file: {path}")

for script_name, slot in [("steal_or_die_observer.luau", "__SOD_OBSERVER"), ("perimeter_zero_esp.luau", "__PZ_ESP"), ("blind_accessibility.luau", "__BLIND_ACCESSIBILITY"), ("average_day_observer.luau", "__AVERAGE_DAY_OBSERVER"), ("chicago_wars_observer.luau", "__CHICAGO_WARS_OBSERVER"), ("world_esp.luau", "__WORLD_ESP"), ("voxel_esp.luau", "__VOXEL_ESP_V1")]:
    source = (root / script_name).read_text(encoding="utf-8")
    forbidden = [
        "FireServer",
        "InvokeServer",
        "hookmetamethod",
        "hookfunction",
        "getrawmetatable",
        "setreadonly",
        "sethiddenproperty",
        "keypress",
        "mouse1click",
        "mousemoverel",
        "WalkSpeed =",
        "JumpPower =",
    ]
    found = [token for token in forbidden if token in source]
    if found:
        raise SystemExit(f"{script_name} forbidden tokens: " + ", ".join(found))
    if script_name == "blind_accessibility.luau":
        if slot not in source or "full_game_dump.json" not in source or "blind_accessibility_state.json" not in source:
            raise SystemExit(f"{script_name} lifecycle or export marker missing")
        continue
    if slot not in source or "refs/heads/main/" not in source or "libs/" not in source:
        raise SystemExit(f"{script_name} loader or lifecycle marker missing")

print("validation passed")
