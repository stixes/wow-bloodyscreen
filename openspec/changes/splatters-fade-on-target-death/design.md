# Design

## Context

Combo point splatters and beads both read one shared function: `GetComboPoints("player", "target")` first, with a fallback to `UnitPower("player", ComboPoints)` when that can't be read. The splatter loop polls this count every frame in combat and for a short settle time after a target switch. It starts fading slots at or above the count and shows a slot below the count when it isn't visible. A fading slot still counts as visible, so if the count comes back during a fade the fade finishes first, and then the slot is shown again. That is the "vanish, then come back" seen at a kill: the count drops to 0, the splatters fade, and a non-zero count shows up again afterwards. The rogue stays in combat for a moment after a kill, so the poll is still running.

Which source reports the count coming back hasn't been measured. Candidates: `GetComboPoints` itself after a server update (as on a target switch, where the real count arrives ~0.9 s later), or the stale `UnitPower` fallback if `GetComboPoints` returns nothing for a corpse.

## Goals / Non-Goals

**Goals:**
- A dead target reads as 0 combo points, for both splatters and beads.
- No change for a living target, for crit triggers, or when the dead state can't be read.

**Non-Goals:**
- Tracking whether points carry over to the next target (the count on the new target decides, as today).
- Changing what the self-check tests at login.

## Decisions

- **Gate in the shared reader, not in the splatter loop.** The reader returns 0 when the target exists and is dead. Splatters and beads both get the fix, and the existing "count is 0" path (fade out, nothing shown) does the rest. Alternative: a death event (`UNIT_DIED` / `UNIT_HEALTH`): the combat log is closed, and health may be secret. A guarded per-read check is simpler and also covers targeting an existing corpse.
- **Dead check = `UnitIsDead("target")`, guarded.** Read it with `pcall`, and act only on a readable `true` (`Readable(v) and v == true`). Missing function, error, secret or nil all mean "not known dead", so behaviour stays as today (the spec's "unreadable" scenario). `UnitIsDeadOrGhost` would add only ghosts, which can't be targets that hold combo points, so `UnitIsDead` is enough. Not `UnitHealth == 0`, because health may be secret.
- **Measure in the same change, without blocking on it.** Add `UnitIsDead(target)` to the `/bs trace` sample. The in-game check covers both questions at once: does the fix stop the comeback, and does the trace show the dead state switching at the kill? If the dead state turns out unreadable, the trace shows `secret`/`err` and we rethink. The fix fails safe in that case: no worse than today.

## Risks / Trade-offs

- [`UnitIsDead` turns true a moment after the count first drops] → harmless: the count is already 0, and a returning count is then blocked.
- [`UnitIsDead` turns true before the count drops] → splatters just start fading a moment earlier.
- [A mob that "feigns death" or is dead but still hostile (rare in Forever's PvE)] → its points read 0; acceptable, since a dead-flagged target can't take finishers.
- [Self-check reads the same function at login with no target] → `UnitIsDead` on a missing target is false or nil, so nothing changes; a harness check covers it.

## Migration Plan

None: no settings, no saved data.
