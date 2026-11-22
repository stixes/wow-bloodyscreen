# Design

## Context

See proposal.md (Why). What the code does today, and where a patch would hurt:

- `ADDON_LOADED` runs `ResolveMode()` → `HasComboPoints()`, which compares `UnitClass` and `UnitPowerType` tokens directly (`class == "ROGUE"`, `token == "ENERGY"`). A token turning secret would raise a Lua error there, before anything else runs.
- `SetupBar()` → `ApplyBar()` → `UpdateValue()` calls `SetMinMaxValues`/`SetValue` unguarded, on every power event. The bar's event handler compares `token == powerToken`, and `IsFull()` indexes `EMPTY_AT_REST[powerToken]`.
- Combo reads (`ComboOnTarget`), the crit handler (`Readable(flagText)`), `IsFull` and `/bs debug` are already guarded with `IsSecret`/`Readable`/`pcall`.
- `pcall(ns.BuildOptions)` prints "settings panel unavailable (...)" on every login when it fails. `ReadCombo` prints a once-per-session warning in combo mode when no source is readable.
- `/bs debug` writes `db.debug = { date, line, line, ... }`; this is the style the record reuses.
- Saved variables are per account: one `db` for every character.

## Goals / Non-Goals

**Goals:**
- A wrong guess must cost little: false positives are the main risk, so "off" needs hard evidence.
- No Lua errors from any check or from a part that is off.
- One record the owner can read after a patch, with the values actually seen.

**Non-Goals:**
- Checking things that are already self-healing: `UnitPowerMax` turning secret only moves "hide when idle" to its 3-second fallback; `InCombatLockdown` lag is already worked around.
- Changing the patch-watch workflow, or bumping anything at release.
- Measuring new API behaviour beyond recording what the checks read.

## Decisions

### Run the checks at every login; announce once per build
The checks are a handful of guarded reads, as cheap as reading a stored verdict, so they run every session: `ADDON_LOADED` arms them, the first `PLAYER_ENTERING_WORLD` after it runs them (unit data is final there; `ADDON_LOADED` re-arms, so the harness can simulate a new login by re-firing both). Parts are switched off from this session's results only, never from a stored verdict, so a one-off wrong reading can't keep a part off for a whole patch.
Alternative: run only when the build changes and store which parts are off. Rejected: a transient bad read (cold login, loading lag) would stick until the next patch, and the stored state needs its own invalidation.

