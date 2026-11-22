#!/usr/bin/env bash
# Check that the luacheck API check really works: tests/api-typos.lua holds one
# deliberate typo per kind, and luacheck must report all of them. Needs the
# generated API list (tools/wow-api/update.sh); without it luacheck falls back
# to the hand list, which misses most of these, so this fails rather than
# letting a missing list pass. Run from anywhere; CI runs it after Lint.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

list=tools/wow-api/forever-api.lua
[[ -s "$list" ]] || { echo "FAIL: $list is missing or empty - run tools/wow-api/update.sh" >&2; exit 1; }

# tests/ is excluded in .luacheckrc, and luacheck silently skips an excluded
# file named on the command line, so feed the fixture on stdin under an addon
# path: it is checked with exactly the addon's rules.
out=$(luacheck --no-color --formatter plain --filename BloodyScreenForever/api-typos.lua - < tests/api-typos.lua)
status=$?
if [[ $status -eq 0 ]]; then
    echo "FAIL: luacheck found nothing in tests/api-typos.lua" >&2; exit 1
fi
fail=0
for name in UnitPowr Aftr PowerType.ComboPoint CreateSlidr "'os'"; do
    if grep -qF -- "$name" <<<"$out"; then
        echo "PASS: luacheck reports $name"
    else
        echo "FAIL: luacheck does not report $name" >&2; fail=1
    fi
done
[[ $fail -eq 0 ]] || { echo "$out" >&2; exit 1; }
