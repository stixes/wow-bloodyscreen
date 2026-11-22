# Tasks

## 1. Settings and detection (splatter-triggers)

- [ ] 1.1 Harness: add a switchable `IsInInstance` stub (`local instType = "none"`; `IsInInstance = function() return instType ~= "none", instType end`) near the other API stubs, before the addon loads; verify `luajit tests/harness.lua BloodyScreenForever` still exits 0, all PASS
- [ ] 1.2 Add `offInRaids = false` and `offInBattlegrounds = false` to `ns.DEFAULTS` (with a comment each); keep `SETTINGS_VERSION` at 10. Verify with harness checks: a fresh load (empty saved table) has both keys `false`; a saved version-10 table without them gains both as `false`, keeps its other values and stays at version 10; `/bs reset` after setting both `true` puts both back to `false`
- [ ] 1.3 In `ResolveMode()`, resolve to `"off"` when the instance type is `"raid"` and `db.offInRaids`, or `"pvp"`/`"arena"` and `db.offInBattlegrounds`. Read the type through a guarded helper (nil check on `IsInInstance`, `pcall`, `Readable` and `type(...) == "string"`, else `"none"`). Add `"off"` to the early return in `OnUnitCombat` and an explicit `mode == "off"` return at the top of `OnCrit`. Add `IsInInstance` to `.luacheckrc` `read_globals`; verify `luacheck BloodyScreenForever/` is clean
- [ ] 1.4 Add `ns.RecheckZone()` (`if db and ResolveMode() then ClearNow() end`), a `ZONE_CHANGED_NEW_AREA` handler calling it, and the event in the registration list. Verify with harness checks (each using `instType` plus `fire("ZONE_CHANGED_NEW_AREA")` or `fire("PLAYER_ENTERING_WORLD")`, warrior on Automatic, in combat):
  - raid box on, in a raid: crits add nothing
  - raid box off, in a raid: crits splatter
  - raid box on, in a battleground (`"pvp"`): crits splatter (independence)
  - battleground box on, in `"pvp"` and in `"arena"`: crits add nothing
  - battleground box on, in a raid: crits splatter (independence)
  - raid box on, `instType = "none"` while in a raid group (no group API consulted): crits splatter
  - rogue on Automatic, raid box on, in a raid: combo points add no splatters (both the event path and the per-frame poll), while the bead row still lights the points
  - entering the raid via `PLAYER_ENTERING_WORLD` with splatters up: cleared; leaving: next crit splatters
  - `IsInInstance = nil`, both boxes on: crits splatter, no error; then restore the stub
  - `/bs debug` "in effect" reads `off` inside a disabled raid
- [ ] 1.5 Verify the switch-on clears in-flight splatters: a timed crit splatter shown, and one mid-fade, just before `ns.RecheckZone()` turns suppression on are both gone at once (harness check: `vis() == 0` right after), and the next frames run without a Lua error

## 2. Panel, preview and debug

- [ ] 2.1 `Options.lua`: two `Settings.CreateCheckbox` calls under "Blood splatters", after "Avoid the centre" and before the Preview button: "Disable in raids" (tooltip: no blood splatters inside raid instances; the energy bar stays) and "Disable in battlegrounds" (tooltip: no blood splatters inside battlegrounds and arenas; the energy bar stays), each `SetValueChangedCallback` → `ns.RecheckZone()`. Harness: capture checkbox labels and tooltips with a `rawset(Settings, "CreateCheckbox", ...)` stub like the dropdown one (and `RegisterAddOnSetting` names so labels can be matched); verify both labels exist, their tooltips mention the energy bar staying, and the panel still builds without error
- [ ] 2.2 Harness: ticking the raid box inside a raid with splatters on screen (set `ns.db.offInRaids = true`, call `ns.RecheckZone()`) clears them; unticking and calling `ns.RecheckZone()` lets the next crit splatter; verify both checks PASS
- [ ] 2.3 Harness: with the raid box on inside a raid, `/bs test` shows `ns.db.max` splatters and they fade after the preview; verify the check PASSes
- [ ] 2.4 `/bs debug`: add a `zone: IsInInstance=<in>/<type> offInRaids=<b> offInBattlegrounds=<b>` line, secret-safe and pcall-guarded like the other debug reads; harness: capture `/bs debug` output inside a raid and check the line shows `raid` and the two settings
- [ ] 2.5 Docs: README settings table rows for both settings (default off, splatters only, energy bar unaffected, raid = raid instance not a raid group in the world, battlegrounds include arenas), and a CHANGELOG line under `## Unreleased`; no TOC version bump. Verify by reading both sections

## 3. In-game checks

Only what needs the real game; everything else is in the harness.

- [ ] 3.1 Raid (any raid instance; the setting off first): `/bs debug` inside shows `zone: IsInInstance=true/raid`. If the type is anything else, report it (the rule needs adjusting). Then tick "Disable in raids": splatters on screen vanish, and in a fight no splatters appear while the energy bar and beads work as usual. Untick it: crits splatter again
- [ ] 3.2 Leave the raid with the box ticked: after the loading screen, crits on a mob outside splatter as usual. Re-enter: none
- [ ] 3.3 Battleground (only if Forever has them): `/bs debug` shows `.../pvp`; with "Disable in battlegrounds" ticked, no splatters in a fight. If Forever has no battlegrounds, report that, so the owner can decide whether the box stays
- [ ] 3.4 If anything is off: `/bs debug`, `/reload`, and ask for the saved variables to be read; fix and add a harness check

## Workflow follow-up

- Archive the change (`/openspec-archive-change disable-in-raids-and-battlegrounds`) once group 3 is done; this modifies `openspec/specs/splatter-triggers`. Releasing is separate and needs this change archived.
