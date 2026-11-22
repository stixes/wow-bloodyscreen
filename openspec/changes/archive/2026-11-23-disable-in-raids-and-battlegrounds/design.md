# Design

## Context

See proposal.md (Why) and the delta spec for the requirements.

Splatters reach the screen through three trigger paths in `BloodyScreenForever.lua`: the `mode == "combo"` branch of the area's `OnUpdate` (it polls combo points every frame), `OnCombo` (from `UNIT_POWER_UPDATE` and target switches), and `OnCrit` (from `OnUnitCombat`). Which path runs depends on `mode`, the resolved trigger set by `ResolveMode()`. `ResolveMode()` is called from `ClearNow()` and from `UNIT_DISPLAYPOWER`; `PLAYER_ENTERING_WORLD` calls `ApplyLayout()`, which calls `ClearNow()`. So every loading screen, including entering or leaving an instance, already clears splatters and re-resolves the trigger.

`Test()` calls `ShowSlot` directly and the `previewUntil` branch in `OnUpdate` runs before the mode branches, so the preview doesn't go through any trigger.

Settings: `SETTINGS_VERSION = 10`. `ADDON_LOADED` fills every `ns.DEFAULTS` key that is nil in the saved table, and `/bs reset` copies all of `ns.DEFAULTS`. In `Options.lua`, `Check()` is local to the Energy bar section and calls `ns.ApplyBar`; the "Avoid the centre" checkbox uses `Settings.CreateCheckbox(category, Setting(...), tooltip)` directly.

## Goals / Non-Goals

**Goals:**
- Two independent switches, splatters only; outside battlegrounds and arenas nothing changes unless the raid box is ticked.
- One place that decides "disabled here", so no trigger path can miss it.
- Every read of the instance API guarded; a missing or unreadable API means "not disabled".

**Non-Goals:**
- Raid groups outside instances (world bosses), dungeons, scenarios.
- Turning the energy bar or beads off (the bar has its own setting).
- Throttling or thinning splatters in big groups; a per-character or per-spec setting.

## Decisions

### Suppression is a resolved trigger: `mode = "off"`
`ResolveMode()` already turns `db.mode` into the trigger in effect, reports whether it changed, and is what `/bs debug` prints as "in effect". It gains one rule first: if the instance type is `"raid"` and `db.offInRaids`, or `"pvp"`/`"arena"` and `db.offInBattlegrounds`, the trigger in effect is `"off"`. Effects:
- The `OnUpdate` mode branches match none of `"off"`, so nothing is shown or polled; fades and ghosts keep stepping because that code runs after the branches.
- `OnCombo` and `OnTargetChanged` already return unless `mode == "combo"`.
- `OnUnitCombat` returns early for `"combo"`; extend that to `"off"`. `OnCrit`'s `else` branch treats any non-`"crit"` mode as a timed crit, so it also gets an explicit `mode == "off"` return (belt and braces; the stats counters then show crits seen while disabled under `seen` but not `shown`).
- Where `ResolveMode()` reports a change outside `ClearNow()`, the caller clears (as `UNIT_DISPLAYPOWER` already does), which gives "splatters stop at once".

Alternative: a separate `disabled` flag checked in each path. Rejected: four checks to keep in sync, and the `/bs debug` "in effect" text wouldn't show it.

### Detect by instance type, not group type
`IsInInstance()` returns `inInstance, instanceType`; `"raid"` for raid instances, `"pvp"` for battlegrounds, `"arena"` for arenas. `IsInRaid()` is not used: battleground groups are raid groups, so it would make the raid box fire in battlegrounds and the two settings would stop being independent; and it would cover world raid groups, which the conservative reading of "in raids" leaves out (owner question). Arenas fall under the battleground box: they are the other PvP instance, and the label stays short. If Forever has no arenas, that rule never matches.

The read follows the `GetComboPoints` pattern: skip if `IsInInstance` is nil, `pcall` it, and use the type only if it is a readable string; otherwise treat it as "none".

