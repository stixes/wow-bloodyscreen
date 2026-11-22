# Tasks

## 1. Crits from anyone (splatter-triggers)

- [ ] 1.1 In `BloodyScreenForever.lua`, remove the strict check from the `UNIT_COMBAT` handler, keeping the target, secret (`Readable`) and `WOUND` + `CRITICAL` guards; remove `CAST_WINDOW`, `autoAttacking`/`autoRepeat`/`lastCast`, `stats.dropped`, the `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_ENTER_COMBAT`, `PLAYER_LEAVE_COMBAT`, `START_AUTOREPEAT_SPELL` and `STOP_AUTOREPEAT_SPELL` handlers and registrations, and the reset in `PLAYER_ENTERING_WORLD`; verify `grep -n "strict\|autoAttacking\|autoRepeat\|lastCast\|CAST_WINDOW" BloodyScreenForever/` finds nothing and luacheck is clean
- [ ] 1.2 Harness: replace the two strict checks with "crit with no auto-attack or cast counts" (crit trigger and Automatic on a warrior) and keep "non-crit / non-target adds nothing"; drop or neutralise `fire()` calls for the removed events so the harness doesn't depend on them; verify `luajit tests/harness.lua BloodyScreenForever` exits 0, all PASS
- [ ] 1.3 Update the file's header comment (crits come from hits the target takes, from anyone) and verify by reading it

## 2. Remove the setting and command, migrate (splatter-triggers)

- [ ] 2.1 Remove `strict` from `ns.DEFAULTS`, add it to the retired keys cleared in `ADDON_LOADED`, bump `SETTINGS_VERSION` to 10; verify a harness check that settings saved with `strict = true` and version 9 load as version 10 with no `strict` key and the trigger kept
- [ ] 2.2 Remove the `/bs strict` branch and its help line; `/bs debug` prints `crits on target: seen=N shown=N secret-flag=N` without strict, autoattack or autorepeat fields; verify with harness checks that `/bs help` output has no "strict" and `/bs strict on` leaves crits counting, and read the debug line in the harness output

## 3. Wording around "your target is taking a beating"

- [ ] 3.1 `Options.lua` Trigger tooltip: crits are hits your target takes, from anyone (you, pets, your group); verify by reading the tooltip text in `Options.lua`
- [ ] 3.2 README: pitch, settings table (Trigger notes), "How it behaves" (crit triggers), "What had to change" (crit detection: no source in `UNIT_COMBAT`, so any crit on the target counts; mention the splatter cap in big groups and lowering max splatters), slash command list without `/bs strict`; verify `grep -n -i strict README.md` finds only the OpenSpec `validate --strict` line
- [ ] 3.3 TOC notes and a CHANGELOG entry for the next version (crits from anyone on your target, strict removed, settings migrate on their own), and bump `## Version` in the TOC; verify `tools/release.sh --dry-run` shows the new notes

## 4. In-game check (the user, on WoW Forever)

- [ ] 4.1 Before the fight, `/bs debug` once to reset the view of the counters. Solo on a warrior (or any non-rogue on Automatic): crits splatter as before, including crits right after you stop auto-attacking. `/bs debug` shows `crits on target: seen=N shown=N` with seen equal to shown and no strict fields.
- [ ] 4.2 Old command: `/bs strict on` prints the help list (no strict line) and crits keep splattering.
- [ ] 4.3 Settings: `/bs` shows the Trigger tooltip with the new wording, and your saved trigger is unchanged after the upgrade.
- [ ] 4.4 Group, if possible (a party or a dungeon): with another player or a pet hitting your target, their crits splatter too. `/bs debug` after the fight; `seen` should include crits you didn't land. If others' crits don't appear, report it: the docs then must not promise them (design Risks).
- [ ] 4.5 Rogue on Automatic: no change, combo point splatters only, crits add none.
- [ ] 4.6 If anything is off, `/bs debug`, `/reload`, and ask for the saved variables to be read; fix and add a harness check.

## Workflow follow-up

- Archive the change (`/openspec-archive-change crits-from-anyone`) once group 4 is done; this modifies `openspec/specs/splatter-triggers`. Releasing is separate and needs this change archived.
