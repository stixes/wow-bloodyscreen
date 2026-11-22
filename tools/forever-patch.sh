#!/usr/bin/env bash
# Check CurseForge for a newer WoW Forever game version than the TOC's
# ## Interface, and if there is one, bump the TOC (Interface + patch version)
# and add a CHANGELOG.md section. Run by .github/workflows/forever-patch.yml,
# which then opens a PR; can also be run locally:
#
#   envchain curseforge tools/forever-patch.sh [--check]
#
# --check only reports. Prints "new=<version name>" (or nothing) on the last line.
# Needs the CurseForge API token as CF_API_TOKEN or API_TOKEN (never printed).
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "error: $*" >&2; exit 1; }
check=0; [[ "${1:-}" == "--check" ]] && check=1
toc=BloodyScreenForever/BloodyScreenForever.toc
field() { sed -n "s/^## $1: *//p" "$toc" | tr -d '\r'; }
interface=$(field Interface)
version=$(field Version)

CF_API_TOKEN=${CF_API_TOKEN:-${API_TOKEN:-}}
[[ -n "$CF_API_TOKEN" ]] || die "no API token (CF_API_TOKEN or API_TOKEN)"
api="https://wow.curseforge.com/api"
auth() { printf 'header = "X-Api-Token: %s"\n' "$CF_API_TOKEN"; }
types=$(auth | curl -fsS -K - "$api/game/version-types") || die "could not list version types"
typeid=$(jq -r '[.[] | select(.slug == "wow-forever")] | if length == 1 then .[0].id else empty end' <<<"$types")
[[ -n "$typeid" ]] || die "no CurseForge version type with slug wow-forever"
versions=$(auth | curl -fsS -K - "$api/game/wow/versions") || die "could not list game versions"

# newest Forever version as an interface number: 1.60.1 -> 16001
latest=$(jq -r --argjson t "$typeid" '.[] | select(.gameVersionTypeID == $t) | .name' <<<"$versions" \
    | awk -F. 'NF == 3 { printf "%d %s\n", $1 * 10000 + $2 * 100 + $3, $0 }' | sort -n | tail -1)
[[ -n "$latest" ]] || die "no Forever game versions listed"
newif=${latest%% *}; newname=${latest#* }
echo "TOC Interface: $interface   newest Forever on CurseForge: $newname ($newif)"
if (( newif <= interface )); then echo "up to date"; echo "new="; exit 0; fi
if [[ $check -eq 1 ]]; then echo "new=$newname"; exit 0; fi

# 0.17.0 -> 0.17.1 (a pre-release suffix is dropped: 0.18.0-beta1 -> 0.18.1)
base=${version%%-*}
IFS=. read -r ma mi pa <<<"$base"
newver="$ma.$mi.$((${pa:-0} + 1))"
sed -i -e "s/^## Interface: .*/## Interface: $newif/" -e "s/^## Version: .*/## Version: $newver/" "$toc"
# An "## Unreleased" section becomes this version (it ships in the same zip);
# otherwise a new section goes above the first one.
awk -v v="$newver" -v g="$newname" '
    !done && /^## Unreleased$/ { print "## " v "\n\n* Updated for WoW Forever " g "."; done = 1; next }
    !done && /^## / { print "## " v "\n\n* Updated for WoW Forever " g ".\n"; done = 1 }
    { print }' CHANGELOG.md > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md
echo "bumped: Interface $interface -> $newif, Version $version -> $newver"
echo "new=$newname"
