# Bundled Easy* compatibility changes

The bundled EasyESP and EasyUI Style 2 sources are credited to the maintained `ToiletStarter/CantStopMakingReposForThis` libraries. This document records the HUSH audit's local compatibility changes, not ownership of the original libraries or all pre-existing working-tree differences.

## EasyUI Style 2

### Silent flag synchronization

`UI:Set(flag, value, silent)` now forwards `silent` to the registered widget's `Set` method. Existing two-argument calls retain their behavior. A true third argument updates the widget/flag without invoking its user callback.

HUSH uses this after applying a stored config directly to renderer state. This prevents callback-order dependence and keeps color swatches and controls aligned with the restored values.

### Native/custom cursor ownership

`UI:SetCursorVisible(enabled)` explicitly hides the native cursor only when both the UI and custom cursor are enabled. Otherwise it restores the saved `MouseIconEnabled` value. The old false-valued `and/or` expression always fell through to the saved value in that branch.

The existing UI visibility/Destroy restoration behavior is retained.

### Drag rendering

Window dragging now updates a target position and follows it from one RenderStepped motion path. The window no longer receives a per-input position tween or an alpha transition during drag, so the panel keeps its configured opacity instead of washing gray. Release snaps to the final target and preserves the stable titlebar geometry.

## EasyESP

### Off-screen arrow gates

`ESP:_arrow` now respects the player master when drawing player arrows, and the snapshot's category-specific Hide occluded policy for both players and NPCs. Existing per-category arrow toggles and feature ranges still apply.

This prevents arrows surviving a Player ESP disable or leaking through an explicitly hidden occluded category.

## Verification and release boundary

`tools/test_hush.py` compiles both real libraries and executes their actual cursor, flag setter, and arrow methods with negative and positive behavioral assertions. The consumer's broader mock suite checks callback wiring, config round trips, cache/replication edges, and lifecycle cleanup.

These checks do not certify the complete renderer, pointer delivery, layout, or texture-cham output. Live structural verification is recorded with each consumer release; visual pixel verification still depends on a working host capture path.