### When to re-check
- `PLAYER_ENTERING_WORLD`: already ends in `ClearNow()` → `ResolveMode()`; covers every loading screen (entering and leaving instances, login, `/reload`).
- `ZONE_CHANGED_NEW_AREA` (new registration): `if ResolveMode() then ClearNow() end`. A cheap second check in case the instance type isn't final yet when `PLAYER_ENTERING_WORLD` fires (unmeasured on Forever).
- The two checkboxes' change callbacks: same call, exposed as `ns.RecheckZone()` so `Options.lua` and the harness can use it (the harness's `Settings` stub swallows callbacks).
- No `GROUP_ROSTER_UPDATE`: group membership doesn't matter with instance-type detection.

### Settings: two booleans, raids off and battlegrounds on, no version bump
`ns.DEFAULTS.offInRaids = false`, `ns.DEFAULTS.offInBattlegrounds = true` (owner's decision). What a default-on key means for the existing code:
- Upgrade: the defaults loop in `ADDON_LOADED` sets a key only when it is `nil`, so old tables gain `offInBattlegrounds = true` (the intended behaviour change, announced in the CHANGELOG), and a saved `false` is never overwritten on later loads. No migration code or version check is needed, so `SETTINGS_VERSION` stays 10.
- `/bs reset` copies `ns.DEFAULTS`, so it ticks the battleground box again; that is what reset means.
- `Settings.RegisterAddOnSetting` gets the default from `ns.DEFAULTS` through `Setting()`, so the panel's own reset agrees.
- The harness starts outside any instance, so the existing checks are unaffected; the new checks set the box explicitly where independence is tested.

### Panel: under "Blood splatters"
Two `Settings.CreateCheckbox` calls after "Avoid the centre" and before the Preview button, each with a callback to `ns.RecheckZone`. They sit in the splatter section so the labels "Disable in raids" / "Disable in battlegrounds" read as "disable the splatters". Tooltips: "No blood splatters inside raid instances. The energy bar stays." and "No blood splatters inside battlegrounds (and arenas). The energy bar stays." `Check()` isn't reused: it is local to the Energy bar section and calls `ApplyBar`.

### `/bs debug` measures the API
One more debug line: `zone: IsInInstance=<inInstance>/<type> offInRaids=<b> offInBattlegrounds=<b>` (values through the same secret-safe `TV`-style formatting), and the existing "in effect" field shows `off` when disabled. This is the measurement for the unmeasured instance types: `/bs debug` inside a raid (and a battleground, if any) answers it.

### What the player sees on the way in and out
Entering or leaving through a loading screen clears splatters (existing `PLAYER_ENTERING_WORLD` behaviour). Ticking a box inside clears them at once; unticking resumes the trigger with nothing carried over. Splatters already fading when suppression starts are cleared by `ClearNow()` too, so there is no blood left on a loading-screen exit.

## Risks / Trade-offs

- [Forever's raids report a type other than `"raid"`, or `IsInInstance` is missing] → The setting silently does nothing (safe direction). In-game check: `/bs debug` inside a raid shows the type; adjust the rule if needed.
- [Instance type not final at `PLAYER_ENTERING_WORLD`] → `ZONE_CHANGED_NEW_AREA` re-checks; the in-game check covers it.
- [Forever has no battlegrounds] → The battleground box is an unused setting against "few settings". Owner question: ship it anyway or drop it.
- [A raiding rogue ticks the raid box and loses combo splatters too] → Intended by "disable"; the tooltip says "no blood splatters". Owner question whether the switch should cover crit triggers only.
- [World-boss raid groups still hit the crit cap] → Out of scope; owner question.

## Migration Plan

- No migration code; first load adds `offInRaids = false` and `offInBattlegrounds = true`; settings version stays 10. Players who don't want the battleground default untick it once (CHANGELOG says where).
- Downgrade: older versions ignore the two keys (no retired-keys entry clears them, and no code reads them), so they come back unchanged on re-upgrade.

## Owner decisions

Settled with the owner after the first draft:

1. Defaults: "Disable in raids" off, "Disable in battlegrounds" on (existing players get it on at upgrade; CHANGELOG says so).
2. Scope: splatters only; the energy bar and beads are untouched.
3. Triggers: all of them, combo points included.
4. A raid group outside an instance doesn't count.
5. Arenas count under the battleground box, and the box stays even if Forever has no battlegrounds.
