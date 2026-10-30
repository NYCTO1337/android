#!/usr/bin/env python3
"""Generates the hero sprite sheet (assets/art/char_sheet.png).

A small, lonely human silhouette drawn from a 2-bone skeleton per limb
(side view, facing right). Every frame is rendered at 4x and downsampled for
clean anti-aliased edges. The lowest point of the body is always placed on the
same baseline, so feet match the physics collider in every pose.

Sheet layout: 8 columns x 6 rows of 96x96 cells
  row 0 idle (6)   row 1 walk (8)   row 2 jump (2)
  row 3 fall (2)   row 4 land (3)   row 5 die (8)
"""
import math
import os
import sys
from PIL import Image, ImageDraw

CELL = 96
S = 4                      # supersampling
BASELINE = 90.0            # y of the soles inside a cell
COLS, ROWS = 8, 6

# proportions (cell pixels): total standing height ~ 73
THIGH, SHIN = 17.0, 17.0
TORSO = 23.0
NECK = 3.0
HEAD_R = 6.3
UARM, FARM = 12.0, 12.0

NEAR = (6, 7, 9, 255)
FAR = (19, 21, 25, 255)
EYE = (205, 210, 214, 235)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    return t * t * (3 - 2 * t)


class Pose:
    def __init__(self, **kw):
        # all angles in radians. limb angles measured from "straight down",
        # positive = swung forward (to the right).
        self.lean = 0.10       # torso lean (forward positive)
        self.head = 0.05       # head tilt relative to torso
        self.hip_dx = 0.0
        self.n_th, self.n_sh = 0.0, 0.0     # near leg thigh / shin (absolute)
        self.f_th, self.f_sh = 0.0, 0.0     # far leg
        self.n_ua, self.n_fa = 0.1, 0.2     # near arm
        self.f_ua, self.f_fa = -0.1, 0.05   # far arm
        self.eye = True
        self.__dict__.update(kw)

    def mix(self, o, t):
        r = Pose()
        for k, v in self.__dict__.items():
            ov = o.__dict__[k]
            r.__dict__[k] = lerp(v, ov, t) if isinstance(v, float) else (v if t < 0.5 else ov)
        return r


