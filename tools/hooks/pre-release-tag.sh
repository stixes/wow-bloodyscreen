#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash): before creating or pushing a release tag
# (`git tag ... v<version>`, `git push ... v<version>` or `git push --tags`),
# check that every OpenSpec change is archived. Blocks (exit 2, reason on
# stderr) otherwise, so an unreleasable tag never reaches GitHub.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
cmd=$(jq -r '.tool_input.command // empty')
git_re='(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
grep -qE "${git_re}(tag|push)[[:space:]].*([[:space:]](refs/tags/)?v[0-9]|--tags)" <<<"$cmd" || exit 0
grep -qE "${git_re}(tag|push)[[:space:]].*([[:space:]]-d|--delete)([[:space:]]|$)" <<<"$cmd" && exit 0

cd "$root" || exit 0
out=$(tools/check-openspec-archived.sh HEAD 2>&1) || { echo "Release tag blocked: $out" >&2; exit 2; }
exit 0
