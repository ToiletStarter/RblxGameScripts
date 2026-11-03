from pathlib import Path

root = Path(__file__).resolve().parents[1]
required = [
    root / "perimeter_zero_esp.luau",
    root / "libs" / "EasyESP.luau",
    root / "libs" / "EasyUi_style_2.luau",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing required file: {path}")

source = (root / "perimeter_zero_esp.luau").read_text(encoding="utf-8")
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
    raise SystemExit("forbidden tokens: " + ", ".join(found))

if "__PZ_ESP" not in source or "refs/heads/main/" not in source or "libs/" not in source:
    raise SystemExit("loader or lifecycle marker missing")

print("validation passed")
