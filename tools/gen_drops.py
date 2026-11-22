#!/usr/bin/env python3
"""Generate the combo point bauble textures: a full and an empty blood drop.

Own art (safe to commit). 64x64 32-bit uncompressed TGA, drop pointing up.
Usage: python3 tools/gen_drops.py [outdir]
"""
import math, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 64          # output size
SS = 8          # supersampling
N = S * SS

def drop_polygon(scale=1.0):
    # teardrop: x = sin(t) * sin(t/2)^m, y = cos(t); tip at t=0 (top)
    pts, m = [], 1.6
    w, h = N * 0.40 * scale, N * 0.46 * scale
    cx, cy = N / 2, N * 0.52
    for i in range(400):
        t = i / 400 * 2 * math.pi
        x = math.sin(t) * math.sin(t / 2) ** m
        y = -math.cos(t)
        pts.append((cx + x * w, cy + y * h))
    return pts

def mask(scale=1.0, blur=1.0):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon(drop_polygon(scale), fill=255)
    return m.filter(ImageFilter.GaussianBlur(SS * blur))

def ellipse_mask(box, blur):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).ellipse([v * N for v in box], fill=255)
    return m.filter(ImageFilter.GaussianBlur(SS * blur))

def full_drop():
    shape = mask(1.0, 0.6)
    inner = mask(0.80, 6.0)                       # depth: brighter core, dark rim
    r = inner.point(lambda v: int(95 + v * 0.55))
    g = inner.point(lambda v: int(4 + v * 0.03))
    b = inner.point(lambda v: int(6 + v * 0.03))
    img = Image.merge("RGBA", (r, g, b, shape))
    # glossy highlight, upper left, and a faint reflected light lower right
    hi = ellipse_mask((0.33, 0.42, 0.45, 0.62), 2.5)
    lo = ellipse_mask((0.55, 0.70, 0.66, 0.80), 3.0)
    white = Image.new("RGBA", (N, N), (255, 235, 235, 255))
    img = Image.composite(white, img, ImageChops.multiply(hi.point(lambda v: int(v * 0.85)), shape))
    pink = Image.new("RGBA", (N, N), (230, 90, 90, 255))
    img = Image.composite(pink, img, ImageChops.multiply(lo.point(lambda v: int(v * 0.35)), shape))
    img.putalpha(shape)
    return img.resize((S, S), Image.LANCZOS)

def empty_drop():
    shape = mask(1.0, 0.6)
    hole = mask(0.78, 0.6)
    rim = ImageChops.subtract(shape, hole)        # dark outline
    fill = hole.point(lambda v: int(v * 0.45))    # see-through dark inside
    a = ImageChops.lighter(rim, fill)
    shade = rim.point(lambda v: 110 if v > 0 else 0)
    base = Image.new("L", (N, N), 30)
    lum = ImageChops.lighter(base, shade)
    img = Image.merge("RGBA", (lum, lum.point(lambda v: int(v * 0.8)), lum.point(lambda v: int(v * 0.8)), a))
    return img.resize((S, S), Image.LANCZOS)

def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "BloodyScreenForever" / "Textures" / "Drops"
    out.mkdir(parents=True, exist_ok=True)
    full_drop().save(out / "drop_full.tga", compression=None)
    empty_drop().save(out / "drop_empty.tga", compression=None)
    print(out / "drop_full.tga"); print(out / "drop_empty.tga")

if __name__ == "__main__":
    main()
