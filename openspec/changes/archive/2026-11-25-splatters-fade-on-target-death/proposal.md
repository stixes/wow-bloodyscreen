# Proposal

## Why

When a rogue kills its target, the combo point splatters vanish for a moment and then come back, and they stay up over the corpse. In vanilla, combo points are lost with the target, so the splatters should fade away with the kill and stay gone. The comeback is the real bug; the short vanish is the addon briefly getting it right.

## What Changes

- In combo point mode, a dead target counts as having no combo points: its splatters fade out the usual way and are not shown again while that corpse stays targeted.
- The combo beads under the energy bar follow the same rule: they show no points on a dead target, because they read the same count.
- Targeting a living mob afterwards works as before: its points show (and fade in) as normal.
- `/bs trace` also logs whether the target is dead, so the in-game check can show what the count sources do at the kill.

Classes affected: rogues, and druids in cat form (Automatic or "Combo points" trigger). Crit triggers (warriors and everyone else) are unchanged: their splatters already fade when combat ends.

No new setting: fading on a kill is how the original behaves, so there's nothing to choose.

Not yet measured in game: which count source reports points after the kill (the guess is that `GetComboPoints(player, target)` drops to 0 and then the count comes back, from the server or from the stale `UnitPower` fallback), and whether the game's "is the target dead" check is readable and switches at the moment of the kill. The fix doesn't rely on knowing which source comes back, but it does rely on the dead check.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `splatter-triggers`: new requirement: combo point splatters fade out when the target dies and are not shown again for that corpse.
- `combo-beads`: new requirement: the beads show no points on a dead target.

## Impact

- `BloodyScreenForever/BloodyScreenForever.lua`: the shared combo point reader (used by the splatters and the beads) returns 0 for a dead target; `/bs trace` logs the target's dead state.
- `tests/harness.lua`: stub for the dead check, plus replay checks for the kill.
- `CHANGELOG.md`: one line under `## Unreleased`.
