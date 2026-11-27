# Proposal

## Why

Forever 1.60.1 gave rogues **Poised**: a passive (spell 1328825, learned at 18)
that applies the aura **Poised** (spell 1328826, "the Energy cost of your next
ability is reduced by 10") whenever the rogue is at maximum Energy and out of
combat. It is the opener charge a rogue waits for after Sap or Distract, and
nothing in the UI says when it is up. The one thing that could say it, the
energy bar, is hidden in exactly that state: "Hide when idle out of combat"
hides the bar at full Energy out of combat.

## What Changes

- The energy bar's **border turns white while the Poised aura (spell 1328826) is
  on the player**, and back to the current black when it is gone - the first
  Energy ability spent it, combat started, or Energy fell below maximum.
- While Poised is up the bar **stays visible out of combat and uses the
  in-combat opacity**, overriding "Hide when idle out of combat" for that moment
  only. No new setting: the existing opacity sliders and the hide setting keep
  their meaning, Poised just counts as "not idle".
- `/bs debug` gains one line with what the Poised aura read returned, so the
  unmeasured API behaviour can be checked in game.
- **Rogues only.** Warriors, other classes and druids in cat form are unaffected
  (the feral Poised aura, spell 1328827, is deliberately left out for now; the
  spell id list is where it would be added). A class that never has the aura
  never sees a border change.
- No new textures, no new settings, no saved-variable change, no version bump.

## Capabilities

### New Capabilities

None. The indicator is behaviour of the existing energy bar, and future bar
indicators belong in the same capability.

### Modified Capabilities

- `energy-bar`: adds a **Poised border** requirement (white border, visible bar,
  in-combat opacity while the rogue's Poised aura is on the player), and adds an
  exception to **Hide when idle out of combat** for that state, which today
  hides the bar in exactly the state Poised appears in.

## Impact

- `BloodyScreenForever/EnergyBar.lua`: register `UNIT_AURA` for `player`, read
  the aura with `C_UnitAuras.GetPlayerAuraBySpellID`, set the border backdrop
  colour, and let Poised hold the bar visible in `UpdateAlpha`.
- `tests/harness.lua`: stub `C_UnitAuras` / `UNIT_AURA`, check the border and the
  hide override.
- `README.md` (energy bar section) and `CHANGELOG.md` under `## Unreleased`.
- **API behaviour not yet measured in game on build 16001:** whether `UNIT_AURA`
  fires on `player` for this self-applied proc aura, whether
  `C_UnitAuras.GetPlayerAuraBySpellID(1328826)` returns it, and whether the
  returned aura data is readable (not secret). If the read fails the indicator
  simply never lights and the bar behaves exactly as it does today - no part of
  the addon is switched off and nothing is announced.
