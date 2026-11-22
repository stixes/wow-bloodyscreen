# Tasks

## 1. Harness first (so the existing behaviour is pinned before the code moves)

- [x] 1.1 `tests/harness.lua` `run()`: call `scripts.OnUpdate()` only when it is non-nil (the bar call is already guarded); verify `luajit tests/harness.lua BloodyScreenForever` is still all PASS on the unchanged addon
- [x] 1.2 Add the invariant to `run()`: on every simulated frame, if `vis() > 0` then `scripts.OnUpdate ~= nil`; count violations and report one check near the end ("never idle with a splatter on screen: 0 violations"); verify it PASSes on the unchanged addon (the script is always attached today)

## 2. Splatter script (BloodyScreenForever.lua)

- [x] 2.1 Add `ns.COMBO_SETTLE = 3` (the only value to change if the in-game trace in 6.1 measures a slower late count; s after a target switch in which the late combo count is still polled, design decision 4) and an `InCombat()` helper: `inCombat` or a `Readable()` true `UnitAffectingCombat("player")`; and a local `settleStart`, set in `handlers.PLAYER_TARGET_CHANGED` and `handlers.PLAYER_ENTERING_WORLD` (separate from `lastTargetSwitch`, which drives the crossfade; design decision 4); verify luacheck clean
- [x] 2.2 Move the `OnUpdate` body into a local `AreaUpdate` that uses the `area` upvalue, add `awake`, `Wake()` and `Sleep()` (design decision 1), forward-declared near the top (like `PlaceSplatter`) because `ShowSlot`, `DetachAll` and `ClearNow` are defined above the handler; don't attach at creation; `if not db then Sleep() return end`; at the end of a full pass, `Sleep()` when the busy predicate (design decision 2) is false; verify the harness's existing checks all PASS with unchanged expectations
- [x] 2.3 Wake in `ShowSlot`, `DetachAll`, `ClearNow`, `handlers.PLAYER_TARGET_CHANGED`, `handlers.PLAYER_ENTERING_WORLD` and `handlers.PLAYER_REGEN_DISABLED`, not in the generic event dispatcher (design decision 5); verify the invariant from 1.2 still reports 0 violations and every existing check PASSes
- [x] 2.4 Update the header comment ("polled" → polled while a splatter is shown, in combat or just after a target switch); verify by reading it

## 3. Energy bar poll (EnergyBar.lua)

- [x] 3.1 Add a local `settleStart`, set in the `PLAYER_TARGET_CHANGED` and `PLAYER_ENTERING_WORLD` branches; move the `OnUpdate` body into a local `BarUpdate` using the `bar` upvalue, with `awake`/`Wake()`/`Sleep()`; after each 0.05 s poll tick, `Sleep()` when the bar busy predicate (design decision 2) is false, using `ns.COMBO_SETTLE`; verify luacheck clean and all existing bar checks PASS unchanged (hideFull, quiet period, beads, crossfade, late count)
- [x] 3.2 Wake at the top of the bar's `OnEvent` and in `ns.ApplyBar`; export the bar's `awake` through `ns.BarDebug` (or a small `ns.BarAwake()`); verify existing checks PASS

## 4. `/bs debug` line and docs

- [x] 4.1 `/bs debug`: one line `idle: splatters=running|idle bar=running|idle`, saved into `db.debug` like the others; verify with a harness check that captures the printed lines (as the existing crit-line check does) and finds the line with both values
- [x] 4.2 README "Getting data out of the game": `/bs debug` also says whether the per-frame scripts are running; "Combo points" bullets: polled while there is something to show, in combat, or just after a target switch; verify by reading
- [x] 4.3 CHANGELOG under `## Unreleased`: the addon now does nothing between fights (no per-frame work while nothing is shown), `/bs debug` shows it; no TOC version bump; verify by reading the section

## 5. New harness checks (automated; all must PASS)

Append them at the end of the harness, before the failures summary. The end state there is a fresh DB from the migration check (`critshared`, max 6), a warrior, `GetComboPoints` nil: start the group with `/bs default`, then set the class per check (rogue for 5.1, 5.5, 5.6).