### The announce gate: per part, per build
`db.selfcheck` holds `build` (the key below), `version` (the addon's TOC `## Version`, read with `C_AddOns.GetAddOnMetadata` or the older `GetAddOnMetadata`, whichever exists, guarded) and `announced` (a set of part names). When either the build or the addon version differs from the stored one, `announced` is cleared, so a check added in an addon update gets reported on the current build too. An unreadable addon version counts as unchanged. At login every part that is off and not in `announced` goes into one line, then into `announced`. The crit flag result arrives later (next decision) and uses the same gate. This answers the per-account problem: a rogue logging in first can't use up the warrior's announcement of a broken rage bar, and a part already announced stays quiet on the next login.
Build key: `version .. "." .. build` from `GetBuildInfo()` (e.g. `1.60.1.12345`), so hotfix builds re-check too (owner's choice). Alternative: the interface number (`16001`), matching the TOC bump. Rejected: hotfixes don't change it.

### Three outcomes per check: ok, off, unknown
Each check yields `ok`, `off` (with a short reason) or `unknown`. Only `off` switches a part off, and only on hard evidence: the call threw, a needed value is a secret that `canaccessvalue` refuses, or a needed API is missing with no fallback. nil, 0 or an unexpected type at login is `unknown`: recorded, nothing switched off, nothing printed.

| Check | Read (all guarded) | off when | part |
|---|---|---|---|
| class | `UnitClass("player")` 2nd return | call throws, or a secret `canaccessvalue` refuses (nil = unknown) | combo |
| power type | `UnitPowerType("player")` token | call throws, or a refused secret (nil = unknown) | bar (and combo for druids) |
| bar write | `pcall` `bar:SetMinMaxValues(0, UnitPowerMax(..))` + `bar:SetValue(UnitPower(..))` | throws | bar |
| power max | `UnitPowerMax("player", type)` | never (recorded: readable / secret) | - |
| combo | `GetComboPoints("player","target")`, then `UnitPower(player, ComboPoints)` | both throw or are unreadable secrets (a missing `GetComboPoints` falls back) | combo |
| settings | the `BuildOptions` pcall result, plus `Settings` and `Settings.RegisterAddOnCategory` present | pcall failed | settings |
| crit flag | every `UNIT_COMBAT` on "target": `flagText` | first inaccessible secret of the session | crits |
| automatic | what `ResolveMode` picked | never (recorded) | - |

The power value itself is never compared or used in maths: the bar check only passes it to the bar, as the bar always does. The combo check runs for every class (cheap, and the record is useful), but "combo points" is announced only when the character has them (rogue, cat druid) or when the class itself can't be read (then nobody can tell, so everyone is told), so a warrior is never told about a part it doesn't use. Likewise the crit flag is always recorded, but "crit splatters" is announced only while a crit trigger is in effect. A part that is off but not announced stays out of `announced`, so it is still told when a character that uses it logs in.

### What "off" does per part
A table `ns.off[part] = reason` is the one switch the code consults.
- **bar**: `ApplyBar` hides the bar and returns; `UpdateValue` returns. `UpdateValue`'s writes are wrapped in `pcall` too: a write that throws mid-session sets `ns.off.bar` at once and notes it in the record, silently, so a patch can't spam errors on every power event even before the check runs. It is announced by the next login's check (whose test write fails the same way).
- **combo**: in `ResolveMode`, Automatic on a combo character resolves to `AUTO_CRIT` (`crittimed`), the same as for a class without combo points (owner's choice; spec delta in splatter-triggers). An explicit "Combo points" trigger resolves to no trigger: nothing is shown, no polling. The bead row hides either way. `ResolveMode` already reports a change, so applying a new `ns.off.combo` goes through `if ResolveMode() then ClearNow() end`, as `UNIT_DISPLAYPOWER` does. A working fallback (`GetComboPoints` broken, `UnitPower` readable) is recorded only, never announced (owner's choice).
- **class unreadable**: `HasComboPoints` returns false without comparing. That is the existing behaviour for any class without combo points, so Automatic gives crits; combo part is off.
- **crits**: the crit handler already drops crits with a secret flag; `ns.off.crits` only adds the gated announcement and the record.
- **settings**: `/bs` already falls back to help; the per-login print is removed in favour of the gate.
- `ReadCombo`'s once-per-session warning is skipped when `ns.off.combo` is set (the self-check line said it already).

### Guard the token reads at their use sites
`HasComboPoints`, the bar's event handler (`token == powerToken`), `UpdateType`'s `Color(powerToken)` and `IsFull`'s `EMPTY_AT_REST[powerToken]` check `Readable` first. An unreadable token means "no combo points" and the fallback colour; the check then switches the bar off. The self-check reports; these guards prevent the errors, because the code that would error runs before the first `PLAYER_ENTERING_WORLD`.

### Where the crit flag is observed
At the top of the `UNIT_COMBAT` handler, after `unit == "target"` and before the `mode == "combo"` return, on every event: the first readable flag sets the record line to `ok`; the first inaccessible secret of the session sets `off` (and stays off for the session), whatever came before. Any action counts (the flag field is the same field for hits, misses and heals). Watching every event, not latching on the first, covers secrecy that only applies in some situations (combat, instances), which is unmeasured. The cost is one `Readable` call per target event, which the handler already makes.

### The record and the message
`db.selfcheck = { build = key, announced = {..}, "2026-11-22 18:00:00 build 1.60.1.12345 project 1", "class: ok ROGUE", "power: ok type=3/ENERGY max=100 value=secret", "bar write: ok", "combo: ok GetComboPoints(target)=0", "settings: ok", "auto: combo", "crit flag: pending" }`. Line style follows `/bs debug` (`key: value`, secrets shown as `secret`, errors as `err`). The crit flag line is updated in place when it is observed. `/bs reset` doesn't touch it (it copies `ns.DEFAULTS` only), and `ADDON_LOADED` doesn't retire it.
The message, one line with the existing prefix: `BloodyScreen: the game changed - energy bar and settings panel off. Details: /bs debug`. Part names: "energy bar", "combo points", "crit splatters", "settings panel".

### No /bs selftest; /bs debug re-runs
`/bs debug` already exists to collect diagnostics into the saved variables. It calls the same check function, appends the result lines to `db.debug`, overwrites the record lines, and applies the results both ways (a part can come back on). It never announces. Results are re-applied (`ApplyLayout`/`ApplyBar`) only when a part's state changed, because `ApplyLayout` clears the splatters on screen. Alternative: a separate `/bs selftest`. Rejected (owner confirmed): one more command, and the re-run is diagnostics anyway.

## Risks / Trade-offs

- [False positive switches a working part off] → `off` needs a thrown call or a refused secret; nil/0 is `unknown`. `/bs debug` re-runs and restores. Every login re-checks, so nothing sticks.
- [Unit data not final at the first `PLAYER_ENTERING_WORLD` of a cold login] → Unmeasured. A not-yet-ready read is most likely nil or 0, which is `unknown`. Measure: the in-game check below reads the record after a cold login.
- [A later message (crit flag) breaks "one message"] → It can only appear once per build and addon version, and only when crits are actually broken and a crit trigger is in effect. Accepted by the owner.
- [Announcing once per build hides a part that stays broken] → The record and `/bs debug` show it every time; the patch-watch PR asks for an in-game test anyway.
- [Rogue on Automatic falls back to crits, which need the crit flag] → If both combo points and the crit flag are broken, the rogue sees nothing; the crit flag line is announced then because a crit trigger is in effect.
- [Interaction with disable-in-raids-and-battlegrounds, which makes `ResolveMode` return `"off"` in raids/battlegrounds] → Order in `ResolveMode`: the instance rule first (`"off"` wins), then `db.mode`, then the combo fallback. The self-check's "auto" record line shows `off` in a raid; that is not a failure. Whichever change lands second rebases `ResolveMode` onto the other.
- [Interaction with idle-no-cost, which detaches `OnUpdate` while idle] → The self-check adds no `OnUpdate` work: checks run from events (`PLAYER_ENTERING_WORLD`, `UNIT_COMBAT`, `/bs debug`). When a part is switched off or back on mid-session, the code that changes the trigger or shows the bar must call that change's `Wake()`, the same as any other trigger change. A bar that is off counts as idle.
- [The harness's first install run now goes through the checks] → The first `ADDON_LOADED`/PEW in the harness runs with `GetComboPoints` nil (fallback, must stay on) and `date` defined only later; tasks move the `date` stub up and add the cases.

## Migration Plan

- First load after the update: no `selfcheck` record, so it counts as a new build; checks run, and only a failure prints. Nothing else in the saved variables changes; no settings version bump.
- Downgrade: older versions ignore the `selfcheck` key.

## Open Questions

None. The owner answered the planning questions (crit fallback for Automatic, the later crit-flag line, build key, no `/bs selftest`, fallbacks recorded only, addon version resets the announcements).
