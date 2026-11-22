#!/usr/bin/env bash
# Build the release zip for CurseForge/WoWInterface/Wago from COMMITTED files only
# (git archive), so nothing untracked can slip in.
# Output: dist/BloodyScreenForever-<version>.zip with BloodyScreenForever/ at the root.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! git diff --quiet HEAD -- BloodyScreenForever; then
    echo "error: uncommitted changes in BloodyScreenForever/ - commit first" >&2; exit 1
fi
version=$(sed -n 's/^## Version: *//p' BloodyScreenForever/BloodyScreenForever.toc | tr -d '\r')
mkdir -p dist
out="dist/BloodyScreenForever-${version}.zip"
git archive --format=zip -o "$out" HEAD BloodyScreenForever
echo "$out"
unzip -l "$out" | tail -n +4 | head -n -2 | awk '{print $4}' | grep -v '/$' | sed 's/^/  /' | head -20
echo "  ... $(unzip -Z1 "$out" | grep -vc '/$') files"
