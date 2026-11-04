from pathlib import Path

root = Path(__file__).resolve().parents[1]
ui = (root / "libs" / "EasyUi_style_2.luau").read_text(encoding="utf-8")
esp = (root / "libs" / "EasyESP.luau").read_text(encoding="utf-8")
consumer = (root / "perimeter_zero_esp.luau").read_text(encoding="utf-8")
sod = (root / "steal_or_die_observer.luau").read_text(encoding="utf-8")
hush = (root / "Hush" / "hush_esp.luau").read_text(encoding="utf-8")

checks = [
    ("ui context menu exists", "function UI:_showContext" in ui),
    ("context menus bind every widget", "widget.opts.context ~= false" in ui and "_contextEntries" in ui),
    ("context slider control exists", "kind == \"slider\" or kind == \"range\"" in ui),
    ("context dropdown control exists", "kind == \"dropdown\"" in ui),
    ("context textbox control exists", "kind == \"textbox\" or kind == \"input\"" in ui),
    ("context keybind action exists", "Set keybind" in ui and "_setWidgetKeybind" in ui),
    ("ui is above game ui", "DisplayOrder = 2147483647" in ui),
    ("nearest ESP draws last", "return a.dist > b.dist" in esp),
    ("arrow class is gated", "if s.npc then" in esp and "self.cfg.npc.arrow.on" in esp),
    ("player arrows are separate", "playerArrows" in consumer),
    ("bot arrows are separate", "botArrows" in consumer),
    ("player name mode exists", "nameMode" in consumer),
    ("range is contextual", "rangeContext(\"Player range\"" in consumer and "kind = \"slider\"" in consumer),
    ("observer name mode exists", "nameMode" in sod),
    ("observer range is contextual", "rangeContext(\"Player range\"" in sod and "lootRange" in sod and "exitRange" in sod),
    ("monster-tag targets are supported", "CollectionService:GetTagged" in hush and "CollectionService:GetTagged" in consumer),
    ("local monster can be drawn", "model == LocalPlayer.Character" not in hush[hush.find("local function addNpcCandidate"):hush.find("local function removeNpcCandidate")]),
]

failed = [name for name, passed in checks if not passed]
if failed:
    raise SystemExit("feature checks failed: " + ", ".join(failed))

print(f"feature checks passed: {len(checks)}")
