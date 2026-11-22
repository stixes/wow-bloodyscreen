# Design: the addon costs nothing when idle

## Context

See proposal.md for why. Three frames have `OnUpdate` scripts today:

| Script | Runs | Work per run |
|---|---|---|
| `area` (BloodyScreenForever.lua, `area:SetScript("OnUpdate", …)`) | every frame, always | preview end; per trigger: combo poll (`ReadCombo` every frame), `crit` fade on `UnitAffectingCombat`, `crittimed` per-slot timers, `critshared` shared timer; then fade-out / fade-in steps of every slot and every ghost |
| `bar` (EnergyBar.lua, `bar:SetScript("OnUpdate", …)`) | every frame while the bar is shown; real work every `POLL` = 0.05 s | `UpdateCombo()` (bead poll) and, out of combat, `UpdateAlpha()` (the `QUIET` 3 s "at rest" rule) |
| `tracer` (`/bs trace`) | only while tracing | already gated: the frame is `Hide()`n at creation and shown only by `/bs trace`; hidden frames get no `OnUpdate`. No change. |

The bar is also already free when "Show energy bar" is off (`bar:SetShown(false)`).

### Which per-frame work is truly needed

- **Bar value: none.** `SetMinMaxValues` / `SetValue` and the text are already set from power events (`UpdateValue` in `OnEvent`), never from `OnUpdate`. The secret power value never needs a per-frame push.
- **Bar opacity: only until the quiet test has run once.** Out of combat, `IsFull()` either compares readable values (they change only with a power event) or uses "3 s since the last power change" (true for good once reached, until the next event). So after one poll at or past `lastPowerChange + QUIET` the decision cannot change without one of the bar's events. In combat `UpdateAlpha` is not called from the poll at all.
- **Beads: only for combo characters, and only when the count can change without an event.** Measured (config.yaml): after a target switch `GetComboPoints` goes to 0 at once and gets the real count ~1 s later with no event. Drops without an event (target dies, despawns, points expire) are possible and unmeasured, so the poll also stays on while points are shown.
- **Splatters: only while something is shown or pending.** Fades and fade-ins are time-stepped; `crittimed` timers live only on shown slots (`HideSlot` zeroes them); `critshared` uses `globalTimer`; `crit` fades on `UnitAffectingCombat` only matter while a splatter is shown; the preview has `previewUntil`. Combo trigger: the same late-count rule as the beads.
- **Combo characters in combat: keep the poll for all of combat** (decision 3).

## Goals / Non-Goals

**Goals:**
- Zero `OnUpdate` calls from this addon while idle: out of combat (or in combat for non-combo characters), nothing shown, nothing pending.
- The same visible behaviour, proven by the existing harness checks passing with unchanged expectations. The one theoretical difference (a combo count arriving out of combat more than 3 s after a switch or loading screen) is listed under Risks and measured first (decision 7).

**Non-Goals:**
- Making in-combat polling cheaper for rogues and cat druids (it stays as today).
- Changing the 0.05 s bar poll rate, the fade timing, or any threshold other than adding the settle window.
- Reducing event handler cost (events are already cheap and only fire when something happens).
- A setting to turn this off.

## Decisions

### 1. Detach with `SetScript("OnUpdate", nil)`, reattach with the same function

Each file keeps its handler in a local (`AreaUpdate`, `BarUpdate`) and an `awake` boolean. `Wake()` does `if not awake then awake = true; frame:SetScript("OnUpdate", fn) end`. `Sleep()` does `awake = false; frame:SetScript("OnUpdate", nil)`, called from inside the handler at the end of a full pass when the busy predicate is false.

