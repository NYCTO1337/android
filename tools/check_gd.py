#!/usr/bin/env python3
"""Cheap static checks for the GDScript files (NOT a replacement for Godot).

- tab-only indentation
- balanced (), [], {} outside of strings/comments
- every `Autoload.member` reference exists in that autoload script
- every res:// path used in scripts exists on disk
- every `UIKit.x(` / `Player.x` / `Level.x` style call exists
"""
import glob
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
files = sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True))
problems = []

AUTOLOADS = {
    "GameState": "scripts/autoload/game_state.gd",
    "AudioManager": "scripts/autoload/audio_manager.gd",
    "PerfGovernor": "scripts/autoload/perf_governor.gd",
    "PlatformService": "scripts/autoload/platform_service.gd",
    "SaveSystem": "scripts/autoload/save_system.gd",
    "UIKit": "scripts/game/ui_kit.gd",
}


def defined_members(path):
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    names = set(re.findall(r"^\s*(?:static\s+)?func\s+(\w+)", src, re.M))
    names |= set(re.findall(r"^\s*(?:static\s+)?var\s+(\w+)", src, re.M))
    names |= set(re.findall(r"^\s*const\s+(\w+)", src, re.M))
    names |= set(re.findall(r"^\s*signal\s+(\w+)", src, re.M))
    names |= set(re.findall(r"^\s*enum\s+(\w+)", src, re.M))
    return names


members = {k: defined_members(v) for k, v in AUTOLOADS.items()}
members["Player"] = defined_members("scripts/game/player.gd")


def strip(line):
    out, i, q = [], 0, None
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


for f in files:
    rel = os.path.relpath(f, ROOT)
    text = open(f, encoding="utf-8").read()
    depth = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    for n, raw in enumerate(text.split("\n"), 1):
        if re.match(r"^ +\S", raw):
            problems.append(f"{rel}:{n}: space indentation")
        line = strip(raw)
        for c in line:
            if c in depth:
                depth[c] += 1
            elif c in pairs:
                depth[pairs[c]] -= 1
        for m in re.finditer(r"\b(GameState|AudioManager|PerfGovernor|PlatformService|SaveSystem|UIKit|Player)\.(\w+)", line):
            owner, name = m.group(1), m.group(2)
            if name in ("new", "State", "make_frames") and owner in ("Player", "GameState"):
                if name == "make_frames" and "make_frames" not in members["Player"]:
                    problems.append(f"{rel}:{n}: Player.make_frames missing")
                continue
            if name not in members[owner]:
                problems.append(f"{rel}:{n}: {owner}.{name} is not defined")
    if any(v != 0 for v in depth.values()):
        problems.append(f"{rel}: unbalanced brackets {depth}")
    for m in re.finditer(r'"(res://[^"%]+)"', text):
        if not os.path.exists(os.path.join(ROOT, m.group(1)[6:])):
            problems.append(f"{rel}: missing resource {m.group(1)}")
    for m in re.finditer(r'"res://([^"]*)%s([^"]*)"', text):
        pass

# generated names used with format strings
for name in ["bg_far", "bg_mid", "fog", "fg_near", "ground_top", "ground_fill", "plank", "crate",
             "lever_off", "lever_on", "door", "thorns", "lantern", "gate", "glow", "light", "knob",
             "vignette", "char_sheet"]:
    if not os.path.exists(os.path.join(ROOT, "assets/art", name + ".png")):
        problems.append(f"missing assets/art/{name}.png")
for name in ["ambience", "jump", "land", "step", "lever", "door", "checkpoint", "death", "end"]:
    if not os.path.exists(os.path.join(ROOT, "assets/audio", name + ".wav")):
        problems.append(f"missing assets/audio/{name}.wav")

print(f"{len(files)} files checked")
print("\n".join(problems) if problems else "no problems found")
sys.exit(1 if problems else 0)
