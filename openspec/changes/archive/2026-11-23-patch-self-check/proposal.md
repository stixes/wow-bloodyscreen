# Proposal: self-check after Forever patches

## Why

Everything the addon does rests on game API behaviour that was measured in game, not documented: which values are secret, which calls exist, what `UNIT_COMBAT` carries. A Forever patch can change any of it. Today a change shows up as silent breakage (no splatters, no beads) or as a Lua error on every power event, and the owner only learns of it from a player report. The daily patch watch (`tools/forever-patch.sh`, `.github/workflows/forever-patch.yml`) already opens a TOC bump PR when a new Forever version appears; the addon itself should tell, on the first login after the patch, whether what it relies on still holds.

## What Changes

- **New: a self-check at every login.** The addon reads the handful of values it relies on (class, power type, primary power and its maximum, combo points on the target, the Settings API) with every read guarded, and records what it saw. The crit flag of `UNIT_COMBAT` is checked on the first such event on the target in each session, because it can't be read without one.
- **New: one short chat line when something broke.** A part whose inputs are unusable is switched off for the session (energy bar, combo points, crit splatters, settings panel) and named in one line, e.g. `BloodyScreen: the game changed - energy bar off. Details: /bs debug`. Each broken part is announced at most once per game build and addon version, so later logins on the same build stay quiet while the part stays off. When everything passes nothing is printed.
- **New: results in the saved variables** under `selfcheck`, in the same one-line-per-item style as `/bs debug`, including the game build and addon version they were taken on. This is the measurement record for the owner after a patch.
- **Changed:** `/bs debug` re-runs the login checks, prints and saves their lines, and applies the result (a part that was switched off comes back if its check now passes). No new command.
- **Changed: Automatic falls back to crits when combo points are off.** A rogue or cat druid on Automatic whose combo points can't be read gets timed crit splatters (as any class without combo points) instead of nothing. The explicit "Combo points" trigger shows nothing while combo points are off.
- **Changed:** the "settings panel unavailable" line, printed at every login today, becomes part of the self-check line (once per build). The once-per-session "combo points are not readable" warning is not printed when the self-check has already switched combo points off.
- **Hardening:** reads of the class and power type token, and the energy bar's writes, are guarded so a value turning secret switches the part off instead of raising a Lua error before the self-check runs.

Classes and power types affected: all of them. Rogues and cat-form druids depend on the combo point checks (splatters and beads); warriors, bear and caster druids and every other class on a crit trigger depend on the crit flag check; every class with the energy bar depends on the power checks (energy, rage, mana). When all checks pass, nobody sees any difference.

No new setting. The check is automatic, quiet on success, and its only output is one line when a part goes off; there is nothing a player would want to tune. No new slash command: re-running is folded into `/bs debug`, which already exists to collect diagnostics.

Relies on, not yet measured in game (build 16001):
- What `GetComboPoints("player", "target")` returns with no target at login (0, nil, or an error). The plan treats nil or 0 as "nothing to judge", never as broken.
- Whether `UnitClass`, `UnitPowerType` and `UnitPowerMax` return their final values at the first `PLAYER_ENTERING_WORLD` of a cold login (not only after `/reload`).
- Whether a `StatusBar:SetValue` test write with the secret power value at login behaves like the writes during play (it is the same call the bar makes on every power event).
- Whether the `flagText` of non-critical `UNIT_COMBAT` events on the target is readable (the crit flag check uses the first event of any kind).
- The exact form of `GetBuildInfo()`'s version and build number on Forever (used as the "same build" key).

## Capabilities

### New Capabilities

- `api-self-check`: the addon checks the game API behaviour it depends on at login, switches off only the parts whose inputs are unusable, tells the player once per game build in one line, and keeps the results for diagnosis.

### Modified Capabilities

- `splatter-triggers`: "Automatic follows combo points on characters that have them" gains an exception for when combo points can't be read, and a new requirement says Automatic then uses timed crit splatters. Combo beads and the energy bar specs are unchanged: when every check passes they behave as specified, and the failing case is specified in `api-self-check`.

## Impact

- Code: `BloodyScreenForever/BloodyScreenForever.lua` (the checks, the saved record, the announce gate, the crit flag observation in the `UNIT_COMBAT` handler, guarded class/power token reads in `HasComboPoints`, combo off in `ResolveMode`, `/bs debug`, the settings-panel failure message), `EnergyBar.lua` (guarded writes and token reads, bar and beads off when their part is off, a test write for the check), `Options.lua` untouched (its pcall stays in place; the failure text moves into the self-check).
- Saved variables: new `selfcheck` table (build key, addon version, date, result lines, parts announced on that build and version). Not a setting, untouched by `/bs reset`; no settings version bump.
- Tests: `tests/harness.lua` gains a secret-aware `issecretvalue` stub, a changeable `GetBuildInfo`, print capture, and checks for: silent pass, one line and the right part off on failure, silence on the next login with the same build (part still off), and a new line after a build change.
- Docs: README ("Getting data out of the game", slash commands), CHANGELOG under `## Unreleased`.
- Unchanged: `tools/forever-patch.sh` and its workflow; the PR text can point at the self-check later, but this change doesn't touch it.
