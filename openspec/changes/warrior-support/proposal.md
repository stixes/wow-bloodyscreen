# Proposal

## Why

Bloody Screen Forever was built around a rogue: combo points drive the splatters and the beads, and the energy bar hides when energy is full. A high-crit fury or arms warrior is just as much the audience, but today a warrior sees no splatters at all, because the default trigger is "Combo points". Saved variables are per account, so a warrior alt also inherits whatever trigger the rogue main chose. The energy bar never hides for a warrior either, because rage rests at empty, not full.

The code for this change is already in (commit `2eca616`, v0.18.0). It has not been tested in game or released. This change records the behaviour and carries the remaining verification and release work.

## What Changes

- New default trigger, **Automatic**: on a character with combo points (a rogue, or a druid in cat form), splatters follow combo points as before. Every other character gets a splatter per crit, each fading after the timer.
- The trigger in effect is worked out per character and updates when a druid changes form.
- Players who had "Combo points" selected are moved to Automatic. On a rogue that is the same behaviour; on any other class it turns splatters on. The three crit triggers and an explicit choice of them are untouched.
- Combo point beads show only for rogues and for druids in cat form.
- "Hide when full out of combat" becomes **"Hide when idle out of combat"**: the bar hides when power is at its resting level, which is full for energy and mana and empty for rage.

Classes and power types affected:
- **Warrior (rage):** gains crit splatters by default; the bar now hides when idle.
- **Druid:** combo points and beads in cat form, crit splatters in bear and caster forms. Bear form's rage gets the same hide rule as a warrior's.
- **Rogue (energy):** no visible change.
- **Others (mana):** gain crit splatters by default; the bar is unchanged.

No new setting: Automatic is a new choice in the existing Trigger dropdown, and the hide setting keeps its key and only changes its label. A per-class trigger setting was the alternative. It would double the trigger settings to solve what one sensible default solves.

Not yet measured in game (build 16001), and relied on:
- `UnitClass` returns the class token (`WARRIOR`, `DRUID`, `ROGUE`) on Forever.
- Cat form reports energy as the power type, and a form change fires the display-power event.
- Warrior ability and auto-attack crits arrive as `UNIT_COMBAT` crits on the target, and the strict filter keeps them (auto-attack, or within 1.5 s of a cast).
- Whether rage is readable or secret out of combat. Both cases are handled: compare it when readable, otherwise 3 s with no power change.

## Capabilities

### New Capabilities

- `splatter-triggers`: what makes splatters appear: the trigger choices, how Automatic resolves per character, and the settings migration.
- `combo-beads`: the combo point beads under the energy bar, and who sees them.
- `energy-bar`: the energy, rage or mana bar under the character. This change adds only its out-of-combat hiding rule.

### Modified Capabilities

None. `openspec/specs/` is empty, and this is the first change recorded with OpenSpec.

## Impact

- Code: `BloodyScreenForever/BloodyScreenForever.lua` (trigger resolution, migration, a form-change event), `EnergyBar.lua` (bead gate, resting level), `Options.lua` (dropdown entry, tooltips, the renamed label).
- Saved variables: settings version 8 → 9; `mode = "combo"` migrates to `"auto"`.
- Tests: `tests/harness.lua` gains class and power-type stubs and checks for rogue, warrior and druid.
- Docs: README pitch and settings table, `CHANGELOG.md` 0.18.0, TOC notes and version.
- Release: 0.18.0 to CurseForge and GitHub through the tag workflow, after the in-game check.
