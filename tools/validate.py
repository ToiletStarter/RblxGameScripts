from pathlib import Path

root = Path(__file__).resolve().parents[1]
required = [
    root / "steal_or_die_observer.luau",
    root / "perimeter_zero_esp.luau",
    root / "libs" / "EasyESP.luau",
    root / "libs" / "EasyUi_style_2.luau",
    root / "tools" / "test_features.py",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing required file: {path}")

for script_name, slot in [("steal_or_die_observer.luau", "__SOD_OBSERVER"), ("perimeter_zero_esp.luau", "__PZ_ESP")]:
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
    if slot not in source or "refs/heads/main/" not in source or "libs/" not in source:
        raise SystemExit(f"{script_name} loader or lifecycle marker missing")

print("validation passed")
