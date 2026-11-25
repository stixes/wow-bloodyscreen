# Tasks

## 1. Dead target reads as no combo points

- [x] 1.1 In `ComboOnTarget` (BloodyScreenForever.lua), return 0 when `pcall(UnitIsDead, "target")` gives a readable `true`; any error, secret, nil or missing `UnitIsDead` keeps today's behaviour. Verify: harness checks in 2.x.
- [x] 1.2 Add `{ "UnitIsDead(target)", TV(UnitIsDead, "target") }` to the `/bs trace` sample. Verify: harness trace check sees the new line.

## 2. Harness checks

- [x] 2.1 Add a `UnitIsDead` stub (default false) to tests/harness.lua.
- [x] 2.2 Replay the kill: 3 points on the target; the target dies (`UnitIsDead` true, `GetComboPoints` 0), then the count comes back as 3 while still in combat. Check that the splatters fade out once and the count is still 0 after 2 s (no comeback), and that the beads show 0.
- [x] 2.3 Same replay with `GetComboPoints` returning nil for the corpse and a stale `UnitPower` of 3: no comeback either.
- [x] 2.4 Next living target after the kill (`UnitIsDead` false, 2 points): 2 splatters fade in, beads show 2.
- [x] 2.5 `UnitIsDead` secret, throwing, or missing: the splatters follow the count as before (no change).
- [x] 2.6 Crit mode (warrior): a dead target doesn't change crit splatters; the self-check at login still reports combo ok.
- [x] 2.7 `luajit tests/harness.lua BloodyScreenForever` all PASS and `luacheck` is clean.

## 3. Docs

- [x] 3.1 CHANGELOG.md: a `## Unreleased` section above `## 0.20.0`, with one line: combo point splatters (and beads) fade out when your target dies, instead of flickering back over the corpse. Verify: the release tooling still finds the 0.20.0 section (heading order unchanged below).

## 4. In-game check (user)

- [ ] 4.1 Rogue: `/bs trace`, build 3+ combo points, kill the mob and keep the corpse targeted, then `/bs trace` again. You should see the splatters fade out once and not come back; the beads empty; the trace shows `UnitIsDead(target) = true` at the kill.
- [ ] 4.2 Then target the next mob and open: splatters and beads work as normal.
