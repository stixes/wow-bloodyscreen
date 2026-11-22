# Proposal: disable splatters in raids and battlegrounds

## Why

Since crits-from-anyone, every critical hit the player's target takes while the player is in combat adds a splatter, whoever landed it. In a 20-40 player raid that keeps the crit triggers at the splatter cap for the whole fight: a wall of blood over boss mechanics. Battlegrounds are similar (many players on one target, and PvP needs a clear screen). The owner wants a simple player choice rather than an automatic rule: two checkboxes, "Disable in raids" and "Disable in battlegrounds".

## What Changes

- **New settings (2 checkboxes)** in the settings panel, in the "Blood splatters" section: **Disable in raids** and **Disable in battlegrounds**. "Disable in raids" is **off by default**. "Disable in battlegrounds" is **on by default** (owner's decision).
- With a box ticked, **no new splatters appear** from any trigger (combo points, the three crit triggers, Automatic) while the player is inside that kind of instance: a raid instance for the first box, a battleground (or arena, if the client has them) for the second.
- Ticking a box while already inside clears the splatters on screen; unticking it, or leaving the instance, brings the trigger back.
- **Not affected:** the energy bar and combo beads (they have their own "Show energy bar" setting, and a raider still wants their resource), `/bs test` and the panel's Preview button (an explicit request), and everything outside those instances, including a raid group out in the world.
- `/bs debug` reports the instance type the client gives and whether splatters are disabled, to measure the unmeasured API in game.
- **Behaviour change on upgrade:** existing players get "Disable in battlegrounds" ticked on first load (the new key takes its default), so splatters stop in battlegrounds and arenas until they untick it. The CHANGELOG says so and how to turn it off.
- No migration code: the new keys get their defaults on first load, a saved choice is never overwritten, and the settings version stays at 10.

Classes and power types affected: all of them, in battlegrounds and arenas by default, in raids only when the box is ticked. Crit-trigger characters (warriors, bear and caster druids, everyone on a crit trigger) are the ones the raid problem hits; rogues and cat-form druids lose their combo point splatters inside the instance too if they tick a box, because the setting reads "disable", not "disable crits".

**New settings: why the existing ones aren't enough.** "Maximal number of splatters" and the Trigger are account-wide (saved variables are shared by every character), so lowering them for raids also changes solo play, and the player would have to change them back on every raid night. A per-instance-type switch is the smallest control that fits. Two settings rather than one because the owner asked for both and raids and battlegrounds are different occasions; they stay independent.

Relies on, not yet measured in game (build 16001):
- `IsInInstance()` exists on Forever and returns instance type `"raid"` inside Forever's raids (Molten Core, Onyxia, ...), `"pvp"` in battlegrounds, `"arena"` in arenas, and is already correct when `PLAYER_ENTERING_WORLD` fires.
- Whether Forever has battlegrounds or arenas at all. The battleground box is harmless if not, but would be a setting nobody can use.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `splatter-triggers`: new requirements: per-instance-type settings that switch every splatter trigger off inside raids and battlegrounds, their defaults, what happens to splatters on screen when the switch takes effect, and that the preview still works.

## Impact

- Code: `BloodyScreenForever/BloodyScreenForever.lua` (defaults, trigger resolution, crit handler guard, a zone event, `/bs debug` line), `Options.lua` (two checkboxes under "Blood splatters"), `.luacheckrc` (`IsInInstance` in `read_globals`).
- Saved variables: two new boolean keys with defaults; no version bump.
- Tests: `tests/harness.lua` gains an `IsInInstance` stub and checks for each setting on/off, entering/leaving, toggling inside, independence of the two, defaults, `/bs reset`, upgrade from a version-10 table, `/bs test` while disabled, and a missing API.
- Docs: README settings list, CHANGELOG `## Unreleased`.