- [x] 5.1 Idle: rogue out of combat (`fire("PLAYER_REGEN_ENABLED")`, `barState.onEvent(nil, "PLAYER_REGEN_ENABLED")`), full readable energy, no combo points, `ns.ClearNow()`, then `run(ns.COMBO_SETTLE + 0.5)` → `scripts.OnUpdate == nil` and `barState.onUpdate == nil`, bar alpha 0, no splatters
- [x] 5.2 Wake by crit: warrior, `crittimed`, in combat, crit while idle → `scripts.OnUpdate ~= nil` and 1 splatter; `run(ns.db.timer + 1)` → splatter gone and `scripts.OnUpdate == nil` again (warrior in combat with nothing shown idles)
- [x] 5.3 Warrior in combat, nothing shown: after `barState.onEvent(nil, "PLAYER_REGEN_DISABLED")` and one poll tick, `barState.onUpdate == nil`; a rage power event wakes it and the bar value updates (`barState.value`)
- [x] 5.4 Wake by `/bs test` while idle: script attached, `ns.db.max` splatters shown; after `run(4.6)` none shown and script detached
- [x] 5.5 Wake by target switch, out of combat, rogue on Automatic, while idle: `fire("PLAYER_TARGET_CHANGED")` + `barState.onEvent(nil, "PLAYER_TARGET_CHANGED")` with `GetComboPoints` returning 0, then 2 after 0.9 s with no event → 2 beads lit and 2 splatters fading in (step > 1 at first), both scripts attached; after spending to 0 by event and `run(ns.COMBO_SETTLE + 1)` → both detached
- [x] 5.6 Combat start keeps the combo poll: rogue idle, `fire("PLAYER_REGEN_DISABLED")` + bar event → both scripts stay attached after `run(ns.COMBO_SETTLE + 1)` with 0 points; a silent count change (no event) is picked up (as today's "baubles follow a late, eventless count change")
- [x] 5.7 Bar quiet period: idle bar, a power event (`energy=80`) wakes it and shows it at idle opacity; `energy=100` + event, `run(3.1)` → alpha 0 and `barState.onUpdate == nil`
- [x] 5.8 Settings: `ns.ApplyBar()` while idle reattaches the bar poll, which detaches again on its next 0.05 s tick (ApplyBar touches neither the quiet nor the settle timestamp); changing the trigger (`mode(...)`, which calls `ClearNow`) reattaches the splatter script for one pass, then it detaches
- [x] 5.10 Loading screen: rogue idle, `fire("PLAYER_ENTERING_WORLD")` + bar event, then `GetComboPoints` goes 0 → 2 after 1 s with no event → 2 beads and 2 splatters, both scripts attached until the points go and the settle window passes
- [x] 5.11 Settle window edge: a late eventless count arriving at `ns.COMBO_SETTLE - 0.1` s after an out-of-combat switch is still picked up (beads and splatters); the scripts detach once `ns.COMBO_SETTLE` has passed with 0 points
- [x] 5.12 Idle debug line: in the idle state of 5.1, `/bs debug` prints `idle: splatters=idle bar=idle`; right after a crit in combat it prints `splatters=running` (extends 4.1)
- [x] 5.13 Trace stays free: capture the `/bs trace` frame in the `CreateFrame` stub; it is hidden (so gets no OnUpdate) before `/bs trace`, shown while tracing, hidden again after the second `/bs trace`
- [x] 5.14 Crit and bar behaviour unchanged with the scripts idling between events: rerun the existing warrior checks (crit splatters, timer fade, rage bar hide/show) after an idle stretch (`run(ns.COMBO_SETTLE + 1)` with nothing shown) and they give the same results
- [x] 5.9 Run the full suite: `luacheck BloodyScreenForever/` clean and `luajit tests/harness.lua BloodyScreenForever` all PASS, with no existing check's expectation edited; `openspec validate idle-no-cost --strict` passes

## 6. In-game check (only what needs the real game)

Everything else (idle detection, every wake, fades, timers, crossfade, bar opacity and hide rules, `/bs test`, the debug line) is covered by the harness in groups 1 and 5. This check measures the one unmeasured API behaviour and confirms the idle state on the real client. It runs alongside implementation; it does not block it.

- [ ] 6.1 Clear your target, stand still at full energy for 5 s, then `/bs debug`: the chat shows `idle: splatters=idle bar=idle`. (Owner decision 2026-11-22: the out-of-combat late-combo-count measurement is dropped. Switching targets with combo points out of combat practically only happens in PvP, and the worst case is beads updating a moment late; `ns.COMBO_SETTLE` stays 3 s, about 3x the ~1 s measured in combat. Left to a bug report.)

## Workflow follow-up

- Optional, separate from this change: one more `/bs trace` run (switch A→B in combat, wait 3 s, hit B back to A's old count, look for `UNIT_POWER_UPDATE ... COMBO_POINTS`) tells whether the in-combat poll for combo characters could be dropped later (design Open Questions).
- Archive with `/openspec-archive-change idle-no-cost` once 6.1 passes; `skip_specs`, so no spec is merged. Releasing is separate.
