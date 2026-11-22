#!/usr/bin/env bash
# Claude Code PostToolUse hook (Edit|Write|MultiEdit): lint the Lua file that
# was just written. Reads the hook payload (JSON) on stdin. On problems, exits 2
# with the findings on stderr, which Claude Code feeds back to Claude.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
file=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[[ "$file" == *.lua && -f "$file" ]] || exit 0
case "$(realpath "$file")" in "$(realpath "$root")"/*) ;; *) exit 0 ;; esac

out=$(luajit -bl "$file" 2>&1 >/dev/null) || { echo "Lua syntax error in $file:" >&2; echo "$out" >&2; exit 2; }
if command -v luacheck >/dev/null; then
    case "$file" in */tests/*) exit 0 ;; esac   # harness stubs globals on purpose
    out=$(cd "$root" && luacheck --no-color --formatter plain --codes "$file" 2>&1) \
        || { echo "luacheck findings in $file (config: .luacheckrc):" >&2; echo "$out" >&2; exit 2; }
fi
exit 0
