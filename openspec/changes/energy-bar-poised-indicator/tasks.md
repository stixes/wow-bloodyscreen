# Tasks

## 1. Poised presence and the bar's reaction

- [x] 1.1 In `tests/harness.lua`, stub `C_UnitAuras.GetPlayerAuraBySpellID`
  (switchable: returns an aura table, returns nil, throws, returns a secret
  value) and capture the bar's backdrop child frame and its
  `SetBackdropBorderColor` into `barState`. Verify: the stub is reachable from
  the checks in 1.2-1.5 and the existing checks still PASS.
- [x] 1.2 In `EnergyBar.lua`, add `POISED_IDS = { 1328826 }`, hoist `border` to a
  file local, and add the pcall-guarded presence read from design.md decision 2
  with a `poisedKnown` latch. Verify: `luacheck BloodyScreenForever/` is clean
  with the generated API list (`tools/wow-api/forever-api.lua` has
  `GetPlayerAuraBySpellID`); add it to the `.luacheckrc` fallback list only if
  the generated list is missing.
- [x] 1.3 `SetPoised(on)` repaints the border (white `1,1,1,1` when lit, the
  current `0,0,0,0.8` otherwise) and keeps the `border.SetBackdrop` guard.
  Verify: harness checks that the recorded border colour flips on an aura event
  and back when the aura is gone.
- [x] 1.4 Register `UNIT_AURA` for `player` on the bar and re-evaluate Poised on
  `UNIT_AURA`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_DISABLED/ENABLED` and
  `UNIT_DISPLAYPOWER`. Verify: harness check that `UNIT_AURA` is registered, and
  that firing it with the aura present lights the border without any power event.
- [x] 1.5 Give `UpdateAlpha` the Poised branch: visible at `barAlphaCombat` while
  lit, whatever `barHideFull` says; otherwise the current rules. Verify: harness
  checks that a rogue at full energy out of combat is no longer hidden while the
  aura is up (alpha equals `barAlphaCombat`), and is hidden again once the aura is
  removed.

## 2. Degradation and diagnostics

- [x] 2.1 Aura read refused or hidden (stub throws, or returns a secret): latch
  off for the session, border never changes, bar keeps updating. Verify: harness
  checks each stub mode - border colour unchanged, no error propagates out of the
  event handler, and the power value still reaches `SetValue`.
- [x] 2.2 `ns.BarDebug()` gains one line: `bar: poised=<id|none|unavailable>
  border=<white|normal>`, presence only. Verify: harness calls `ns.BarDebug()` and
  checks the line appears in both border states and in the unavailable case.

## 3. Docs

- [x] 3.1 `README.md` energy bar section: the border turns white while Poised is
  up (rogue), the bar stays visible and at the in-combat opacity then, no new
  setting. Verify: the wording matches the delta spec and names no setting that
  does not exist.
- [x] 3.2 `CHANGELOG.md` entry under `## Unreleased`. Verify: no `## Version` bump
  in the TOC and no other changelog section is touched.

## 4. Integration check

- [x] 4.1 Run `luacheck BloodyScreenForever/`, `luajit tests/harness.lua
  BloodyScreenForever` (all PASS) and `openspec validate --all --strict` (no
  findings). Verify: all three exit clean.

## In-game checks (only what the real game can answer)

1. Rogue 18+, out of combat, let Energy fill to maximum: the bar stops hiding
   itself and its border turns white at the same moment the Poised buff icon
   appears on your buff row. (Answers: does `UNIT_AURA` reach the addon for this
   server-applied aura.)
2. Sinister Strike: the border goes back to black on that cast and the bar dims
   to the out-of-combat opacity. (Answers: is consumption reported.)
3. Sap or Distract a mob and stand still: the border goes white again the moment
   Energy is full - the case the feature is for.
4. `/bs debug` then `/reload`, read the saved `debug` line `bar: poised=…
   border=…`: it names the spell id found, or `none`, or `unavailable`. (Answers
   whether the aura is reported at all, without guessing.)
5. Warrior, hunter and cat-druid alt out of combat at full power: the border
   never changes.
6. Combo beads, splatters and the other bar settings behave exactly as before; a
   rogue at full energy with no Poised (below level 18, or the aura not reported)
   is still hidden by "Hide when idle out of combat".

## Workflow follow-up

- Test in game, fix what the in-game checks show, then `/openspec-archive-change`
  so the delta merges into `openspec/specs/energy-bar/spec.md`.
- Commit with the repo's own identity (`stixes` noreply); remote operations only
  on the user's request. No release work in this change.
