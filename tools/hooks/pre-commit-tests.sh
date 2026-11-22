#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash): before a `git commit`, lint the addon and
# run the test harness. Blocks the commit (exit 2, reason on stderr) on failure.
# Runs against the working tree, which is what's staged in the usual
# "git add -A && git commit" flow.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
cmd=$(jq -r '.tool_input.command // empty')
grep -qE '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|$)' <<<"$cmd" || exit 0

cd "$root" || exit 0
fail() { echo "Commit blocked: $1" >&2; echo "$2" | tail -n 40 >&2; exit 2; }
for f in BloodyScreenForever/*.lua; do
    out=$(luajit -bl "$f" 2>&1 >/dev/null) || fail "syntax error in $f" "$out"
done
if command -v luacheck >/dev/null; then
    out=$(luacheck --no-color --formatter plain --codes BloodyScreenForever/ 2>&1) || fail "luacheck findings" "$out"
fi
out=$(luajit tests/harness.lua BloodyScreenForever 2>&1) || fail "test harness failed" "$(grep -E '^FAIL|failed|error' <<<"$out")"
exit 0
