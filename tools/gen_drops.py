#!/usr/bin/env python3
"""Generate the combo point bauble textures: round beads of blood.

Full: a bead of blood (deep red, darker rim, specular highlight).
Empty: a dark bead, so the row shows how many points are possible.
Own art (safe to commit). 64x64 32-bit uncompressed TGA.
Usage: python3 tools/gen_drops.py [outdir]
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 64          # output size
SS = 8          # supersampling
N = S * SS

def disc(box, blur):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).ellipse([v * N for v in box], fill=255)
    return m.filter(ImageFilter.GaussianBlur(SS * blur)) if blur else m

def bead(core, rim, spec_strength, soft_strength):
    shape = disc((0.03, 0.03, 0.97, 0.97), 0.5)
    # depth: lit core offset towards the light (upper left), dark rim
    depth = disc((0.12, 0.10, 0.80, 0.78), 7.0)
    def mix(i):
        return depth.point(lambda v: int(rim[i] + (core[i] - rim[i]) * v / 255))
    img = Image.merge("RGBA", (mix(0), mix(1), mix(2), shape))
    # soft broad sheen, then a small sharp specular, upper left
    for box, blur, strength, colour in (
        ((0.18, 0.14, 0.62, 0.50), 4.0, soft_strength, (255, 170, 170, 255)),
        ((0.26, 0.20, 0.44, 0.36), 1.2, spec_strength, (255, 250, 250, 255)),
    ):
        m = ImageChops.multiply(disc(box, blur).point(lambda v: int(v * strength)), shape)
        img = Image.composite(Image.new("RGBA", (N, N), colour), img, m)
    img.putalpha(shape)
    return img.resize((S, S), Image.LANCZOS)

def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "BloodyScreenForever" / "Textures" / "Drops"
    out.mkdir(parents=True, exist_ok=True)
    # blood: deep crimson core, near-black maroon rim
    bead(core=(150, 8, 10), rim=(45, 0, 2), spec_strength=0.95, soft_strength=0.22).save(out / "drop_full.tga", compression=None)
    bead(core=(48, 44, 44), rim=(16, 14, 14), spec_strength=0.25, soft_strength=0.08).save(out / "drop_empty.tga", compression=None)
    print(out / "drop_full.tga"); print(out / "drop_empty.tga")

if __name__ == "__main__":
    main()
