# Tasks

Groups 1-3 were implemented in commit `2eca616` before this change was recorded.

## 1. Automatic trigger (splatter-triggers)

- [x] 1.1 Add "auto" to the trigger list and make it the default; resolve it per character (rogue or cat-form druid → combo points, otherwise timed crits) on load, on entering the world, on a display-power change, and when splatters are cleared; verify with the harness checks "default trigger is auto", "auto, rogue: …", "auto, warrior: …" and "auto, druid …" (`2eca616`)
- [x] 1.2 Migrate a saved "combo" to "auto" (settings version 9); verify with the harness's migration line showing `mode=auto version=9` (`2eca616`)
- [x] 1.3 Settings panel: add Automatic to the Trigger dropdown with a tooltip that explains sharing across characters; `/bs debug` prints the trigger in effect; verify by reading `Options.lua` and the debug line in the harness output (`2eca616`)

## 2. Combo beads by class (combo-beads)

- [x] 2.1 Show the bead row only for rogues and cat-form druids; verify with the harness checks "warrior: combo bead row hidden", "druid in cat form: combo bead row shown" and "rogue: combo bead row shown" (`2eca616`)

## 3. Resting level (energy-bar)

- [x] 3.1 Hide when idle: rage rests at empty, other power at full; rename the label to "Hide when idle out of combat"; verify with the harness checks "warrior: rage empty out of combat -> bar hidden", "warrior: rage left out of combat -> bar shown" and the existing hideFull checks (`2eca616`)
- [x] 3.2 Docs: README pitch and settings table, CHANGELOG.md 0.18.0, TOC notes and version 0.18.0; verify that `envchain curseforge tools/release.sh --dry-run` shows the 0.18.0 notes (`2eca616`)
- [x] 3.3 Full harness run: `luajit tests/harness.lua BloodyScreenForever` exits 0 with 84 PASS (`2eca616`)

## 4. In-game check (the user, on WoW Forever)

Set up first: uninstall the CurseForge copy in the CurseForge app, restore the dev symlink, then `/reload`.

- [x] 4.1 Rogue: open `/bs`. The Trigger shows "Automatic" (migrated from Combo points) and the hide setting reads "Hide when idle out of combat". In a fight, splatters follow combo points as before, crits add none, and the beads show and follow target switches.
- [x] 4.2 Warrior (or any non-rogue): `/bs debug` prints "mode=auto (in effect: crittimed)". In a fight, each crit splatters, and each splatter fades about 5 s after it appeared. No beads under the bar; the bar is red (rage).
- [x] 4.3 Warrior out of combat: once rage has decayed to 0, the bar disappears within about 3 s. It shows again on entering combat. With the hide setting off, it stays visible at the out-of-combat opacity.
- [ ] 4.4 Druid: in cat form, beads and combo splatters. Shift to bear: splatters clear, beads disappear, and crits splatter. Shift back: beads return. **Not tested (no druid available, 2026-11-22). It ships as untested; the CHANGELOG and README say so.**
- [x] 4.5 If anything is off, run `/bs debug`, then `/reload`, and ask for the saved variables to be read. Fix as 0.18.0 (still unreleased), and add harness checks for whatever was missed. (4.1-4.3 passed; nothing to fix.)

## Workflow follow-up

- Archive this change (`/openspec-archive-change`) once 4.x is done; this creates `openspec/specs/splatter-triggers`, `combo-beads` and `energy-bar`. Releasing is not part of the change; it happens separately when the user asks.
