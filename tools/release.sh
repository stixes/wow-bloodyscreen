#!/usr/bin/env bash
# Release to CurseForge through its upload API.
#
#   envchain curseforge tools/release.sh [alpha|beta|release] [--dry-run]
#
# Reads from the TOC: ## Version, ## Interface (-> game version, 16001 -> 1.60.1)
# and ## X-Curse-Project-ID. Release notes come from CHANGELOG.md's
# "## <version>" section. Needs CF_API_TOKEN (CurseForge author portal ->
# API tokens), injected by envchain; the token is never printed.
# Steps: checks -> zip (tools/package.sh) -> game version id -> upload -> git tag v<version>.
# --dry-run does everything except the upload and the tag.
set -euo pipefail
cd "$(dirname "$0")/.."

type=beta dry=0
for a in "$@"; do
    case "$a" in
        alpha|beta|release) type=$a ;;
        --dry-run) dry=1 ;;
        *) echo "usage: $0 [alpha|beta|release] [--dry-run]" >&2; exit 2 ;;
    esac
done

die() { echo "error: $*" >&2; exit 1; }
toc=BloodyScreenForever/BloodyScreenForever.toc
field() { sed -n "s/^## $1: *//p" "$toc" | tr -d '\r'; }
version=$(field Version)
interface=$(field Interface)
project=$(field X-Curse-Project-ID)
[[ -n "$version" && -n "$interface" && -n "$project" ]] || die "TOC needs Version, Interface and X-Curse-Project-ID"

# Interface 16001 -> game version name 1.60.1 (major, minor, patch)
gv="$((interface / 10000)).$(((interface / 100) % 100)).$((interface % 100))"

# clean tree, new version, notes present
git diff --quiet HEAD || die "uncommitted changes - commit first"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || die "uncommitted changes - commit first"
if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
    die "v$version is already tagged (released) - bump ## Version in the TOC"
fi
notes=$(awk -v v="$version" '
    $0 ~ "^## "v"$" {on=1; next}
    on && /^## / {exit}
    on {print}' CHANGELOG.md | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
[[ -n "$notes" ]] || die "CHANGELOG.md has no '## $version' section"

zip=$(tools/package.sh | head -n1)
[[ -f "$zip" ]] || die "packaging failed"

echo "release:  Bloody Screen Forever $version ($type)"
echo "project:  $project   game version: $gv (Interface $interface)"
echo "zip:      $zip"
echo "notes:"; sed 's/^/  | /' <<<"$notes"

api="https://wow.curseforge.com/api"
if [[ -z "${CF_API_TOKEN:-}" ]]; then
    [[ $dry -eq 1 ]] && { echo "dry run: no CF_API_TOKEN, skipping game version lookup and upload"; exit 0; }
    die "CF_API_TOKEN is not set - run via: envchain curseforge $0 $*"
fi

# game version id by name; the token goes in through a curl config on stdin, not argv
auth() { printf 'header = "X-Api-Token: %s"\n' "$CF_API_TOKEN"; }
versions=$(auth | curl -fsS -K - "$api/game/wow/versions") || die "could not list game versions (bad token?)"
gvid=$(jq -r --arg v "$gv" '[.[] | select(.name == $v)] | if length == 1 then .[0].id else empty end' <<<"$versions")
[[ -n "$gvid" ]] || die "no unique CurseForge game version named $gv - check $api/game/wow/versions"
echo "game version id: $gvid"

if [[ $dry -eq 1 ]]; then echo "dry run: stopping before upload"; exit 0; fi

meta=$(jq -n --arg name "Bloody Screen Forever $version" --arg notes "$notes" \
    --arg type "$type" --argjson gv "$gvid" \
    '{displayName: $name, changelog: $notes, changelogType: "markdown", gameVersions: [$gv], releaseType: $type}')
resp=$(auth | curl -sS -K - -w '\n%{http_code}' \
    -F "metadata=$meta;type=application/json" -F "file=@$zip" \
    "$api/projects/$project/upload-file")
code=${resp##*$'\n'}; body=${resp%$'\n'*}
[[ "$code" == 200 || "$code" == 201 ]] || die "upload failed (HTTP $code): $body"
fileid=$(jq -r '.id // empty' <<<"$body")
echo "uploaded: file id ${fileid:-?} - waiting for CurseForge processing/moderation"

git tag -a "v$version" -m "Release $version ($type) - CurseForge file ${fileid:-?}"
echo "tagged v$version"
