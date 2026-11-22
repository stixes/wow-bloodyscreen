#!/usr/bin/env bash
# Fetch the WoW Forever API dump at the pinned upstream commit and generate the
# luacheck list tools/wow-api/forever-api.lua (git-ignored, never committed:
# the upstream repo has no licence). .luacheckrc uses the list when it exists.
#
#   tools/wow-api/update.sh              fetch the pinned files (cached) and generate
#   tools/wow-api/update.sh --pin <sha>  move the pin to another upstream commit
#                                        of the "forever" branch, then generate
#
# Downloads go to tools/wow-api/cache/<sha>/ (git-ignored; CI caches it).
# Needs curl and luajit.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo="Ketho/BlizzardInterfaceResources"
raw="https://raw.githubusercontent.com/$repo"
files=(GlobalAPI.lua LuaEnum.lua FrameXML.lua Frames.lua Mixins.lua)

die() { echo "error: $*" >&2; exit 1; }
fetch() { # <url> <dest>: download to a temp name, move into place on success
    curl -fsSL --retry 3 -o "$2.part" "$1" || { rm -f "$2.part"; die "download failed: $1"; }
    mv "$2.part" "$2"
}

if [[ "${1:-}" == "--pin" ]]; then
    sha=${2:-}
    [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "--pin needs a full 40-character commit sha"
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    fetch "$raw/$sha/README.md" "$tmp/README.md"
    # GetBuildInfo() => "1.60.1", "70938", "Nov 12 2026", 16001
    line=$(grep -m1 'GetBuildInfo() =>' "$tmp/README.md") || die "no GetBuildInfo line in upstream README"
    read -r version build interface < <(sed -E 's/.*=> *"([^"]+)", *"([^"]+)", *"[^"]*", *([0-9]+).*/\1 \2 \3/' <<<"$line")
    [[ "$interface" =~ ^[0-9]+$ ]] || die "could not parse: $line"
    { sed -n '/^#/p' "$here/pin"
      printf 'sha=%s\nversion=%s\nbuild=%s\ninterface=%s\n' "$sha" "$version" "$build" "$interface"
    } > "$here/pin.new" && mv "$here/pin.new" "$here/pin"
    echo "pinned $sha (WoW Forever $version build $build, interface $interface)"
elif [[ $# -gt 0 ]]; then
    die "usage: $0 [--pin <sha>]"
fi

pinval() { sed -n "s/^$1=//p" "$here/pin"; }
sha=$(pinval sha); version=$(pinval version); build=$(pinval build); interface=$(pinval interface)
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "bad sha in $here/pin"

cache="$here/cache/$sha"
mkdir -p "$cache"
for f in "${files[@]}"; do
    [[ -s "$cache/$f" ]] || { echo "fetching $f"; fetch "$raw/$sha/Resources/$f" "$cache/$f"; }
done

out="$here/forever-api.lua"
luajit "$here/gen.lua" "$cache" "$sha" "$version" "$build" "$interface" > "$out.new"
mv "$out.new" "$out"
echo "wrote ${out#"$here/"} (WoW Forever $version build $build, interface $interface)"
