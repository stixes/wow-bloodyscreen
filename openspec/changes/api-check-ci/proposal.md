# Proposal: static WoW API check in CI

## Why

A misspelled or removed WoW API name (`UnitPowr`, `C_Timer.Aftr`, `Enum.PowerType.ComboPoint`, an API Blizzard dropped) only fails in the game today, as a Lua error after `/reload`. luacheck already flags unknown globals, but its `read_globals` list in `.luacheckrc` is typed by hand: a name is "known" because someone added it, not because the Forever client has it, and fields of namespaces (`C_Timer.*`, `Enum.*`, `Settings.*`) are not checked at all. The list can drift from the game without anyone noticing.

## What Changes

- **New: a generated list of the Forever client's API** for luacheck, built from the `forever` branch of [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources/tree/forever) (dumped in game on WoW Forever 1.60.1, Interface 16001, by the KethoDoc addon). It covers global functions, `C_*` namespace functions, `Enum` with its nested values, FrameXML functions, global frames and mixins. It is committed to the repo outside the addon folder, pinned to one upstream commit, with that commit and the game build in its header.
- **New: a small generator and update script** under `tools/` that rebuilds the list from a given upstream commit. Network is needed only when updating the list, never in CI or the hooks.
- **Changed: `.luacheckrc`** uses the generated list as the standard for `BloodyScreenForever/` instead of the generic `lua51` standard (other repo Lua such as `tools/` stays plain Lua), plus a short hand-kept overlay for what the dump does not contain (the `Settings` table with the fields the addon uses, `PowerBarColor`, `WOW_PROJECT_ID`, `SlashCmdList`, Lua constants such as `math.huge`). The hand-maintained `read_globals` list of API functions goes away; `issecretvalue` and `canaccessvalue` come from the dump.
- **New: a CI check that the check works**: a fixture file of known typos must make luacheck fail, so a broken config can't go silently green.
- **New: a CI warning when the list is older than the TOC**, i.e. when `## Interface` was bumped (for example by the Forever patch watch PR) but the list was not regenerated.
- **Unchanged:** CI keeps its syntax, lint and harness steps; the lint step simply knows more. The Claude Code lint and pre-commit hooks pick the check up through `.luacheckrc` with no change of their own.
- **Docs:** the README dev loop and the `.luacheckrc` comments describe the new list and how to update it.

Classes and power types affected: none. This is tooling only; the addon's code and in-game behaviour do not change, and the release zip (`tools/package.sh` archives only `BloodyScreenForever/`) does not grow.

No new setting.

API behaviour relied on that has not been measured in game: none. The check only tests that names exist in the Forever client's dump; it says nothing about how they behave (secret values, combo point timing), which stays with the harness and in-game checks.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No player-visible behaviour changes, so the change declares `skip_specs`. The existing requirements in `splatter-triggers`, `combo-beads` and `energy-bar` keep holding, and the harness must stay all PASS unchanged.

## Impact

- New files: `tools/wow-api/` (generated `forever-api.lua`, the generator, the update script), a typo fixture for CI.
- Changed files: `.luacheckrc`, `.github/workflows/ci.yml` (fixture step, staleness warning), `README.md` (dev loop, Forever patch step).
- Not changed: addon code, the harness, the hooks under `tools/hooks/`, `openspec/config.yaml`, `CHANGELOG.md` (nothing user-visible).
- Dependencies: no new tool. luacheck and luajit are already used in CI and locally. The upstream data source is read only by the update script, pinned to a commit.
- Complements the open `patch-self-check` change: that one checks API *behaviour* in game at login, this one checks API *names* before code reaches the game.
