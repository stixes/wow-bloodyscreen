#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash): before creating or pushing a release tag
# (`git tag ... v<version>`, `git push ... v<version>` or `git push --tags`),
# check that every OpenSpec change is archived and that a release review for
# the TOC version is recorded in dist/release-review-v<version>.md. Blocks
# (exit 2, reason on stderr) otherwise, so an unreleasable tag never reaches GitHub.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
cmd=$(jq -r '.tool_input.command // empty')
git_re='(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
grep -qE "${git_re}(tag|push)[[:space:]].*([[:space:]](refs/tags/)?v[0-9]|--tags)" <<<"$cmd" || exit 0
grep -qE "${git_re}(tag|push)([[:space:]]+[^[:space:]]+)*[[:space:]]+(-d|--delete)([[:space:]]|$)" <<<"$cmd" && exit 0

cd "$root" || exit 0
out=$(tools/check-openspec-archived.sh HEAD 2>&1) || { echo "Release tag blocked: $out" >&2; exit 2; }

# A clean-context review (the release-reviewer agent) must have run for this
# version: its report and how each finding was handled, in dist/ (git-ignored).
version=$(sed -n 's/^## Version: *//p' BloodyScreenForever/BloodyScreenForever.toc | tr -d '\r')
review="dist/release-review-v$version.md"
if [[ ! -s "$review" ]]; then
    echo "Release tag blocked: no release review for v$version. Run the release-reviewer agent" >&2
    echo "(clean context; give it only the version and the previous tag), handle its findings," >&2
    echo "then save its report and the outcome of each finding to $review." >&2
    exit 2
fi
exit 0
