# Proposal: crits from anyone (your target is taking a beating)

## Why

The original Bloody Screen splattered on *your own* crits, read from the combat log. On WoW Forever the combat log is closed to addons, and the event that replaces it (`UNIT_COMBAT` on the target) doesn't say who hit. The port papers over that with a timing guess, the hidden "strict" filter: a crit counts only while you auto-attack or within 1.5 s of your own cast. That guess drops some of your own crits (DoT ticks, crits outside the window), lets others' crits through in groups anyway, and needs explaining everywhere.

Instead of guessing at a source the game won't give us, change the idea: **your target is taking a beating, so the blood lands on your screen.** Every critical hit on your target splatters, whoever landed it (you, your pet, your group). It is simpler, honest about what the game tells addons, and fits the theme. This deliberately leaves the original's scope ("your crits") behind.

## What Changes

- **BREAKING (behaviour):** the crit triggers (and Automatic on non-combo characters) splatter on **every critical hit your target takes**, from anyone, not only your own.
- **Removed:** the strict filter: the `strict` setting, the `/bs strict on|off` command, its help line, and the auto-attack/auto-repeat/cast tracking that only existed to feed it. Its `/bs debug` counters (`dropped(strict)`, autoattack, autorepeat) go too.
- **Migration:** settings version 9 → 10 removes the saved `strict` value. Nothing else in the saved settings changes; the chosen trigger is kept.
- **Rephrased:** the crit feature is described around the new idea in the settings tooltip, `/bs` help, README (pitch, settings, "How it behaves", "What had to change"), TOC notes and CHANGELOG. The dropdown labels keep their short form ("Crits - …").

Classes and power types affected:
- **Warrior (rage), bear and caster druids, and every other class on Automatic or a crit trigger:** now also get splatters from pets' and other players' crits on their target, and from their own crits the filter used to drop.
- **Rogue and cat-form druid on Automatic (combo points):** no change; crits add no splatters for them.
- **Anyone who picked "Combo points" explicitly:** no change.

No new setting, and one fewer: the hidden strict switch goes away. A player who finds group content too busy can lower "Maximal number of splatters", or pick "Combo points" or a different crit trigger. The proposal accepts that in big groups the crit triggers will often sit at the splatter cap; that is the beating the target is taking.

Relies on, not yet measured in game (build 16001):
- `UNIT_COMBAT("target", "WOUND", ..., "CRITICAL")` fires for pets' and other players' crits on your target, not only yours. The current code assumed this (it is why the filter existed), and the README already says others' crits slip through in groups, but it hasn't been confirmed with a `/bs debug` count in a group.
- Whether periodic (DoT) crits arrive as `WOUND` + `CRITICAL` on `UNIT_COMBAT`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `splatter-triggers`: crit-based splatters count every critical hit the target takes, from any source; Automatic's timed-crit requirement is reworded to match; a migration requirement covers dropping the saved strict value.

## Impact

- Code: `BloodyScreenForever/BloodyScreenForever.lua` (crit handler, state, events registered, slash commands, `/bs debug`, defaults, migration, header comment), `Options.lua` (Trigger tooltip).
- Saved variables: settings version 9 → 10; `strict` removed.
- Tests: `tests/harness.lua` loses the strict checks and gains checks for crits counted without auto-attack or a cast, and for the migration dropping `strict`.
- Docs: README (pitch, settings, behaviour, "What had to change", slash commands), TOC notes, CHANGELOG entry and TOC version bump for the next release.
