#!/usr/bin/env bash
# Fetch the original Bloody Screen splatter textures (Feador's art, as shipped in
# Resike's 2013 MoP port) into BloodyScreenForever/Textures/.
#
# These files carry no licence: fine on your own machine, but do not publish or
# redistribute the addon with them included. That is why they are fetched, not bundled.
#
# Usage: tools/fetch_original_textures.sh
set -euo pipefail

REPO="Resike/BloodyScreen"
REF="4b21e57dfc34786ef98c6cb992dbea6fca0d6f4d"   # pinned: last commit, 2013-06-03
BASE="https://raw.githubusercontent.com/${REPO}/${REF}/BloodyScreen/Textures"
OUT="$(cd "$(dirname "$0")/.." && pwd)/BloodyScreenForever/Textures"

mkdir -p "$OUT"
count=0
for shape in 1 2 3 4 5; do
    for stage in 1 2 3 4 5 6 7 8 9 10; do
        f="Splatter${shape}_${stage}.tga"
        curl -fsSL --retry 3 -o "$OUT/$f.part" "$BASE/$f"
        # sanity check: uncompressed (2) or RLE (10) truecolor TGA header
        type=$(od -An -tu1 -j2 -N1 "$OUT/$f.part" | tr -d ' ')
        if [[ "$type" != 2 && "$type" != 10 ]]; then
            echo "error: $f is not a truecolor TGA (image type $type)" >&2
            rm -f "$OUT/$f.part"; exit 1
        fi
        mv "$OUT/$f.part" "$OUT/$f"
        count=$((count + 1))
    done
done
echo "fetched $count textures into $OUT"
echo "in game: /reload"