def tapered(draw, p0, p1, r0, r1, col):
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    d = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / d, dx / d
    poly = [
        ((x0 + nx * r0) * S, (y0 + ny * r0) * S),
        ((x1 + nx * r1) * S, (y1 + ny * r1) * S),
        ((x1 - nx * r1) * S, (y1 - ny * r1) * S),
        ((x0 - nx * r0) * S, (y0 - ny * r0) * S),
    ]
    draw.polygon(poly, fill=col)
    for (x, y, r) in ((x0, y0, r0), (x1, y1, r1)):
        draw.ellipse(((x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S), fill=col)


def fk(origin, length, ang):
    return (origin[0] + math.sin(ang) * length, origin[1] + math.cos(ang) * length)


def build(pose, hip_y_guess=56.0):
    """Returns dict of joint positions for a pose, hip placed at hip_y_guess."""
    hx = 48.0 + pose.hip_dx
    hip = (hx, hip_y_guess)
    sh = (hip[0] + math.sin(pose.lean) * TORSO, hip[1] - math.cos(pose.lean) * TORSO)
    neck = (sh[0] + math.sin(pose.lean + pose.head * 0.5) * NECK,
            sh[1] - math.cos(pose.lean + pose.head * 0.5) * NECK)
    ha = pose.lean + pose.head
    head = (neck[0] + math.sin(ha) * (HEAD_R * 0.9), neck[1] - math.cos(ha) * (HEAD_R * 0.9))
    j = {"hip": hip, "sh": sh, "neck": neck, "head": head, "ha": ha}
    for side, th, shn, ua, fa in (("n", pose.n_th, pose.n_sh, pose.n_ua, pose.n_fa),
                                  ("f", pose.f_th, pose.f_sh, pose.f_ua, pose.f_fa)):
        knee = fk(hip, THIGH, th)
        ankle = fk(knee, SHIN, shn)
        toe = (ankle[0] + 6.5, ankle[1] + 1.2)
        elbow = fk((sh[0], sh[1] + 1.5), UARM, ua)
        hand = fk(elbow, FARM, fa)
        j[side + "knee"], j[side + "ankle"], j[side + "toe"] = knee, ankle, toe
        j[side + "elbow"], j[side + "hand"] = elbow, hand
    return j


def lowest(j):
    ys = [j["nankle"][1] + 2.4, j["fankle"][1] + 2.4, j["ntoe"][1] + 2.0, j["ftoe"][1] + 2.0,
          j["nknee"][1] + 3.0, j["fknee"][1] + 3.0, j["hip"][1] + 4.0,
          j["nhand"][1] + 2.0, j["fhand"][1] + 2.0, j["head"][1] + HEAD_R,
          j["nelbow"][1] + 2.4, j["felbow"][1] + 2.4, j["sh"][1] + 4.0]
    return max(ys)


def render(pose):
    j = build(pose)
    shift = BASELINE - lowest(j)
    j = build(pose, 56.0 + shift)
    img = Image.new("RGBA", (CELL * S, CELL * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # far limbs first (slightly lighter so the pose stays readable)
    tapered(d, j["hip"], j["fknee"], 4.4, 3.5, FAR)
    tapered(d, j["fknee"], j["fankle"], 3.5, 2.6, FAR)
    tapered(d, j["fankle"], j["ftoe"], 2.3, 1.9, FAR)
    tapered(d, (j["sh"][0], j["sh"][1] + 1.5), j["felbow"], 2.7, 2.2, FAR)
    tapered(d, j["felbow"], j["fhand"], 2.2, 1.7, FAR)

    # torso (tapered: broader shoulders), short tunic, neck, head
    tapered(d, j["hip"], j["sh"], 4.6, 5.6, NEAR)
    hem = (j["hip"][0] - math.sin(pose.lean) * 3.0, j["hip"][1] + 9.0)
    shb = (j["sh"][0], j["sh"][1])
    d.polygon([((shb[0] - 5.4) * S, (shb[1] + 1.0) * S), ((shb[0] + 5.2) * S, (shb[1] + 1.0) * S),
               ((hem[0] + 6.6) * S, hem[1] * S), ((hem[0] - 6.8) * S, hem[1] * S)], fill=NEAR)
    tapered(d, j["sh"], j["neck"], 2.4, 2.1, NEAR)
    hx, hy = j["head"]
    d.ellipse(((hx - HEAD_R) * S, (hy - HEAD_R) * S, (hx + HEAD_R) * S, (hy + HEAD_R) * S), fill=NEAR)
    # slight jaw / nose bump so the head reads as a human profile
    ha = j["ha"]
    nx, ny = hx + math.cos(ha) * HEAD_R * 0.95, hy + math.sin(ha) * HEAD_R * 0.95
    d.ellipse(((nx - 1.3) * S, (ny - 1.3) * S, (nx + 1.3) * S, (ny + 1.3) * S), fill=NEAR)
    if pose.eye:
        ex, ey = hx + math.cos(ha) * 3.4 - math.sin(ha) * 0.2, hy + math.sin(ha) * 3.4 - 0.9
        d.ellipse(((ex - 0.95) * S, (ey - 0.95) * S, (ex + 0.95) * S, (ey + 0.95) * S), fill=EYE)

    # near limbs
    tapered(d, j["hip"], j["nknee"], 4.7, 3.7, NEAR)
    tapered(d, j["nknee"], j["nankle"], 3.7, 2.6, NEAR)
    tapered(d, j["nankle"], j["ntoe"], 2.4, 2.0, NEAR)
    tapered(d, (j["sh"][0], j["sh"][1] + 1.5), j["nelbow"], 2.9, 2.3, NEAR)
    tapered(d, j["nelbow"], j["nhand"], 2.3, 1.8, NEAR)
    return img.resize((CELL, CELL), Image.LANCZOS)


# ------------------------------------------------------------------ poses

def idle(i, n=6):
    t = i / n
    b = math.sin(t * math.tau)
    return Pose(lean=0.09 + 0.012 * b, head=0.10 - 0.02 * b,
                n_th=0.10, n_sh=0.04, f_th=-0.12, f_sh=-0.07,
                n_ua=0.10 + 0.02 * b, n_fa=0.50 + 0.04 * b,
                f_ua=-0.18 - 0.02 * b, f_fa=0.22)


def walk(i, n=8):
    ph = i / n * math.tau
    def leg(p):
        th = 0.62 * math.sin(p)
        flex = 1.05 * max(0.0, math.cos(p)) ** 1.2 + 0.08
        return th, th - flex
    nt, ns = leg(ph)
    ft, fs = leg(ph + math.pi)
    na = -0.55 * math.sin(ph)
    fa = -0.55 * math.sin(ph + math.pi)
    return Pose(lean=0.13, head=0.02, hip_dx=0.0,
                n_th=nt, n_sh=ns, f_th=ft, f_sh=fs,
                n_ua=na, n_fa=na + 0.55 + 0.25 * max(0.0, math.sin(ph)),
                f_ua=fa, f_fa=fa + 0.55 + 0.25 * max(0.0, math.sin(ph + math.pi)))


def jump(i):
    if i == 0:   # push-off, arms up
        return Pose(lean=0.10, head=-0.10, n_th=0.35, n_sh=-0.30, f_th=-0.35, f_sh=-0.85,
                    n_ua=2.45, n_fa=2.20, f_ua=2.10, f_fa=1.90)
    return Pose(lean=0.08, head=-0.05, n_th=0.95, n_sh=-0.35, f_th=0.10, f_sh=-0.55,
                n_ua=2.65, n_fa=2.55, f_ua=2.35, f_fa=2.30)


def fall(i):
    if i == 0:
        return Pose(lean=-0.04, head=-0.02, n_th=0.45, n_sh=0.10, f_th=-0.40, f_sh=-0.55,
                    n_ua=2.55, n_fa=2.75, f_ua=2.30, f_fa=2.55)
    return Pose(lean=-0.06, head=0.0, n_th=0.30, n_sh=0.15, f_th=-0.25, f_sh=-0.35,
                n_ua=2.75, n_fa=2.95, f_ua=2.45, f_fa=2.70)


def land(i):
    k = [1.0, 0.8, 0.35][i]
    return Pose(lean=0.12 + 0.45 * k, head=0.15 * k, n_th=0.95 * k, n_sh=0.95 * k - 1.75 * k,
                f_th=0.80 * k, f_sh=0.80 * k - 1.60 * k,
                n_ua=0.55 * k, n_fa=0.95 * k, f_ua=0.40 * k, f_fa=0.8 * k)


def die(i, n=8):
    t = smooth(i / (n - 1))
    start = Pose(lean=0.12, head=0.02, n_th=0.0, n_sh=0.0, f_th=-0.05, f_sh=-0.05,
                 n_ua=0.1, n_fa=0.2, f_ua=-0.1, f_fa=0.05)
    mid = Pose(lean=0.65, head=0.25, hip_dx=-4.0, n_th=0.95, n_sh=-0.40, f_th=0.70, f_sh=-0.60,
               n_ua=1.1, n_fa=1.5, f_ua=0.9, f_fa=1.3)
    end = Pose(lean=1.50, head=0.12, hip_dx=-16.0, n_th=-1.52, n_sh=-1.55, f_th=-1.45, f_sh=-1.55,
               n_ua=1.75, n_fa=1.60, f_ua=1.90, f_fa=1.70, eye=False)
    if t < 0.5:
        p = start.mix(mid, smooth(t * 2))
    else:
        p = mid.mix(end, smooth((t - 0.5) * 2))
    return p


def main(out_dir):
    rows = [
        [idle(i) for i in range(6)],
        [walk(i) for i in range(8)],
        [jump(i) for i in range(2)],
        [fall(i) for i in range(2)],
        [land(i) for i in range(3)],
        [die(i) for i in range(8)],
    ]
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for r, poses in enumerate(rows):
        for c, p in enumerate(poses):
            sheet.paste(render(p), (c * CELL, r * CELL))
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "char_sheet.png"))
    # preview on a misty background (not shipped)
    prev = Image.new("RGBA", sheet.size, (150, 152, 150, 255))
    prev.alpha_composite(sheet)
    prev = prev.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    prev.convert("RGB").save("/tmp/char_preview.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/art")
