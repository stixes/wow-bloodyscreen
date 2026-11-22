# Proposal: static WoW API check in CI

## Why

A misspelled or removed WoW API name (`UnitPowr`, `C_Timer.Aftr`, `Enum.PowerType.ComboPoint`, an API Blizzard dropped) only fails in the game today, as a Lua error after `/reload`. luacheck already flags unknown globals, but its `read_globals` list in `.luacheckrc` is typed by hand: a name is "known" because someone added it, not because the Forever client has it, and fields of namespaces (`C_Timer.*`, `Enum.*`, `Settings.*`) are not checked at all. The list can drift from the game without anyone noticing.

## What Changes

- **New: a list of the Forever client's API, generated in CI.** It is built from the `forever` branch of [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources/tree/forever), dumped in game on WoW Forever 1.60.1 (Interface 16001) by the KethoDoc addon. It covers global functions, `C_*` namespace functions, `Enum` with its nested values, FrameXML functions, global frames and mixins.
  - The upstream data is **not committed**: the upstream repo has no licence. Only a pin file is committed, holding the upstream commit SHA and the game build it matches.
  - CI downloads the files at that commit, caching them with `actions/cache` keyed on the pin, and generates the list on every run.
- **New: a small generator and update script** under `tools/wow-api/`. Locally, `tools/wow-api/update.sh` fetches the pinned files and writes the list to a git-ignored path. `update.sh --pin <sha>` moves the pin to a new upstream commit.
- **Changed: `.luacheckrc`.**
  - When the generated list exists, it is the standard for `BloodyScreenForever/` instead of the generic `lua51` standard. Other repo Lua such as `tools/` stays plain Lua.
  - A short hand-kept overlay covers what the dump does not contain: the `Settings` table with the fields the addon uses, `PowerBarColor`, `WOW_PROJECT_ID`, and Lua constants such as `math.huge`.
  - When the list is absent, it falls back to today's hand-maintained `read_globals`. The edit and commit hooks therefore keep working offline without it.
- **New: a CI check that the check works.** A fixture file of known typos must make luacheck fail on every one of them. The fallback list misses most of them, so CI can't pass unless the generated list was loaded.
- **New: a CI warning when the pin is older than the TOC**, i.e. when `## Interface` was bumped (for example by the Forever patch watch PR) but the pin was not moved. It warns and does not fail.
- **Unchanged:** CI keeps its syntax, lint and harness steps, and the lint step knows more. The Claude Code lint and pre-commit hooks need no change of their own.
- **Docs:** the README dev loop explains how to fetch the list locally and how to move the pin after a Forever patch, and the `.luacheckrc` comments say the same.

Classes and power types affected: none. This is tooling only; the addon's code and in-game behaviour do not change, and the release zip (`tools/package.sh` archives only `BloodyScreenForever/`) does not grow.

No new setting.

API behaviour relied on that has not been measured in game: none. The check only tests that names exist in the Forever client's dump; it says nothing about how they behave (secret values, combo point timing), which stays with the harness and in-game checks.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No player-visible behaviour changes, so the change declares `skip_specs`. The existing requirements in `splatter-triggers`, `combo-beads` and `energy-bar` keep holding, and the harness must stay all PASS unchanged.

## Impact

- New files (committed): `tools/wow-api/gen.lua`, `tools/wow-api/update.sh`, `tools/wow-api/pin`, `tools/check-api-typos.sh`, `tests/api-typos.lua`.
- New files (git-ignored, generated): `tools/wow-api/forever-api.lua`, `tools/wow-api/cache/`.
- Changed files: `.luacheckrc`, `.gitignore`, `.github/workflows/ci.yml` (cache, generate, fixture, staleness warning), `README.md` (dev loop, Forever patch step).
- Not changed: addon code, the harness, the hooks under `tools/hooks/`, `openspec/config.yaml`, `CHANGELOG.md` (nothing user-visible).
- Dependencies: no new tool. luacheck and luajit are already used. There is one new GitHub Action, `actions/cache`, pinned to an exact release tag. CI reads the upstream data over the network on a cache miss, pinned by commit SHA, with no secrets.
- Complements the open `patch-self-check` change: that one checks API *behaviour* in game at login, this one checks API *names* before code reaches the game.
