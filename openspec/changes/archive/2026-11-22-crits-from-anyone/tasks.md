# Tasks

## 1. Crits from anyone (splatter-triggers)

- [x] 1.1 In `BloodyScreenForever.lua`, remove the strict check from the `UNIT_COMBAT` handler, keeping the target, secret (`Readable`) and `WOUND` + `CRITICAL` guards; remove `CAST_WINDOW`, `autoAttacking`/`autoRepeat`/`lastCast`, `stats.dropped`, the `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_ENTER_COMBAT`, `PLAYER_LEAVE_COMBAT`, `START_AUTOREPEAT_SPELL` and `STOP_AUTOREPEAT_SPELL` handlers and registrations, and the reset in `PLAYER_ENTERING_WORLD`; verify `grep -n "strict\|autoAttacking\|autoRepeat\|lastCast\|CAST_WINDOW" BloodyScreenForever/` finds nothing and luacheck is clean (done: the only matches left are the settings-version comment and the retired-keys entry that 2.1 requires)
- [x] 1.2 Harness: replace the two strict checks with "crit with no auto-attack or cast counts" (crit trigger and Automatic on a warrior) and keep "non-crit / non-target adds nothing"; drop or neutralise `fire()` calls for the removed events so the harness doesn't depend on them; verify `luajit tests/harness.lua BloodyScreenForever` exits 0, all PASS
- [x] 1.3 Update the file's header comment (crits come from hits the target takes, from anyone) and verify by reading it

## 2. Remove the setting and command, migrate (splatter-triggers)

- [x] 2.1 Remove `strict` from `ns.DEFAULTS`, add it to the retired keys cleared in `ADDON_LOADED`, bump `SETTINGS_VERSION` to 10; verify a harness check that settings saved with `strict = true` and version 9 load as version 10 with no `strict` key and the trigger kept
- [x] 2.2 Remove the `/bs strict` branch and its help line; `/bs debug` prints `crits on target: seen=N shown=N secret-flag=N` without strict, autoattack or autorepeat fields; verify with harness checks that `/bs help` output has no "strict" and `/bs strict on` leaves crits counting, and read the debug line in the harness output

## 3. Wording around "your target is taking a beating"

- [x] 3.1 `Options.lua` Trigger tooltip: crits are hits your target takes, from anyone (you, pets, your group); verify by reading the tooltip text in `Options.lua`
- [x] 3.2 README: pitch, settings table (Trigger notes), "How it behaves" (crit triggers), "What had to change" (crit detection: no source in `UNIT_COMBAT`, so any crit on the target counts; mention the splatter cap in big groups and lowering max splatters), slash command list without `/bs strict`; verify `grep -n -i strict README.md` finds only the OpenSpec `validate --strict` line (done: plus one deliberate history note in "What had to change" saying the filter existed up to 0.18.x)
- [x] 3.3 TOC notes and a CHANGELOG entry under `## Unreleased` (crits from anyone on your target, strict removed, settings migrate on their own); no version bump, that is release work; verify by reading the `## Unreleased` section

## 3b. Crits only in combat (splatter-triggers, added after 4.4)

- [x] 3b.1 Track combat in `BloodyScreenForever.lua` from `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED`, and in the crit handler drop crits unless that flag or a readable `UnitAffectingCombat("player")` is true; verify harness checks: crit out of combat adds nothing, crit with only the REGEN flag counts, crit with only `UnitAffectingCombat` counts, timed splatters still fade after leaving combat, `/bs test` still previews out of combat; luacheck clean
- [x] 3b.2 Docs: README crit bullets (crits count only while you're in combat; drop the "flash and fade" note) and the `## Unreleased` CHANGELOG line; verify by reading both

## 4. Checks

Automated where the harness can see it; manual only for what needs the real game.

- [x] 4.1 Crits splatter in game without the strict filter. (Passed 2026-11-22: a rogue on "Crits - hide after the timer (each splatter)", the same crit path Automatic uses for a warrior.)
- [x] 4.2 Automated: `/bs debug` crit line reads `seen=N shown=N secret-flag=N` with seen equal to shown and no strict fields (harness "/bs debug: crits on target seen=shown"); `/bs help` lists no strict and `/bs strict on` leaves crits counting (harness checks from 2.2)
- [x] 4.3 Automated: the Trigger tooltip has the new wording (harness "Trigger tooltip: crits from anyone"); the saved trigger survives the upgrade (harness "migration 9 -> 10")
- [x] 4.4 Manual, group (a party or a dungeon, or a pet hitting your target): their crits on your target splatter too. `/reload` before, `/bs debug` after the fight; `seen` should include crits you didn't land. If others' crits don't appear, report it: the docs then must not promise them (design Risks). (Passed 2026-11-22 without a group: targeting another player's mob splattered on their crits.)
- [x] 4.5 Manual: rogue on Automatic: no change, combo point splatters only, crits add none. (Passed 2026-11-22.)
- [x] 4.7 Manual: out of combat, target a mob another player is fighting (Trigger "Crits - hide after the timer (each splatter)"): no splatters. Then pull a mob yourself: crits splatter, including your opening hit if it crits. (Passed 2026-11-22.)
- [x] 4.6 If anything is off, `/bs debug`, `/reload`, and ask for the saved variables to be read; fix and add a harness check. (Nothing was off: 4.1, 4.4, 4.5 and 4.7 passed in game.)

## Workflow follow-up

- Archive the change (`/openspec-archive-change crits-from-anyone`) once group 4 is done; this modifies `openspec/specs/splatter-triggers`. Releasing is separate and needs this change archived.
