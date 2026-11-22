# Design

## Context

Implemented in commit `2eca616` (v0.18.0); this document records why it was built this way. See proposal.md for motivation and the specs for the required behaviour.

Constraints that shaped it:
- One `BloodyScreenForeverDB` per account. Every character reads the same Trigger value, so any per-class behaviour has to be worked out at runtime, not stored.
- The player's primary power is a secret value on Forever (measured for energy on build 16001, even out of combat). Rage is assumed to behave the same until measured.
- The splatter logic already branched on the stored trigger in about ten places (OnUpdate, combo and target-switch handlers, crit handler).

## Goals / Non-Goals

**Goals:**
- A warrior, or any non-combo class, gets useful splatters with zero configuration, including as an alt on an account set up by a rogue.
- No new settings.
- No behaviour change for rogues.

**Non-Goals:**
- Warrior-specific crit rules (Deep Wounds, Whirlwind's extra targets, Sweeping Strikes). Crits stay "critical hits on the current target" as for every class.
- Changing the energy bar's look per class beyond the power colour it already uses.
- Hunters, casters and healers beyond what falls out of Automatic. Their crits work the same way but aren't the focus.

## Decisions

### Resolve Automatic at runtime into one of the existing triggers
The stored value stays `db.mode` ("auto", "combo", or a crit trigger). A local, `mode`, holds the trigger in effect, and every branch that read `db.mode` now reads `mode`. It's recomputed on load, on entering the world, on a display-power change (a druid's form), and whenever splatters are cleared (a settings change or reset). When the resolved trigger changes, splatters are cleared so combo-point and crit slots don't mix.

Alternative: a fifth branch for "auto" at every call site. Rejected: it duplicates the combo and crit logic, and the harness already covers the existing branches.

### Automatic falls back to "Crits - timer (each splatter)"
Out of the three crit triggers:
- "Hide when combat ends" (the original's default) lets a long warrior fight pile up to the maximum and hold a full screen of blood until combat ends.
- "Timer (shared)" clears everything at once 5 s after the last crit, which is close to the same in a fight with steady crits.
- "Timer (each splatter)" keeps each crit as a short flash that fades on its own.

The last one fits "flavour" best. Players who want another one can still pick it explicitly.

### Gate combo points and beads by class, not by the reported combo maximum
A character has combo points when `UnitClass` returns `ROGUE`, or `DRUID` with `ENERGY` as its current power type (cat form). The previous bead check used `UnitPowerMax(player, ComboPoints) > 0`. On the modern client that can be non-zero for classes that never build combo points, and that hasn't been measured on Forever. The class check is explicit and costs nothing.

Alternative: keep the maximum check and add the class check only for Automatic. Rejected: two definitions of "has combo points" would drift.

### Include cat-form druids
The request said beads should show for rogues. Vanilla-style druids also build combo points in cat form, so leaving them out would show a druid's combo points as nothing. This is a deliberate deviation, recorded here, and it's easy to remove (one line in the class check).

### Resting level per power type
`EMPTY_AT_REST = { RAGE = true }`. When power is readable, "at rest" means `cur <= 0` for rage and `cur >= max` otherwise. When it's secret, the existing rule (3 s with no power event out of combat) covers both, since rage decays to 0 and then stops changing. The setting keeps its saved key (`barHideFull`), so saved choices survive, and only its label changes to "Hide when idle out of combat".

### Migrate "combo" to "auto" once (settings version 9)
Automatic resolves to exactly the combo trigger for a rogue, so the migration changes nothing for rogues and turns splatters on for non-rogues. An explicit crit trigger is left alone. The version gate means a player who picks "Combo points" again after upgrading keeps it.

## Risks / Trade-offs

- [`UnitClass` or cat form's power type behave differently on Forever] → `/bs debug` prints "mode=auto (in effect: …)", so a wrong resolution shows up straight away. The in-game checks in tasks.md cover rogue, warrior and both druid forms.
- [Warrior crits filtered out by the strict check] → Heroic Strike and Cleave land on the next swing while auto-attacking, which passes. Instant abilities pass within 1.5 s of the cast. `/bs debug` shows seen, shown and dropped counts if crits seem missing.
- [Rage is secret, and decay produces power events long after combat] → the bar stays visible until rage reaches 0 and goes quiet for 3 s. That's acceptable: it hides once you're actually idle.
- [A player who really wanted "Combo points" on every class] → nothing is lost: "Combo points" is still in the dropdown and is kept after the one-time migration.
- [Clearing splatters on a druid's form change] → a druid shifting mid-fight loses the current splatters. Acceptable, since the meaning of the slots has changed.

## Migration Plan

- The settings migration runs on first load of 0.18.0 (version 8 → 9); there's nothing for the player to do.
- Release through the tag workflow after the in-game check. If something breaks in game, a fix goes out as 0.18.1. Rolling back means reinstalling 0.17.0 from CurseForge; the migrated `auto` value is unknown to 0.17.0 and falls back to its default ("combo"), so a downgrade is safe.
