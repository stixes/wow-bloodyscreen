#!/usr/bin/env bash
# A release requires every OpenSpec change to be archived: fails (exit 1) when
# openspec/changes/ holds any change other than archive/ in the given commit
# (default HEAD). Reads the committed tree, so it needs no OpenSpec CLI and
# ignores uncommitted files.
#
#   tools/check-openspec-archived.sh [<commit>]
set -euo pipefail
cd "$(dirname "$0")/.."
rev=${1:-HEAD}
open=$(git ls-tree -d --name-only "$rev" openspec/changes/ | sed 's|^openspec/changes/||' | grep -vx archive || true)
if [[ -n "$open" ]]; then
    echo "error: open OpenSpec changes in $rev - archive them before releasing (/openspec-archive-change <name>):" >&2
    sed 's/^/  - /' <<<"$open" >&2
    exit 1
fi
echo "openspec: no open changes in $rev"
