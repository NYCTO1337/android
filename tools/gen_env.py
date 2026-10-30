#!/usr/bin/env python3
"""Generates every environment texture into assets/art/.

Dark, misty, monochrome. Colour only appears in the lantern flame (the single
warm accent). Layers: bg_far (opaque, glowing mist + faint trees), bg_mid
(trees in fog), fg_near (huge near-black trunks), fog (drifting mist),
ground_top / ground_fill, plank, crate, lever, door, thorns, lantern, gate,
vignette. All horizontally-tileable layers wrap around correctly.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/art"
os.makedirs(OUT, exist_ok=True)


BIG = ("bg_far.png", "bg_mid.png", "fg_near.png")


def save(img, name):
    # parallax layers are soft by design: ship them at 1024x512 (2 MB each in
    # VRAM instead of 8 MB) - the engine scales them up
    if name in BIG:
        img = img.resize((1024, 512), Image.LANCZOS)
    img.save(os.path.join(OUT, name))


def lerp(a, b, t):
    return a + (b - a) * t


# ----------------------------------------------------------------- trees

def branch(d, x, y, ang, length, width, depth, rng, col, W, ss):
    if depth == 0 or width < 0.6:
        return
    x2 = x + math.sin(ang) * length
    y2 = y - math.cos(ang) * length
    for off in (-W, 0, W):
        d.line([((x + off) * ss, y * ss), ((x2 + off) * ss, y2 * ss)], fill=col, width=max(1, int(width * ss)))
        r = width * ss * 0.5
        d.ellipse([((x2 + off) * ss - r, y2 * ss - r), ((x2 + off) * ss + r, y2 * ss + r)], fill=col)
    n = 2 if depth > 1 else rng.choice([1, 2, 2])
    for _ in range(n):
        da = rng.uniform(0.25, 0.75) * rng.choice([-1, 1])
        branch(d, x2, y2, ang + da, length * rng.uniform(0.62, 0.8), width * 0.66, depth - 1, rng, col, W, ss)


def tree(d, x, base_y, height, trunk_w, rng, col, W, ss, crown=True):
    """Trunk drawn as a tapered polygon (flared roots), then a bare crown."""
    top_w = trunk_w * 0.45
    pts = []
    sway = rng.uniform(-0.08, 0.08) * height
    for off in (-W, 0, W):
        poly = [
            ((x + off - trunk_w * 1.35) * ss, (base_y + 4) * ss),
            ((x + off - trunk_w * 0.5) * ss, (base_y - height * 0.08) * ss),
            ((x + off + sway - top_w * 0.5) * ss, (base_y - height) * ss),
            ((x + off + sway + top_w * 0.5) * ss, (base_y - height) * ss),
            ((x + off + trunk_w * 0.5) * ss, (base_y - height * 0.08) * ss),
            ((x + off + trunk_w * 1.35) * ss, (base_y + 4) * ss),
        ]
        d.polygon(poly, fill=col)
    if crown:
        tx, ty = x + sway, base_y - height
        for _ in range(rng.randint(3, 5)):
            branch(d, tx, ty, rng.uniform(-0.9, 0.9), height * rng.uniform(0.16, 0.26),
                   top_w * 0.9, rng.randint(3, 4), rng, col, W, ss)


def fog_ramp(img, y0, y1, fog_col, strength):
    """Blends RGB toward fog_col between y0 (0) and y1 (strength)."""
    a = np.asarray(img).astype(np.float32)
    h = a.shape[0]
    ys = np.clip((np.arange(h) - y0) / max(1.0, (y1 - y0)), 0, 1)[:, None, None] * strength
    fc = np.array(fog_col, dtype=np.float32)[None, None, :3]
    a[..., :3] = a[..., :3] * (1 - ys) + fc * ys
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), img.mode)


def make_bg_far():
    W, H = 2048, 1024
    ys = np.linspace(0, 1, H)[:, None]
    top = np.array([30, 32, 34], dtype=np.float32)
    mid = np.array([120, 124, 123], dtype=np.float32)
    low = np.array([188, 191, 188], dtype=np.float32)
    t1 = np.clip(ys / 0.62, 0, 1)
    t2 = np.clip((ys - 0.62) / 0.38, 0, 1)
    col = (top * (1 - t1) + mid * t1) * (1 - t2) + (mid * (1 - t2) + low * t2) * t2 * 0 + low * t2 * 0
    col = np.where(ys < 0.62, top * (1 - t1) + mid * t1, mid * (1 - t2) + low * t2)
    img = np.broadcast_to(col[:, None, :], (H, W, 3)).copy()
    # back-light: soft pale glow behind the far trees (wrap-safe: two glows)
    xs = np.arange(W)[None, :]
    yy = np.arange(H)[:, None]
    for gx, gy, gr, gs in ((620, 560, 520, 70), (1650, 600, 640, 55)):
        for off in (-W, 0, W):
            dist = np.sqrt((xs - gx - off) ** 2 + ((yy - gy) * 1.35) ** 2)
            g = np.exp(-(dist / gr) ** 2) * gs
            img += g[..., None]
    base = Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB")

    ss = 1
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = random.Random(11)
    for i in range(16):
        x = rng.uniform(0, W)
        h = rng.uniform(380, 640)
        tree(d, x, 820, h, rng.uniform(9, 16), rng, (92, 96, 97, 255), W, ss)
    layer = layer.filter(ImageFilter.GaussianBlur(2.2))
    base.paste(layer, (0, 0), layer)
    base = fog_ramp(base, 560, 860, (176, 180, 178), 0.78)
    save(base, "bg_far.png")


def make_bg_mid():
    W, H = 2048, 1024
    ss = 2
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(23)
    for i in range(11):
        x = rng.uniform(0, W)
        h = rng.uniform(560, 900)
        tree(d, x, 980, h, rng.uniform(16, 30), rng, (44, 47, 49, 255), W, ss)
    # ruined bridge pylons / arch remnants, to suggest old construction
    for bx in (410, 1380):
        for off in (-W, 0, W):
            for px in (bx, bx + 190):
                d.rectangle([(px + off) * ss, 560 * ss, (px + off + 26) * ss, 990 * ss], fill=(40, 43, 45, 255))
            d.rectangle([(bx + off - 30) * ss, 540 * ss, (bx + off + 250) * ss, 566 * ss], fill=(40, 43, 45, 255))
            d.polygon([((bx + off + 26) * ss, 566 * ss), ((bx + off + 70) * ss, 566 * ss), ((bx + off + 26) * ss, 640 * ss)], fill=(40, 43, 45, 255))
    img = img.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.1))
    img = fog_ramp(img, 520, 960, (118, 122, 121), 0.62)
    save(img, "bg_mid.png")


def make_fg_near():
    W, H = 2048, 1024
    ss = 2
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(37)
    for x in (260, 1010, 1560):
        h = rng.uniform(1100, 1300)
        tree(d, x, 1100, h, rng.uniform(46, 70), rng, (6, 7, 8, 255), W, ss, crown=False)
    # a few thin hanging roots / vines
    for _ in range(9):
        x = rng.uniform(0, W)
        ln = rng.uniform(160, 420)
        pts = [(x, -10)]
        for k in range(1, 9):
            pts.append((x + math.sin(k * 0.7 + x) * 8, -10 + ln * k / 8))
        d.line([(px * ss, py * ss) for px, py in pts], fill=(6, 7, 8, 255), width=int(3 * ss))
    img = img.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(3.0))
    save(img, "fg_near.png")


def make_fog():
    W, H = 1024, 512
    xs = np.arange(W)[None, :] / W * math.tau
    ys = np.arange(H)[:, None] / H
    rng = np.random.RandomState(5)
    n = np.zeros((H, W), dtype=np.float32)
    for k in range(1, 7):
        ph = rng.uniform(0, math.tau)
        amp = 1.0 / k
        n += amp * np.sin(xs * k + ph + np.sin(ys * math.tau * 1.5 + k) * 1.2)
    n = (n - n.min()) / (n.max() - n.min())
    vert = np.exp(-((ys - 0.62) / 0.26) ** 2)
    a = (n ** 1.6 * vert * 0.9).clip(0, 1)
    rgba = np.zeros((H, W, 4), dtype=np.uint8)
    rgba[..., :3] = 205
    rgba[..., 3] = (a * 255).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA").filter(ImageFilter.GaussianBlur(6))
    save(img, "fog.png")


# ----------------------------------------------------------------- tiles

def noise_tex(w, h, seed, lo, hi, scale):
    rng = np.random.RandomState(seed)
    small = rng.rand(h // scale + 2, w // scale + 2).astype(np.float32)
    big = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    a = np.asarray(big).astype(np.float32) / 255.0
    return lo + a * (hi - lo)


def make_ground():
    # fill tile 128x128 (tileable): dark earth with strata
    w = h = 128
    base = noise_tex(w, h, 3, 14, 30, 16) + noise_tex(w, h, 4, -5, 6, 4)
    for y in (30, 74, 108):
        base[y:y + 2, :] -= 5
    arr = np.stack([base, base + 1, base + 2], axis=-1).clip(0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(os.path.join(OUT, "ground_fill.png"))

    # top edge strip 128x96 (tileable in x): ragged rim with grass blades
    W, H = 128, 96
    ss = 4
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(8)
    edge = []
    for x in range(0, W + 1, 4):
        y = 40 + 4.0 * math.sin(x / W * math.tau * 2) + 3.0 * math.sin(x / W * math.tau * 5 + 1) + rng.uniform(-1.2, 1.2)
        edge.append((x, y))
    edge[-1] = (W, edge[0][1])
    body = [(x * ss, y * ss) for x, y in edge] + [(W * ss, H * ss), (0, H * ss)]
    d.polygon(body, fill=(19, 21, 23, 255))
    # rim light line (cold, faint)
    d.line([(x * ss, (y + 1) * ss) for x, y in edge], fill=(84, 90, 92, 255), width=3 * ss // 2)
    # grass blades (silhouette, wrap-safe)
    for i in range(18):
        x = rng.uniform(0, W)
        hgt = rng.uniform(10, 26)
        lean = rng.uniform(-6, 6)
        yb = 42
        for off in (-W, 0, W):
            d.polygon([((x + off - 1.4) * ss, yb * ss), ((x + off + lean) * ss, (yb - hgt) * ss), ((x + off + 1.4) * ss, yb * ss)], fill=(11, 12, 13, 255))
    img = img.resize((W, H), Image.LANCZOS)
    img.save(os.path.join(OUT, "ground_top.png"))


def make_plank():
    W, H = 64, 24
    ss = 4
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 4 * ss, W * ss, 18 * ss], fill=(24, 25, 27, 255))
    d.line([(0, 5 * ss), (W * ss, 5 * ss)], fill=(88, 92, 94, 255), width=2 * ss)
    rng = random.Random(4)
    for _ in range(5):
        y = rng.uniform(8, 16)
        d.line([(rng.uniform(0, W) * ss, y * ss), (rng.uniform(0, W) * ss, (y + rng.uniform(-1, 1)) * ss)], fill=(12, 13, 14, 255), width=ss)
    d.rectangle([(W - 4) * ss, 4 * ss, (W - 2) * ss, 18 * ss], fill=(12, 13, 14, 255))
    img.resize((W, H), Image.LANCZOS).save(os.path.join(OUT, "plank.png"))


def make_crate():
    S = 64
    ss = 4
    img = Image.new("RGBA", (S * ss, S * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2 * ss, 2 * ss, 62 * ss, 62 * ss], fill=(22, 23, 25, 255))
    for k in (2, 62):
        d.rectangle([2 * ss, (k - 3 if k == 62 else k) * ss, 62 * ss, (k + (0 if k == 62 else 3)) * ss], fill=(13, 14, 15, 255))
    d.rectangle([2 * ss, 2 * ss, 8 * ss, 62 * ss], fill=(13, 14, 15, 255))
    d.rectangle([56 * ss, 2 * ss, 62 * ss, 62 * ss], fill=(13, 14, 15, 255))
    d.line([(8 * ss, 8 * ss), (56 * ss, 56 * ss)], fill=(13, 14, 15, 255), width=5 * ss)
    d.line([(56 * ss, 8 * ss), (8 * ss, 56 * ss)], fill=(13, 14, 15, 255), width=5 * ss)
    d.line([(8 * ss, 4 * ss), (56 * ss, 4 * ss)], fill=(86, 90, 92, 255), width=2 * ss)  # rim light
    d.rectangle([2 * ss, 2 * ss, 62 * ss, 62 * ss], outline=(6, 6, 7, 255), width=2 * ss)
    img.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, "crate.png"))


def make_lever():
    W, H = 64, 72
    ss = 4
    for name, ang in (("lever_off.png", -0.75), ("lever_on.png", 0.75)):
        img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([14 * ss, 56 * ss, 50 * ss, 70 * ss], fill=(16, 17, 18, 255))
        d.line([(16 * ss, 57 * ss), (48 * ss, 57 * ss)], fill=(86, 90, 92, 255), width=2 * ss)
        px, py = 32, 56
        ex, ey = px + math.sin(ang) * 40, py - math.cos(ang) * 40
        d.line([(px * ss, py * ss), (ex * ss, ey * ss)], fill=(8, 9, 10, 255), width=5 * ss)
        d.ellipse([(ex - 5) * ss, (ey - 5) * ss, (ex + 5) * ss, (ey + 5) * ss], fill=(8, 9, 10, 255))
        d.ellipse([(px - 6) * ss, (py - 6) * ss, (px + 6) * ss, (py + 6) * ss], fill=(30, 32, 34, 255))
        img.resize((W, H), Image.LANCZOS).save(os.path.join(OUT, name))


def make_door():
    W, H = 64, 192
    ss = 3
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4 * ss, 0, 60 * ss, H * ss], fill=(17, 18, 20, 255))
    for y in range(0, H, 24):
        d.rectangle([4 * ss, y * ss, 60 * ss, (y + 3) * ss], fill=(9, 10, 11, 255))
    for x in (12, 32, 52):
        d.rectangle([(x - 2) * ss, 0, (x + 2) * ss, H * ss], fill=(10, 11, 12, 255))
    d.rectangle([4 * ss, 0, 7 * ss, H * ss], fill=(70, 74, 76, 255))
    d.rectangle([4 * ss, 0, 60 * ss, H * ss], outline=(5, 5, 6, 255), width=2 * ss)
    img.resize((W, H), Image.LANCZOS).save(os.path.join(OUT, "door.png"))


def make_thorns():
    W, H = 64, 44
    ss = 4
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(9)
    xs = [4, 14, 26, 36, 48, 58]
    for x in xs:
        hgt = rng.uniform(26, 40)
        lean = rng.uniform(-5, 5)
        d.polygon([((x - 5) * ss, H * ss), ((x + lean) * ss, (H - hgt) * ss), ((x + 5) * ss, H * ss)], fill=(7, 8, 9, 255))
        d.line([((x - 3) * ss, (H - 4) * ss), ((x + lean - 0.5) * ss, (H - hgt + 3) * ss)], fill=(78, 82, 84, 255), width=ss)
    d.rectangle([0, (H - 5) * ss, W * ss, H * ss], fill=(7, 8, 9, 255))
    img.resize((W, H), Image.LANCZOS).save(os.path.join(OUT, "thorns.png"))


def make_lantern():
    W, H = 48, 112
    ss = 4
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([22 * ss, 14 * ss, 26 * ss, 112 * ss], fill=(10, 11, 12, 255))
    d.line([(24 * ss, 14 * ss), (36 * ss, 14 * ss)], fill=(10, 11, 12, 255), width=3 * ss)
    d.line([(36 * ss, 14 * ss), (36 * ss, 24 * ss)], fill=(10, 11, 12, 255), width=2 * ss)
    d.rectangle([29 * ss, 24 * ss, 43 * ss, 46 * ss], fill=(10, 11, 12, 255))
    d.rectangle([32 * ss, 28 * ss, 40 * ss, 43 * ss], fill=(255, 196, 110, 255))  # flame: the only colour
    d.polygon([(28 * ss, 24 * ss), (44 * ss, 24 * ss), (36 * ss, 17 * ss)], fill=(10, 11, 12, 255))
    img.resize((W, H), Image.LANCZOS).save(os.path.join(OUT, "lantern.png"))


def make_gate():
    W, H = 192, 288
    ss = 3
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dark = (8, 9, 10, 255)
    d.rectangle([10 * ss, 60 * ss, 40 * ss, H * ss], fill=dark)
    d.rectangle([152 * ss, 60 * ss, 182 * ss, H * ss], fill=dark)
    d.pieslice([10 * ss, 10 * ss, 182 * ss, 190 * ss], 180, 360, fill=dark)
    d.pieslice([40 * ss, 40 * ss, 152 * ss, 170 * ss], 180, 360, fill=(0, 0, 0, 0))
    d.rectangle([40 * ss, 100 * ss, 152 * ss, H * ss], fill=(0, 0, 0, 0))
    img = img.resize((W, H), Image.LANCZOS)
    img.save(os.path.join(OUT, "gate.png"))


def make_vignette():
    W, H = 512, 288
    xs = np.linspace(-1, 1, W)[None, :]
    ys = np.linspace(-1, 1, H)[:, None]
    r = np.sqrt((xs * 0.95) ** 2 + (ys * 1.15) ** 2)
    a = np.clip((r - 0.45) / 0.85, 0, 1) ** 1.6 * 0.88
    rgba = np.zeros((H, W, 4), dtype=np.uint8)
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "vignette.png"))


def make_glow():
    S = 256
    xs = np.linspace(-1, 1, S)[None, :]
    ys = np.linspace(-1, 1, S)[:, None]
    r = np.sqrt(xs ** 2 + ys ** 2)
    a = np.clip(1 - r, 0, 1) ** 2.2
    rgba = np.zeros((S, S, 4), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "glow.png"))
    # light texture for PointLight2D (white centre -> black edge)
    g = (a * 255).astype(np.uint8)
    Image.fromarray(g, "L").convert("RGB").save(os.path.join(OUT, "light.png"))


def make_knob():
    S = 32
    ss = 4
    img = Image.new("RGBA", (S * ss, S * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([3 * ss, 3 * ss, 29 * ss, 29 * ss], fill=(214, 218, 218, 255))
    d.ellipse([3 * ss, 3 * ss, 29 * ss, 29 * ss], outline=(40, 42, 44, 255), width=2 * ss)
    img.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, "knob.png"))


def main():
    make_knob()
    make_bg_far()
    make_bg_mid()
    make_fg_near()
    make_fog()
    make_ground()
    make_plank()
    make_crate()
    make_lever()
    make_door()
    make_thorns()
    make_lantern()
    make_gate()
    make_vignette()
    make_glow()
    print("ok", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
