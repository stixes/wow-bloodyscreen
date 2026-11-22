#!/usr/bin/env python3
"""Generate the blood splatter textures (own art, safe to commit).

Same scheme as the original addon's art, so it draws the same way: red on a
WHITE background, drawn with MOD blending (white = no change, red stains the
scene). 5 shapes x 10 pre-faded steps: SplatterN_1 is full strength and each
later step is a bit closer to white; SplatterN_10 is almost gone.
256x256 24-bit RLE TGA. Deterministic (seeded).

Usage: python3 tools/gen_splatters.py [outdir]
"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 256          # output size
SS = 3           # supersampling
N = S * SS
SHAPES, STEPS = 5, 10
BLOOD = (98, 4, 6)          # deepest stain colour (multiplied into the scene)
SPRAY = (196, 40, 40)       # thinnest spray

def splatter_density(seed):
    """0..255 'how much blood' map for one shape."""
    rng = random.Random(seed)
    c = N / 2
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)

    def blob(cx, cy, r):
        n = rng.randint(18, 30)
        ph = rng.random() * math.tau
        pts = [(cx + math.cos(ph + i * math.tau / n) * r * (0.72 + 0.5 * rng.random()),
                cy + math.sin(ph + i * math.tau / n) * r * (0.72 + 0.5 * rng.random())) for i in range(n)]
        d.polygon(pts, fill=255)

    # off-centre main pool plus satellite pools, like a hit spatter
    core_r = N * rng.uniform(0.12, 0.16)
    ox, oy = rng.uniform(-0.06, 0.06) * N, rng.uniform(-0.06, 0.06) * N
    for _ in range(rng.randint(3, 6)):
        blob(c + ox + rng.gauss(0, core_r * 0.4), c + oy + rng.gauss(0, core_r * 0.4), core_r * rng.uniform(0.55, 1.0))
    for _ in range(rng.randint(1, 3)):
        a = rng.random() * math.tau
        dist = N * rng.uniform(0.18, 0.32)
        blob(c + ox + math.cos(a) * dist, c + oy + math.sin(a) * dist, core_r * rng.uniform(0.3, 0.55))

    # streaks flung outwards, mostly in one direction (impact direction)
    main_dir = rng.random() * math.tau
    for _ in range(rng.randint(10, 18)):
        a = main_dir + rng.gauss(0, 1.1)
        length = N * rng.uniform(0.14, 0.34)
        width = N * rng.uniform(0.006, 0.019)
        for s in range(60):
            t = s / 60
            dist = core_r * 0.5 + length * t
            w = width * (1 - t * 0.85)
            x, y = c + ox + math.cos(a) * dist, c + oy + math.sin(a) * dist
            d.ellipse([x - w, y - w, x + w, y + w], fill=255)
        if rng.random() < 0.75:
            dist = core_r * 0.5 + length + N * rng.uniform(0.01, 0.03)
            x, y = c + ox + math.cos(a) * dist, c + oy + math.sin(a) * dist
            w = width * rng.uniform(1.0, 2.0)
            d.ellipse([x - w, y - w, x + w, y + w], fill=255)

    # fine droplets, denser in the impact direction
    for _ in range(rng.randint(40, 80)):
        a = main_dir + rng.gauss(0, 1.4)
        dist = N * min(0.46, abs(rng.gauss(0.22, 0.10)))
        x, y = c + ox + math.cos(a) * dist, c + oy + math.sin(a) * dist
        w = N * rng.uniform(0.002, 0.009)
        d.ellipse([x - w, y - w, x + w, y + w], fill=255)

    # keep everything inside the texture (rotation-safe: within the inscribed circle)
    clip = Image.new("L", (N, N), 0)
    ImageDraw.Draw(clip).ellipse([N * 0.03, N * 0.03, N * 0.97, N * 0.97], fill=255)
    m = ImageChops.multiply(m, clip)

    m = m.filter(ImageFilter.GaussianBlur(SS * 0.8))
    m = m.point(lambda v: 0 if v < 70 else min(255, int((v - 70) * 1.5)))
    # thickness: pools are dense, spray thin; plus mottling (uneven drying)
    thick = m.filter(ImageFilter.GaussianBlur(SS * 7))
    noise = Image.effect_noise((N // 6, N // 6), 50).resize((N, N), Image.BICUBIC).filter(ImageFilter.GaussianBlur(SS * 2))
    mb, tb, nb = m.tobytes(), thick.tobytes(), noise.tobytes()
    out = bytearray(len(mb))
    for i in range(len(mb)):
        v = mb[i] * (0.55 + 0.45 * tb[i] / 255) * (0.9 + 0.2 * (nb[i] - 128) / 128 * 0.5)
        out[i] = 0 if v < 0 else 255 if v > 255 else int(v)
    return Image.frombytes("L", (N, N), bytes(out)).resize((S, S), Image.LANCZOS)

def render(density, fade):
    """RGB on white. fade 0 = full strength, 1 = white."""
    db = density.tobytes()
    rgb = bytearray(len(db) * 3)
    for i, v in enumerate(db):
        dens = v / 255 * (1 - fade)
        # colour: thin spray is brighter red, dense pools deep maroon
        k = min(1.0, v / 255 * 1.25)
        col = [SPRAY[j] + (BLOOD[j] - SPRAY[j]) * k for j in range(3)]
        for j in range(3):
            rgb[i * 3 + j] = int(255 + (col[j] - 255) * dens)
    return Image.frombytes("RGB", density.size, bytes(rgb))

def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "BloodyScreenForever" / "Textures" / "Splatters"
    out.mkdir(parents=True, exist_ok=True)
    random.seed(0)
    for shape in range(1, SHAPES + 1):
        random.seed(shape)  # effect_noise uses the global RNG? keep runs stable-ish
        dens = splatter_density(4200 + shape)
        for step in range(1, STEPS + 1):
            fade = (step - 1) / STEPS          # step 10 = 90% faded
            render(dens, fade).save(out / f"Splatter{shape}_{step}.tga", compression="tga_rle")
    print(f"wrote {SHAPES * STEPS} textures to {out}")

if __name__ == "__main__":
    main()
