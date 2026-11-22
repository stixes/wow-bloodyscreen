# Proposal: the addon costs nothing when idle

## Why

Two `OnUpdate` scripts run on every rendered frame for the whole session, even when nothing is on screen and nothing is about to change: the splatter frame's pass (`BloodyScreenForever.lua`, fades, timers, the combo point poll) and the energy bar's 0.05 s poll (`EnergyBar.lua`, combo beads and the out-of-combat opacity check). Standing in a city at full energy, the addon still reads combo points and walks its slot table 60+ times a second. An addon that only draws blood now and then should cost nothing between fights.

## What Changes

- The splatter frame's per-frame script detaches itself on the first frame with nothing to do: no splatter or ghost shown, no `/bs test` preview pending, no crit timer running, and (for combo characters) not in combat and not just after a target switch. It reattaches when work appears: a splatter is shown, a target switch, combat starts, the trigger or layout is re-applied.
- The energy bar's poll detaches itself once the bar has nothing left to settle: out of combat, more than the 3 s quiet period since the last power change or combat end, and (for combo characters) no points on the target and no recent target switch. Any of the bar's own events, and any bar setting change, reattach it.
- Combo characters keep today's poll for all of combat, and for a few seconds after every target switch, because the new target's count arrives late with no event. Out of combat with nothing showing, they cost nothing either.
- `/bs debug` gets one line saying whether each of the two scripts is running or idle, so the idle state can be checked in game.
- The `/bs trace` frame is already free when tracing is off (it is hidden, and hidden frames get no `OnUpdate`); no change there. The same holds for the bar when "Show energy bar" is off.

No player-visible change in splatters, beads or the bar: same fades, timers, crossfades, opacity and hide rules, same `/bs test` preview.

Classes and power types affected: all of them, with no visible difference.
- **Warriors, bear/caster druids and other non-combo characters:** both scripts idle whenever nothing is shown, in or out of combat (the bar also idles in combat, since its value is already drawn from power events).
- **Rogues and cat-form druids:** both scripts idle out of combat with no combo points and no splatters; in combat they poll as today.

No new setting. This is an internal saving with no trade-off for the player to choose.

Relies on, not yet measured in game (build 16001):
- Out of combat, combo points on the target only change without an event right after a target switch or a loading screen, and the late count arrives within the settle window (3 s; measured ~0.9 s in combat). Neither the out-of-combat switch nor the loading screen has been traced; the tasks start with a `/bs trace` run (no code change) to measure it.
- Gaining a combo point always fires `UNIT_POWER_UPDATE` with `COMBO_POINTS`, except possibly when the stale `UnitPower` value happens not to change (switch, then hit the new target back to the old count). That case starts or continues combat, where the poll keeps running, so it is covered either way; a `/bs trace` run can confirm it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No requirement changes; the change declares `skip_specs`. The existing requirements in `splatter-triggers`, `combo-beads` and `energy-bar` must keep holding, and the harness checks behind them must pass unchanged.

## Impact

- Code: `BloodyScreenForever/BloodyScreenForever.lua` (splatter `OnUpdate` becomes attach/detach, wake points in `ShowSlot`, `DetachAll`, `ClearNow`, target change and combat start; `/bs debug` line), `BloodyScreenForever/EnergyBar.lua` (bar poll attach/detach, wake from its events and `ApplyBar`, last target switch time).
- Saved variables: none.
- Tests: `tests/harness.lua` (`run()` tolerates a detached script; an invariant that a visible splatter always has its script attached; new idle/wake checks).
- Docs: CHANGELOG entry under `## Unreleased`; README's "What had to change"/debug text if it describes the per-frame poll.
