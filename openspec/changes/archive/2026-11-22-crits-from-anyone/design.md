# Design

## Context

See proposal.md (Why). Today, crits arrive through `UNIT_COMBAT(unit, action, flagText)`: the handler takes only `unit == "target"`, skips a secret `flagText` (counted as `secret-flag`), needs `flagText == "CRITICAL"` and, when readable, `action == "WOUND"`. Then the strict check drops the crit unless the player is auto-attacking (`PLAYER_ENTER_COMBAT`/`PLAYER_LEAVE_COMBAT`), auto-repeating (`START/STOP_AUTOREPEAT_SPELL`), or within `CAST_WINDOW` (1.5 s) of `UNIT_SPELLCAST_SUCCEEDED` for the player. Those four events and the three state variables exist only for that check.

Settings are at version 9 (`SETTINGS_VERSION`); `strict = true` is in `ns.DEFAULTS`, so every saved table holds it.

## Goals / Non-Goals

**Goals:**
- Remove the strict filter completely: code, setting, command, debug output, docs.
- Keep every existing guard on the crit read (target only, secret-safe, `WOUND` + `CRITICAL`).

**Non-Goals:**
- Telling the player's crits apart from others' (the API doesn't allow it; that is the point of the change).
- New throttling or a group mode. Existing settings (max splatters, trigger) are the controls.
- Renaming the trigger keys or the dropdown labels' "Crits - …" short form.

## Decisions

### Delete the filter rather than default it off
The user wants strict gone, not hidden. Deleting it also removes the auto-attack, auto-repeat and cast tracking (four event registrations, three locals, `CAST_WINDOW`), which nothing else reads. Alternative: flip the default to off and keep `/bs strict on` as an escape hatch. Rejected: it keeps a hidden setting and its explanation alive for a niche case, against the "few settings" preference.

### Keep the crit read's guards as they are
`unit == "target"`, the `Readable()` checks on `flagText` and `action`, and the `stats.crits` / `stats.counted` / `stats.secretFlag` counters stay. With no filter, `counted` equals `crits`, so `/bs debug` reports `crits on target: seen=N shown=N secret-flag=N`; the `dropped(strict)`, autoattack, autorepeat and strict fields are removed. Every value from `UNIT_COMBAT` may be secret and stays guarded.

### Migration: settings version 10 drops `strict`
Add `strict` to the list of retired keys that `ADDON_LOADED` sets to nil, remove it from `ns.DEFAULTS`, and bump `SETTINGS_VERSION` to 10. The retired-keys list already runs on every load, so the drop is idempotent and needs no version check of its own; the version bump records the format change for future migrations. `/bs reset` copies `ns.DEFAULTS`, so it no longer writes `strict`.

### `/bs strict` falls through to the unknown-command path
Remove its branch and help line. Whatever the slash handler does for an unknown command (currently it prints help) is what `/bs strict` does. No special "this was removed" message: it would be a third place to explain a feature that no longer exists.

### "Crits - hide when combat ends" out of combat
Unchanged behaviour, worth noting because crits from anyone now arrive while the player is out of combat (watching someone else fight their target). That trigger already fades everything each frame while `UnitAffectingCombat("player")` is false, so such crits flash and fade at once. The timed triggers show them for the normal timer. No new code.

### Crits count only while the player is in combat
Added after the in-game check showed that targeting someone else's mob splatters while you stand idle. A crit counts when the player is in combat by either signal: `UnitAffectingCombat("player")` (readable-guarded) or a flag tracked from `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`, like the energy bar's (`InCombatLockdown()` lags behind those events). Either-signal acceptance is there for the opening crit: whether `UNIT_COMBAT` for the hit that starts combat arrives before the game reports combat hasn't been measured, and an opener that arrives first would be dropped. The check sits in the crit handler, so it covers every crit trigger and Automatic; `/bs test` and combo points don't go through it. Already-shown splatters keep their timers (spec: they fade in or out of combat). This makes the "hide when combat ends" note about out-of-combat crits flashing moot. Alternative: only `UnitAffectingCombat`. Rejected: one signal, and the ordering risk above has no fallback.

### Narrative and wording
Tooltip, help and docs describe crits as hits *your target* takes ("your target is taking a beating"). The dropdown labels stay short ("Crits - hide when combat ends", …) because they must fit the Settings dropdown; the tooltip carries the narrative. The Automatic label ("…crits for others") stays accurate.

## Risks / Trade-offs

- [Big groups keep the crit triggers at the splatter cap] → Accepted (proposal). Players can lower the max splatters or switch trigger; the README says so.
- [`UNIT_COMBAT` might not fire for others' crits on the target, contrary to the assumption] → Measure first: in a group, `/bs debug` before and after a fight; `seen` rising while the player isn't attacking confirms it. If it doesn't fire, the change still holds for the player's own crits, and the docs must not promise others' crits.
- [DoT crits may not arrive as `WOUND` + `CRITICAL`] → Same measurement (watch `seen` while only a DoT ticks). Docs say "critical hits your target takes" without promising DoTs.
- [The opening crit may arrive before either combat signal and be dropped] → In-game check on a fresh pull (manual test). If it is dropped, a short grace window after the player's own `UNIT_SPELLCAST_SUCCEEDED` or auto-attack start could cover it; not built unless needed.
- [Players who relied on strict lose it] → It was hidden (slash command only) and on by default, so few chose it. CHANGELOG says what changed.

## Migration Plan

- Settings version 9 → 10 on first load drops `strict`; nothing for the player to do.
- Downgrading to 0.18.x: its defaults loop re-adds `strict = true`, so the older behaviour comes back on its own.

## Open Questions

- Whether others' crits and DoT crits reach `UNIT_COMBAT` on the target (measured in game, see Risks). The answer changes only how the docs phrase it, not the code.
