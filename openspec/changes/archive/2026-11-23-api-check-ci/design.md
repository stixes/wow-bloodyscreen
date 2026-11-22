# Design: static WoW API check in CI

## Context

See proposal.md for why. Today:

- CI (`.github/workflows/ci.yml`, job `test`) installs Ubuntu's `luajit` and `lua-check` packages (luacheck 1.1.2 on `ubuntu-latest`), then runs a luajit syntax check, `luacheck BloodyScreenForever/` and the harness. The local dev machine has luacheck 1.2.0.
- `.luacheckrc` uses `std = "lua51"` and a hand-kept `read_globals` list of about 30 WoW names. Plain names allow any field, so `C_Timer.Aftr` and `Settings.CreateSlidr` pass.
- The Claude Code hooks (`tools/hooks/lua-lint.sh` after each Lua edit, `tools/hooks/pre-commit-tests.sh` before a commit) run luacheck from the repo root with the same `.luacheckrc`.
- The game is WoW Forever: the Mainline/Midnight client with its own game type (`WOW_PROJECT_ID` 18, TOC game "Camelot", Interface 16001). Its API is neither Classic nor current Retail.

### Research (measured 2026-11-22)

Candidate data sets and tools, with the upstream state on that day:

| Candidate | Matches Forever? | State |
|---|---|---|
| [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources), branch `forever` | Yes: dumped in game on 1.60.1 build 70938 (`GetBuildInfo()` interface 16001, `WOW_PROJECT_ID` 18). `GlobalAPI.lua` has 7,092 names, 186 of them absent from `live` (12.1.5); only 7 `live` names are absent from Forever. Has `issecretvalue`, `canaccessvalue`, `GetComboPoints`, `C_Timer.*`. | Branch updated per Forever build (last 2026-11-14, commit `e230342a476eb4ef484ba7b34adc0da6ecc6acc1`). No licence file. |
| [Ketho/vscode-wow-api](https://github.com/Ketho/vscode-wow-api) LuaLS annotations + [LuaLS](https://github.com/LuaLS/lua-language-server) `--check` | Partly: core annotations are Mainline 12.0.1, so Forever-only names are missing; its FrameXML annotations come from [NumyAddon/FramexmlAnnotations](https://github.com/NumyAddon/FramexmlAnnotations), which has a `forever` branch. | MIT. Last release 0.22.3 (2026-02), master last changed 2026-06. LuaLS 3.19.2 (2026-10), 22 MB download, about 5 s per run. |
| [wowless](https://github.com/wowless/wowless) | Has a `wowf` product. | Self-described pre-alpha, Docker and CMake build. A headless client, far more than a name check. |
| Gethe/wow-ui-source, branch `forever` | FrameXML source only (no C API list). | Useful for Lua-defined tables such as `Settings` (68 `Settings.*` functions under `Blizzard_Settings_Shared`). |

Both realistic candidates were run on the addon plus a typo fixture (`UnitPowr`, `C_Timer.Aftr`, `Enum.PowerType.ComboPoint`, `GetComboPoint`, `issecretvalu`, removed `UnitAura`, `Settings.CreateSlidr`, `os.time`, `io.open`, `require`, a widget method typo `bar:SetValu`):

- **luacheck 1.2.0 with a std generated from BlizzardInterfaceResources `forever`** (prototype): the addon's own files were clean after a 4-name overlay. It caught every fixture typo except the widget method; `Settings.CreateSlidr` once `Settings` had hand-listed fields, and `os`/`io`/`require` once the generated std replaced `lua51`. Runs in well under 0.1 s.
- **LuaLS 3.19.2 with vscode-wow-api `d0b5b51fac` core + FramexmlAnnotations `forever` `78b00e04c8`**: 21 false positives on the addon (`Settings` ×12, `CreateSettingsButtonInitializer`, `CreateSettingsListSectionHeaderInitializer`, `PowerBarColor`, `SlashCmdList`, `MinimalSliderWithSteppersMixin.Label`). On the fixture it missed `C_Timer.Aftr` and `bar:SetValu`, even at check level Hint. `os`, `io` and `require` passed because of its default Lua 5.1 builtins, which could be switched off.

## Goals / Non-Goals

**Goals:**
- In CI, an unknown global, an unknown `C_*`/`Enum` field or an unknown hand-listed `Settings` field fails the build, and CI can't pass without the generated list.
- Locally, the hooks use the same check once the list has been fetched, and keep working offline without it, using today's hand list.
- The known-API list comes from the Forever client, not from memory, and records which build it came from. No upstream data is committed.
- Moving to a new Forever build means changing one committed pin.

**Non-Goals:**
- Widget method names (`frame:SetPoint`, `bar:SetValu`). luacheck can't see them and LuaLS didn't catch them either.
- Event names in `RegisterEvent("…")` strings. `Events.lua` in the same source could feed a later check.
- Argument counts and types. That is LuaLS territory and was too noisy here.
- API behaviour (secret values, combo point timing). That stays with the harness and the open `patch-self-check` change.

## Decisions

### D1. luacheck with a generated std, not LuaLS

luacheck is already installed in CI and on the dev machine, and is already wired into both hooks. It checks nested fields of read-only globals (warning 143). LuaLS would add a 22 MB tool, a second config and Mainline-only annotations, and in the measurement above it caught fewer typos and raised more false positives. wowless is out of proportion for a name check.

### D2. Source: BlizzardInterfaceResources, `forever` branch, pinned commit

It is the only source dumped from the Forever client itself, it is updated per Forever build, and it already contains the secret-value functions. Files used: `GlobalAPI.lua` (C API, including `C_*` namespaces and WoW's Lua library), `LuaEnum.lua` (`Enum` with values), `FrameXML.lua` (Lua functions from Blizzard's UI, such as `CreateSettingsButtonInitializer`), `Frames.lua` (global frames such as `UIParent`), `Mixins.lua` (mixin names; their fields stay unchecked). The update script downloads these five files by commit SHA from `raw.githubusercontent.com`, so a given SHA always produces the same list. The pinned SHA lives in one committed file, `tools/wow-api/pin` (D3).

Alternative: Ketho's generated LuaLS annotations (Mainline 12.0.1, not Forever) or Blizzard's `Blizzard_APIDocumentationGenerated` (documents the C API only, not what the client really exposes).

### D3. Don't commit the list; CI fetches and generates it at a pinned commit

The upstream repo has no licence file, so its data (even a list of API names) is not copied into this public repo. Downloading it at build time and using it as a check is not redistribution. The repo commits only the generator, the update script and a pin file.

- **`tools/wow-api/pin`** (committed) is a tiny key=value file holding the upstream commit SHA and the game version, build and interface number it was dumped on (`sha=e230342a476eb4ef484ba7b34adc0da6ecc6acc1`, `version=1.60.1`, `build=70938`, `interface=16001`). It is the single source of truth for which upstream data is used.
- **`tools/wow-api/update.sh`** downloads the five upstream files at the pinned SHA into `tools/wow-api/cache/<sha>/`, unless they are already there, and runs the generator. Output goes to `tools/wow-api/forever-api.lua`, a sorted `return { … }` table in luacheck's `read_globals` format with the pin in its header (about 0.5 to 0.8 MB, mostly `Enum` values). `update.sh --pin <sha>` rewrites `pin` for a new upstream commit, reading version, build and interface from that commit's `README.md` (`GetBuildInfo() => "1.60.1", "70938", …, 16001`), then regenerates. Both `tools/wow-api/cache/` and `tools/wow-api/forever-api.lua` are git-ignored.
- **CI**, before Lint: `actions/cache` restores `tools/wow-api/cache` with key `wow-api-${{ hashFiles('tools/wow-api/pin') }}`, and `tools/wow-api/update.sh` downloads only on a cache miss and always generates. Generating takes milliseconds, so only the downloads are cached. The action is pinned to an exact release tag (`actions/cache@v6.1.0`, released 2026-06-26), and the downloads are pinned by SHA. Nothing needs a secret.
- **Locally**, a developer runs `tools/wow-api/update.sh` once, as the README says. Until then the hooks use the fallback in D5.

Everything stays outside `BloodyScreenForever/`, so `tools/package.sh` (which archives only that folder) never ships it. The WoW std applies only to `BloodyScreenForever/` (D5), so the generator itself is linted as plain Lua.

Alternative considered: committing the generated list. That is simpler and fully offline, and a patch would show as a reviewable diff. The owner rejected it because of the missing upstream licence.

### D4. Generator in Lua 5.1, run with luajit

`tools/wow-api/gen.lua` reads the five files as data. The string lists are parsed with a pattern, and `LuaEnum.lua` is loaded in an empty environment with `setfenv`. Dotted names become nested `fields`, and leaf names become plain strings, which allow any sub-field. luajit is already a dependency and the prototype ran this way, so there is no Python and no new tool.

### D5. `.luacheckrc`: generated std when present, hand list otherwise

```lua
std = "lua51"                      -- tools/ and other repo Lua stay plain Lua
max_line_length = false
exclude_files = { "tests/", "dist/" }
globals = { ... }                  -- unchanged
local api = "tools/wow-api/forever-api.lua"
local f = io.open(api)
if f then
    f:close()
    stds.wow = { read_globals = dofile(api) }
    files["BloodyScreenForever/"] = { std = "wow" }
    read_globals = { -- not in the dump
        "PowerBarColor", "WOW_PROJECT_ID",
        math = { fields = { "huge", "pi" } },
        Settings = { fields = { "CreateCheckbox", ... } },
    }
else
    read_globals = { ... }         -- today's hand list, unchanged
end
```

Checked in the prototype with luacheck 1.2.0. With the file present, the addon is clean and all five fixture typos are reported. With the file absent, the addon is still clean on the hand list, and only `UnitPowr` of the fixture is reported.

- **Existence check, not `pcall`.** A missing file falls back. A present but broken file still errors loudly in `dofile`, so a bad generation can never quietly downgrade the check.
- **The fallback is today's hand list, kept as it is.** New API the addon starts using goes in both lists: in the fallback by name, and in the overlay only if the dump lacks it (e.g. a new `Settings.*` field). The `.luacheckrc` comment says so. CI always runs the generated branch, so a name missing from the fallback can only cause a local lint error, never a missed typo in CI.
- **The WoW std is scoped to the addon folder.** The edit hook (`lua-lint.sh`) lints every `.lua` file in the repo except `tests/`, so a global `std = "wow"` would flag `io`, `arg` and `loadfile` in `tools/wow-api/gen.lua`. A `files["BloodyScreenForever/"]` override keeps the rest of the repo on `lua51`. This was checked in the prototype.
- **Inside the addon folder the generic `lua51` std is replaced, not combined**, so names WoW's sandbox doesn't have (`os`, `io`, `require`, `dofile`) are flagged. The dump lists only functions, so non-function Lua globals the addon uses (`math.huge`, `math.pi`) go in the overlay. `print` is in the dump. The implementer adds exactly what the addon's files need and nothing speculative.
- **`Settings` is hand-listed with fields (owner decision).** It is a Lua table defined in Blizzard's FrameXML, so it is not in the C API dump. Listing its fields catches typos in the 9 `Settings.*` calls the addon makes.
- **Paths resolve against the current directory.** Seen in the prototype: luacheck run from a subfolder could not load the file. CI and both hooks run luacheck from the repo root, which the comment in `.luacheckrc` states. Run from elsewhere, the existence check simply falls back to the hand list.

### D6. Negative fixture, which also proves the list was loaded

`tests/api-typos.lua` holds one deliberate typo per kind: global (`UnitPowr`), `C_Timer` field, `Enum` field, `Settings` field, `os`. A script (`tools/check-api-typos.sh`) runs it in two stages:

1. It fails if `tools/wow-api/forever-api.lua` is missing or empty.
2. It feeds the fixture to luacheck on stdin under an addon path, `luacheck --filename BloodyScreenForever/api-typos.lua - < tests/api-typos.lua`, so the fixture is checked with exactly the addon's rules. It passes only if luacheck fails and reports all five names.

The fallback hand list catches only `UnitPowr`, so stage 2 can't pass without the generated list. A missing or ignored list fails CI twice over. In CI the script runs after generation and Lint.

Measured in the prototype (luacheck 1.2.0): passing an excluded file on the command line, with or without `--include-files`, is skipped silently with exit 0. That is why the stdin form is used. The file stays in `tests/` so neither the edit hook nor the normal lint run trips on it.

### D7. Staleness warning, not failure (owner decision)

A CI step compares `interface` in `tools/wow-api/pin` with `## Interface` in the TOC. On a mismatch it prints a GitHub `::warning::` with the update command (`tools/wow-api/update.sh --pin <sha>`), and still passes. The Forever patch watch PR bumps the TOC on the day CurseForge lists a patch, and the upstream dump can lag by days. Reading the pin means the check doesn't need the generated list.

### D8. Hooks: no change

`lua-lint.sh` and `pre-commit-tests.sh` already run luacheck with `.luacheckrc` from the repo root. Once the list has been fetched, they catch API typos at edit time in well under a second. Without it, they behave as today. The fixture, the fetch and the staleness warning are CI only.

### D9. CI luacheck version

CI's apt luacheck is 1.1.2. Its config loader falls back to `_G`, so `io.open` and `dofile` are available in `.luacheckrc`. Nested `fields` in custom stds and the stdin `--filename` mode worked in 1.2.0 locally but were not checked against 1.1.2. Task 2.2 confirms them on CI. If any fails, install luacheck pinned through luarocks (`luacheck 1.2.0`) instead of apt.

## Risks / Trade-offs

- [Upstream unreachable on a CI cache miss] → CI fails at the fetch step with a clear error, never silently. The cache key changes only when the pin changes, so misses are rare. A re-run fixes a transient outage.
- [Upstream rewrites history and the pinned SHA disappears] → The cached files keep CI working until the cache expires, which is 7 days without use. After that, re-pin to a current commit.
- [Upstream dump lags a Forever patch or stops being updated] → The pinned data keeps working at its last build. The staleness warning makes the lag visible. Gethe/wow-ui-source and NumyAddon FramexmlAnnotations also have `forever` branches as fallbacks for FrameXML names.
- [The local fallback list and the generated overlay drift apart] → Only local lint is affected, and CI always uses the generated list. The `.luacheckrc` comment tells the editor to update both.
- [Dump misses a real global the addon uses, e.g. a Lua-defined table] → It shows as a lint error in CI, never as a silent pass, and goes in the overlay with a comment.
- [A name exists in the client but is protected or not callable by addons] → Not caught. Out of scope, same as today.
- [A Forever hotfix keeps Interface 16001 but changes the API] → The staleness check compares interface numbers only, so it misses this (upstream has three builds on 16001 so far). Mitigation: the patch-watch PR text already asks to check API changes, and re-pinning is one command.
- [luacheck run from a subfolder] → It falls back to the hand list. Documented, and every existing caller runs from the root.

## Migration Plan

One commit: add the generator, update script, pin, fixture, `.gitignore` entries and CI steps, and switch `.luacheckrc`. Rollback is reverting that commit; the hand list was never removed. Afterwards, when the staleness warning fires, run `tools/wow-api/update.sh --pin <sha>` with the `forever` branch commit for the new build, fix any lint findings, and commit the new pin.

## Open Questions

- Exact size of the generated file once the overlay and sorting are final. It has no effect on the approach.