- Why: `SetScript(…, nil)` and setting a script from inside itself are long-standing, version-independent frame API (hyper compatible). Nothing new is needed from the Forever client.
- The handlers refer to the `area` / `bar` upvalues, not `self` (the harness calls `scripts.OnUpdate()` with no arguments).
- The local `awake` flag, not `GetScript`, decides whether to call `SetScript` (cheap, and the harness stub has no real `GetScript`).
- Alternatives: `Hide()`/`Show()` the frame (rejected: hides the splatters and the bar themselves); a separate hidden "ticker" child frame shown only when busy (works, but adds a frame for no gain over `SetScript`); `C_Timer.NewTicker` (moves the cost, doesn't remove it, and fade steps want per-frame timing); one-shot `C_Timer.After` for the quiet test (precise, but a second mechanism; the poll is already there).

### 2. One busy predicate per frame, evaluated after a complete pass

The handler always does its full current work first (including the combo read), then decides. A wake therefore always gets at least one complete pass, so an event that wakes the script can never be missed by sleeping before the read.

Splatters (`area`), after the pass:

```
busy = previewUntil > 0 or #ghosts > 0 or globalTimer > 0
    or any slot's texture is shown          -- covers fading, fading in, crittimed timers
    or (mode == "combo" and (InCombat() or now - settleStart < SETTLE))
```

Bar, after a poll tick (the predicate is only evaluated on the 0.05 s ticks):

```
busy = (not inCombat and now - lastPowerChange < QUIET)        -- quiet test not yet run past 3 s
    or (baubleRow:IsShown()                                    -- combo character
        and (inCombat or (lastCur or 0) > 0 or now - settleStart < SETTLE))
```

`if not db then Sleep() return end` at the top of the splatter handler (before `ADDON_LOADED`); the splatter script starts detached and `ADDON_LOADED` → `ApplyLayout` → `ClearNow` wakes it.

**Secret values:** neither predicate reads power. They use timestamps, booleans, frame visibility, `lastCur` (already a guarded, readable number or nil) and, for `InCombat()`, `UnitAffectingCombat` behind the existing `Readable()` guard. No new read of a possibly secret value is added.

### 3. Combo characters keep polling for all of combat

`InCombat()` in the splatter file is `inCombat or (Readable(uac) and uac)` with `uac = UnitAffectingCombat("player")`, the same either-signal test `OnUnitCombat` uses. The bar uses its `inCombat` (REGEN events, seeded at `PLAYER_ENTERING_WORLD`).

- Why: combat is not idle, and there is at least one unmeasured eventless case: hold N points on A, switch to B, wait past the settle window, hit B back up to N. `UnitPower(ComboPoints)` is stale at N and may not change, so `UNIT_POWER_UPDATE` may not fire. Keeping the in-combat poll keeps today's behaviour exactly where the risk is.
- Using the either-signal test (not `inCombat` alone) matters after a `/reload` mid-fight: the splatter file's `inCombat` starts false and no `PLAYER_REGEN_DISABLED` follows, but `PLAYER_ENTERING_WORLD` → `ClearNow` wakes the script, and `UnitAffectingCombat` keeps it awake. This adds no new seeding and changes no crit-counting behaviour.
- Alternative: idle in combat too, relying on events plus the settle window. Cheaper for rogues, but it bets on the unmeasured case; can be revisited after a `/bs trace` run.

### 4. Settle window after a target switch: `SETTLE = 3` s

One constant, defined in BloodyScreenForever.lua as `ns.COMBO_SETTLE = 3` and read by EnergyBar.lua, so both use the same window. The measured late count arrives ~0.9 s after the switch; 3 s is more than three times that and longer than `CROSSFADE_WINDOW` (1.5 s). It only bounds how long an out-of-combat poll lasts after a switch; a count arriving later than 3 s out of combat would be picked up on the next event (hit, spend, combat start, another switch). Each file keeps a new `settleStart` timestamp, set on `PLAYER_TARGET_CHANGED` and on `PLAYER_ENTERING_WORLD` (a loading screen or `/reload` can also leave the count to arrive late). It is separate from the splatter file's `lastTargetSwitch` on purpose: that one drives the crossfade (`SwitchFade`), and starting it on a loading screen would make points fade in where today they pop.

### 5. Wake points

Splatters: targeted wakes at the structural choke points, not in the generic event dispatcher (which receives `UNIT_POWER_UPDATE` for every power token and `UNIT_COMBAT` for every hit on the target, and would reattach the script on each regen tick or watched fight):

| Wake in | Covers |
|---|---|
| `ShowSlot` | every splatter (combo, crits, `/bs test` preview, the next-frame `C_Timer.After(0, OnCombo)`); guarantees "a splatter is shown ⇒ the script is attached" |
| `DetachAll` | ghosts from a target switch |
| `ClearNow` | trigger change (settings dropdown, `/bs reset`), layout (`ApplyLayout` from `ADDON_LOADED`, `PLAYER_ENTERING_WORLD`, display/UI scale, max/area sliders), druid form change re-resolving Automatic. One pass, then idle if nothing is due. |
| `handlers.PLAYER_TARGET_CHANGED`, `handlers.PLAYER_ENTERING_WORLD` | settle window (`settleStart`; any mode, harmless outside combo) |
| `handlers.PLAYER_REGEN_DISABLED` | in-combat poll for combo characters |

Settings with no callback (`timer`, `size`, `avoidCentre`) need no wake: they are read when a splatter is shown or while one is shown (and so awake).

Bar: wake at the top of its own `OnEvent` (it only registers player power events, `PLAYER_ENTERING_WORLD`, the REGEN events and `PLAYER_TARGET_CHANGED`, none of which fire while truly idle; at full power no power events arrive) and in `ns.ApplyBar` (every bar setting, `/bs reset`, and setup). The bar starts awake from `ApplyBar` in `SetupBar`.

Each frame wakes only from its own events, matching how the harness feeds them separately (`fire` for the splatter frame, `barState.onEvent` for the bar).

### 6. `/bs debug` shows the state

One extra line, e.g. `idle: splatters=running|idle bar=running|idle`, from the two `awake` flags (the bar's exported via `ns.BarDebug`). This is the in-game check for the feature and a diagnostic if a splatter ever sticks. The line goes into the saved `debug` table like the others. Nothing new is read from the game; the measurement that matters uses the existing `/bs trace` (decision 7).

### 7. Measure the out-of-combat late count first

The settle window is the one assumption no kept poll covers: out of combat, after a target switch (or a loading screen), the new count must arrive within 3 s. The ~0.9 s figure was traced in combat. Before (or at the latest alongside) implementation, the user runs the existing `/bs trace` with no code change: out of combat, put points on mob A, switch to mob B and back to A, then `/reload` with points on a target; stop the trace and read it. Pass: each `GetComboPoints(player,target) = N` line lands under 3 s after its `PLAYER_TARGET_CHANGED` (or the trace start). If it does not, raise `COMBO_SETTLE` to cover the measured delay with margin before implementing.

### 8. Harness

- `run()`: call `scripts.OnUpdate()` only when it is non-nil (the bar call is already guarded).
- Invariant inside `run()`, every simulated frame: if `vis() > 0` (it counts every shown splatter texture, ghosts included) then `scripts.OnUpdate ~= nil`; count violations and report one check at the end. This turns every existing scenario (fades, timers, crossfade, preview) into a "never asleep with something on screen" test for free.
- Existing checks keep their expectations. Several rely on eventless changes being picked up (lines ~211, ~247, ~294 of today's harness); they must still pass because those happen inside a wake window (visible splatters, the quiet period, the settle window).
- New checks: both scripts nil when idle (out of combat, nothing shown, quiet period and settle window passed); each is reattached by its wake (crit in combat, `/bs test`, target switch with a late eventless count, power event, combat start, a settings change); the warrior in combat with nothing shown has both nil; `/bs debug` prints the idle line.

## Risks / Trade-offs

- [A wake point is missed and a splatter sticks on screen, or a fade freezes] → `ShowSlot` and `DetachAll` wake unconditionally, so anything that can be shown is covered; the harness invariant checks it on every simulated frame; `/bs debug` shows the state in game.
- [Out of combat, a count arrives later than 3 s after a target switch or loading screen (lag)] → beads/splatters update on the next event (hit, spend, combat start, switch) instead of by poll. Today's always-on poll would catch it, so this is the one theoretical visible difference. Window is 3x the measured delay. Listed as an in-game check.
- [Combo points drop silently out of combat while none are shown] → nothing to update (nothing shown); while points are shown the poll stays on.
- [Unmeasured: no `UNIT_POWER_UPDATE` when a hit brings the stale count back to the same value] → only happens in combat, where combo characters keep polling.
- [Bar hidden by "Show energy bar" off but awake] → harmless: hidden frames get no `OnUpdate`; `ApplyBar` re-evaluates on the next show.
- [Trade-off: one extra pass after each wake] → a wake costs at most one frame (splatters) or one 0.05 s tick plus the quiet/settle window (bar). Negligible.
- [Trade-off: rogues still poll in combat] → accepted (decision 3).

## Migration Plan

No saved-variable change. Rollback is reverting the commit. The changelog gets a line under `## Unreleased`.

## Open Questions

- Whether the in-combat poll for combo characters (decision 3) can be dropped later: answerable with one `/bs trace` run (switch A→B in combat, wait 3 s, hit B to A's old count, check for a `UNIT_POWER_UPDATE COMBO_POINTS` line). Does not change this change's tasks.
