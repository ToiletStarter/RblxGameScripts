# Voxel live verification

Place identity confirmed in Potassium:

- Place ID `6128781746`
- Place name `Morskoe Village, Odesa Oblast, Ukraine`
- Game ID `595270616`
- Live client PID `38820`
- Player count during verification: 15 before the overlay load and 19 during the overlay snapshot

Observed live roots:

- `Workspace.Players` with 14 character models
- `Workspace.Interactable.PickUps` with 1015 live pickup models after the overlay started
- `Workspace.Interactable.Containers` with 302 live container models after the overlay started
- `Workspace.Airdrops.Nodes` with 34 extraction/drop location nodes
- `Workspace.ExfilFlare` present in the live workspace
- `Workspace.Zombies` present but empty during this sample

The consumer was staged with matching SHA-256 bytes for the consumer, EasyESP, and EasyUI Style 2. The live load emitted `[VOXEL_ESP_LOAD] true`.

Structural live checks passed:

- Exactly one `VOXEL_ESP_GUI` root after load
- Window size `520x560`
- Window opacity `0.08`, matching the configured UI transparency
- Snapshot reported `readOnly=true`, `remoteCalls=false`, `hooks=false`, `inputSynthesis=false`, and `worldMutation=false`
- Delayed renderer snapshot reported 8 player roster entries and 8 drawn player records at about 165 FPS average
- Unload removed the owned root and cleared the session slot
- Reload restored one root and persisted the test range value
- Final reload restored the sane default player range of 3000m
- Fullbright toggle applied `Brightness=3`, `ClockTime=14`, and `GlobalShadows=false`; disabling it restored the captured Lighting values and cleared `localAppearanceOverrides`
- Combat preview and trajectory observer loaded with `trajectoryAvailable=true`; the passive preview toggled on and off without remote calls, input synthesis, or firing behavior

The host screenshot helper could not capture the Roblox window because it returned `no window for process RobloxPlayerBeta`. Desktop computer-use capture was unavailable in this session, so visual pixel inspection remains blocked. Structural UI checks and live renderer checks passed; the drag fix still needs a visual capture when a host capture path is available.

The live error buffer contained only pre-existing game or asset messages. No Voxel ESP warning or load traceback was emitted.
