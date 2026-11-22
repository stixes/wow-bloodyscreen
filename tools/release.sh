#!/usr/bin/env bash
# Release to CurseForge through its upload API.
#
#   envchain curseforge tools/release.sh [alpha|beta|release] [--dry-run]   (manual fallback)
#   tools/release.sh --ci                                                   (GitHub Actions, on a tag push)
#
# Normally releases go out from GitHub Actions (.github/workflows/release.yml)
# when a v<version> tag is pushed; this script is what that workflow runs.
# Release type: given, or from the version: 1.2.3-alpha1 -> alpha,
# 1.2.3-beta2 -> beta, 1.2.3 -> release.
#
# Reads from the TOC: ## Version, ## Interface (-> game version, 16001 -> 1.60.1)
# and ## X-Curse-Project-ID. Release notes come from CHANGELOG.md's
# "## <version>" section. Needs the CurseForge API token (author portal ->
# API tokens) as CF_API_TOKEN or API_TOKEN, injected by envchain (namespace
# curseforge holds API_TOKEN); the token is never printed.
# Every OpenSpec change must be archived (tools/check-openspec-archived.sh).
# Steps: checks -> zip (tools/package.sh) -> game version id -> upload -> git tag v<version>.
# --dry-run does everything except the upload and the tag.
# --ci: HEAD must already be tagged v<version>; no tag is created. Writes
# dist/RELEASE_NOTES.md and, under Actions, version/type/zip to $GITHUB_OUTPUT.
# A tag message containing [no-curseforge] skips the upload (GitHub release only).
set -euo pipefail
cd "$(dirname "$0")/.."

type="" dry=0 ci=0
for a in "$@"; do
    case "$a" in
        alpha|beta|release) type=$a ;;
        --dry-run) dry=1 ;;
        --ci) ci=1 ;;
        *) echo "usage: $0 [alpha|beta|release] [--dry-run] [--ci]" >&2; exit 2 ;;
    esac
done

die() { echo "error: $*" >&2; exit 1; }
toc=BloodyScreenForever/BloodyScreenForever.toc
field() { sed -n "s/^## $1: *//p" "$toc" | tr -d '\r'; }
version=$(field Version)
interface=$(field Interface)
project=$(field X-Curse-Project-ID)
[[ -n "$version" && -n "$interface" && -n "$project" ]] || die "TOC needs Version, Interface and X-Curse-Project-ID"
if [[ -z "$type" ]]; then
    case "$version" in
        *-alpha*) type=alpha ;;
        *-beta*) type=beta ;;
        *) type=release ;;
    esac
fi

# Interface 16001 -> game version name 1.60.1 (major, minor, patch)
gv="$((interface / 10000)).$(((interface / 100) % 100)).$((interface % 100))"

# clean tree, new version, notes present
git diff --quiet HEAD || die "uncommitted changes - commit first"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || die "uncommitted changes - commit first"
if [[ $ci -eq 1 ]]; then
    [[ "$(git rev-parse -q --verify "refs/tags/v$version^{commit}")" == "$(git rev-parse HEAD)" ]] \
        || die "HEAD is not tagged v$version - the tag must match ## Version in the TOC"
elif git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
    die "v$version is already tagged (released) - bump ## Version in the TOC"
fi
notes=$(awk -v v="$version" '
    $0 ~ "^## "v"$" {on=1; next}
    on && /^## / {exit}
    on {print}' CHANGELOG.md | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
[[ -n "$notes" ]] || die "CHANGELOG.md has no '## $version' section"
! grep -q '^## Unreleased' CHANGELOG.md || die "CHANGELOG.md still has an '## Unreleased' section - rename it to '## $version'"
tools/check-openspec-archived.sh HEAD >/dev/null || exit 1

pkg=$(tools/package.sh)       # no "| head": with pipefail that SIGPIPEs (exit 141)
zip=${pkg%%$'\n'*}
[[ -f "$zip" ]] || die "packaging failed"
printf '%s\n' "$notes" > dist/RELEASE_NOTES.md
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    { echo "version=$version"; echo "type=$type"; echo "zip=$zip"; } >> "$GITHUB_OUTPUT"
fi

echo "release:  Bloody Screen Forever $version ($type)"
echo "project:  $project   game version: $gv (Interface $interface)"
echo "zip:      $zip"
echo "notes:"; sed 's/^/  | /' <<<"$notes"

if [[ $ci -eq 1 ]] && git tag -l --format='%(contents)' "v$version" | grep -qF '[no-curseforge]'; then
    echo "tag message has [no-curseforge]: skipping the CurseForge upload"
    exit 0
fi

api="https://wow.curseforge.com/api"
CF_API_TOKEN=${CF_API_TOKEN:-${API_TOKEN:-}}
if [[ -z "${CF_API_TOKEN:-}" ]]; then
    [[ $dry -eq 1 ]] && { echo "dry run: no CF_API_TOKEN, skipping game version lookup and upload"; exit 0; }
    die "no API token (CF_API_TOKEN or API_TOKEN) - run via: envchain curseforge $0 $*"
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

if [[ $ci -eq 0 ]]; then
    git tag -a "v$version" -m "Release $version ($type) - CurseForge file ${fileid:-?}"
    echo "tagged v$version - push it with: git push origin v$version (the release workflow"
    echo "would upload again: delete the duplicate on CurseForge, or don't push the tag)"
fi
