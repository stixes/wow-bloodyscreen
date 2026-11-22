# Tasks

## 1. Harness groundwork

- [ ] 1.1 In `tests/harness.lua`: make `issecretvalue` also report the `SECRET` sentinel (keep the `secret and v == "CRITICAL"` case); make `GetBuildInfo` return from changeable locals (version, build); define `date` before the first `ADDON_LOADED` (it is stubbed only at line 126 today); add a small print-capture helper (as lines 313-316 do) that collects lines starting with the addon prefix. Verify `luajit tests/harness.lua BloodyScreenForever` still exits 0 with every existing line PASS (fix any existing code path the secret-aware stub exposes by guarding it, not by weakening the stub)

## 2. Guard the token reads and the bar writes (api-self-check: only the broken part is off, no Lua errors)

- [ ] 2.1 `BloodyScreenForever.lua`: add `ns.off = {}`; `HasComboPoints` checks `Readable` on the class and power type tokens before comparing and returns false when either is unreadable. Verify a harness check: with `UnitClass` returning `SECRET`, `ADDON_LOADED` + PEW raise no error and Automatic gives crit splatters on a crit in combat
- [ ] 2.2 `EnergyBar.lua`: wrap `UpdateValue`'s `SetMinMaxValues`/`SetValue` in `pcall`; on failure set `ns.off.bar` and hide the bar; guard `token == powerToken`, `Color(powerToken)` and `EMPTY_AT_REST[powerToken]` with `Readable`; `ApplyBar` hides the bar and returns while `ns.off.bar` is set; the bead row hides while `ns.off.combo` is set. Verify harness checks: a bar stub whose `SetValue` throws on `SECRET` leaves the bar hidden with no error on further power events; a `SECRET` power token raises no error; existing bar checks still PASS
- [ ] 2.3 `ResolveMode`: when `ns.off.combo` is set, `combo` (explicit or from Automatic) resolves to no trigger (nothing shown, OnUpdate does nothing for it); `ReadCombo`'s warning is skipped while `ns.off.combo` is set. Verify a harness check: rogue with combo off on Automatic shows no splatters for combo points and no beads, prints no "not readable" warning, and the energy bar still updates

## 3. The checks, the record and the announce gate (api-self-check)

- [ ] 3.1 Add the check function in `BloodyScreenForever.lua` per the design table (class, power type, bar write via a new `ns.BarSelfTest()` in `EnergyBar.lua`, power max, combo with fallback, settings from the stored `BuildOptions` pcall result, automatic); each check returns ok/off/unknown and a `key: value` line in the `/bs debug` style (secrets as `secret`, errors as `err`); never compare or do maths with the power value. Verify by harness: all checks ok with the default stubs; `GetComboPoints = nil` with readable `UnitPower` gives combo ok (fallback noted), not off; combo read returning nil gives unknown, not off
- [ ] 3.2 Arm on `ADDON_LOADED`, run on the first `PLAYER_ENTERING_WORLD` after it; apply results to `ns.off` (both ways) and call `ns.ApplyLayout`/`ns.ApplyBar` so parts follow. Write `db.selfcheck` (`build` = `version.."."..build` from `GetBuildInfo`, `announced`, then the dated header line and one line per check). Move the "settings panel unavailable" print into the settings check (store the error text in the record instead). Verify harness: after login, `ns.db.selfcheck` has the build key, a header line with the build and one line per check; a failing `BuildOptions` prints no separate panel line
- [ ] 3.3 Announce gate: clear `announced` when the build key differs; print one line `BloodyScreen: the game changed - <parts> off. Details: /bs debug` for parts that are off, used by this character (combo only for combo characters, crits only with a crit trigger in effect) and not yet announced; add them to `announced`. Verify these harness checks, each by counting captured prefixed lines:
  - all checks pass on a first install (no `selfcheck` record): 0 lines
  - bar write fails: exactly 1 line naming "energy bar", bar hidden, splatters still work
  - two parts fail (bar and settings): exactly 1 line naming both
  - next login (re-fire `ADDON_LOADED` + PEW, DB kept, same build, still failing): 0 lines, bar still hidden
  - build changes (swap the `GetBuildInfo` stub), still failing: exactly 1 line again
  - combo broken on a warrior: 0 lines; then a rogue logs in on the same build: 1 line naming "combo points"
  - class token `SECRET` on a warrior: 1 line naming "combo points"; class or power type `nil`: 0 lines, nothing off
- [ ] 3.4 Crit flag: in the `UNIT_COMBAT` handler, after the `unit == "target"` test and before the combo return, on every event: the first readable flag sets the record's crit flag line to ok; the first inaccessible secret of the session sets it to off, sets `ns.off.crits` and announces through the same gate. Verify harness: readable hits print nothing and the line reads ok; on a warrior (crit trigger) readable hits then `secret = true` print exactly 1 line naming "crit splatters" and later hits print nothing; a rogue on Automatic gets the record but no line
- [ ] 3.5 `/bs debug` re-runs the checks, appends their lines to `db.debug`, overwrites the record lines and applies `ns.off` both ways, never announcing; re-apply layout and bar only when a part's state changed. Verify harness: with the bar write failing at login then fixed, `/bs debug` brings the bar back and prints no "the game changed" line; with nothing changed, `/bs debug` leaves visible splatters on screen; `/bs help` lists no selftest command
- [ ] 3.6 README: "Getting data out of the game" describes the `selfcheck` record (written at every login, what each line means, the build key) and that `/bs debug` re-runs it; the "Forever patches" section says to read the record after the first login on a new build; slash command list unchanged apart from the `/bs debug` description. Verify by reading both sections
- [ ] 3.7 CHANGELOG under `## Unreleased`: after a game update the addon checks what it relies on, switches off only what broke and says so in one line; no version bump. Verify by reading the section
- [ ] 3.8 `luacheck BloodyScreenForever/` clean (add any new WoW globals to `.luacheckrc` `read_globals`); full harness exits 0, all PASS

## 4. In-game check (only what needs the real game)

- [ ] 4.1 Cold login (quit to desktop and start the game, not `/reload`) on the rogue, with no target. Expect: no BloodyScreen line in chat, splatters, beads and energy bar as usual. Fight a mob until it takes a hit (a crit is not needed), then `/reload` and ask for the saved variables to be read: `selfcheck` should show every check ok, with the real values for `GetComboPoints` with no target at login, the power value as secret and the max readable, the crit flag readable, and the build key. Anything `unknown` or `off` there: report it before release, it means an unmeasured assumption was wrong

## Workflow follow-up

- Archive the change (`/openspec-archive-change patch-self-check`) once group 4 has passed; this creates `openspec/specs/api-self-check`. Releasing is separate and needs this change archived.
