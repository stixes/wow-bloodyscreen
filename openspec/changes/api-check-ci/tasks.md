# Tasks

Before you start, check the owner's answers to the planning questions: commit or fetch the list (D3), where the `Settings` fields come from (D5), and whether staleness warns or fails (D7). The plan assumes the defaults in design.md. If an answer changes a decision, update design.md first.

## 1. Generator and generated list

- [ ] 1.1 Add `tools/wow-api/gen.lua` (Lua 5.1, run with luajit) per design D4. It takes a directory holding `GlobalAPI.lua`, `LuaEnum.lua`, `FrameXML.lua`, `Frames.lua` and `Mixins.lua`, plus the header values, and writes a sorted `return { … }` read_globals table with a header comment (upstream repo, commit SHA, game version, build, interface). Verify: running it twice on the same input gives byte-identical output.
- [ ] 1.2 Add `tools/wow-api/update.sh <sha>`. It downloads the five files and `README.md` at that commit of Ketho/BlizzardInterfaceResources (`forever` branch) into a temp dir, reads the `GetBuildInfo()` line for the header, runs the generator and rewrites `tools/wow-api/forever-api.lua`. Use `set -euo pipefail`, fail on any download error, and add a usage comment. Use no personal paths. Verify: `tools/wow-api/update.sh e230342a476eb4ef484ba7b34adc0da6ecc6acc1` produces a file whose header says 1.60.1, build 70938, interface 16001, and which contains `issecretvalue`, `canaccessvalue`, `GetComboPoints`, `C_Timer.After` and `Enum.PowerType.ComboPoints`.
- [ ] 1.3 Commit the generated `tools/wow-api/forever-api.lua` (design D3). Verify: `tools/package.sh` output still lists only files under `BloodyScreenForever/`.

## 2. luacheck config

- [ ] 2.1 In `.luacheckrc`, define `stds.wow` via `dofile("tools/wow-api/forever-api.lua")` and apply it only to the addon with `files["BloodyScreenForever/"] = { std = "wow" }`. Keep `std = "lua51"` and `max_line_length = false` for the rest (design D5). Replace the hand API list with the overlay from design D5: `Settings` with exactly the fields the addon calls, `PowerBarColor`, `WOW_PROJECT_ID`, and only the Lua constants the addon needs (e.g. `math.huge`). Keep `globals` and `exclude_files`. Update the file's comments: where the list comes from, that luacheck must run from the repo root, how to add a missing name, and how to update the list. Verify: `luacheck --no-color BloodyScreenForever/` exits 0 from the repo root, and `luacheck tools/wow-api/gen.lua` exits 0 (the edit hook lints tools/ too).
- [ ] 2.2 Confirm the CI luacheck (apt `lua-check` 1.1.2 on `ubuntu-latest`) loads this config, i.e. `dofile` and nested `fields` work (design D9). Also confirm that the stdin `--filename` form from 3.1 reports findings. If any of this fails, change the CI install to luacheck 1.2.0 pinned through luarocks. Verify: the CI Lint step passes on a pushed branch, or run the same command in an `ubuntu-latest` container.

## 3. Negative fixture and CI

- [ ] 3.1 Add `tests/api-typos.lua` with one deliberate typo per kind: global (`UnitPowr`), `C_Timer` field (`C_Timer.Aftr`), `Enum` field (`Enum.PowerType.ComboPoint`), `Settings` field (`Settings.CreateSlidr`), and a non-WoW Lua global (`os.time`). Add a header comment saying it must fail. Add a script, e.g. `tools/check-api-typos.sh`, that feeds it to luacheck on stdin as `--filename BloodyScreenForever/api-typos.lua -`, so it gets the addon's rules. Passing the excluded file directly is silently skipped (design D6) and exits 0 only if luacheck fails and reports all five names. Verify: the script passes, and fails when one typo line is corrected.
- [ ] 3.2 Add CI steps in the `test` job of `.github/workflows/ci.yml`, after Lint: (a) the fixture script from 3.1; (b) a staleness step that compares the interface number in the `forever-api.lua` header with `## Interface` in the TOC and prints a `::warning::` with the update command on a mismatch, without failing (design D7). Add no new actions; keep `actions/checkout@v4` as it is. Verify: CI is green on the branch, and a local run with a temporarily edited TOC Interface prints the warning.

## 4. Docs

- [ ] 4.1 Update the README "Working on this project" dev loop, step 2. Unknown names are now checked against the Forever client's API list in `tools/wow-api/forever-api.lua`. Only names missing from the dump (Lua-defined tables such as `Settings`, constants) go in the `.luacheckrc` overlay. Also mention the fixture step in "CI runs the same lint and harness". Verify: the commands in the text run as written.
- [ ] 4.2 In the README's Forever patch and release text, add: after a Forever patch, run `tools/wow-api/update.sh <sha>` with the `forever` branch commit for the new build, review the API name diff, and commit. Verify: the README mentions the staleness warning and the update command, and contains no personal paths or account names.

## 5. Integration check

- [ ] 5.1 Run the full local loop from the repo root: syntax check, `luacheck BloodyScreenForever/`, `tools/check-api-typos.sh` and `luajit tests/harness.lua BloodyScreenForever` (all PASS, unchanged). Then run `openspec validate api-check-ci --strict`. Make one throwaway edit that misspells an API name in an addon file and check that the Claude Code lint hook reports it. Revert the edit.
- [ ] 5.2 In-game check list: none. This change does not touch the addon's code. CHANGELOG: no entry, because nothing is user-visible.
