#!/usr/bin/env python3
"""Synthesises every sound into assets/audio/*.wav (16-bit mono, 22.05 kHz).

Dark, sparse, quiet: low drones, filtered wind, soft thuds, one low bell.
The ambience loop is seamless (circular FFT-filtered noise + LFOs with an
integer number of cycles per loop).
"""
import os
import sys
import wave

import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
SR = 22050
os.makedirs(OUT, exist_ok=True)
rng = np.random.RandomState(7)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def env_ad(n, attack, decay_pow=3.0):
    x = np.linspace(0, 1, n)
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * (1 - x) ** decay_pow


def lowpass(x, cutoff):
    """Circular FFT low-pass (keeps loops seamless)."""
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1.0 / (1.0 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def highpass(x, cutoff):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1.0 - 1.0 / (1.0 + (freqs / cutoff) ** 2)
    return np.fft.irfft(f, len(x))


def norm(x, peak):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def ambience():
    sec = 16.0
    t = t_axis(sec)
    n = len(t)
    drone = (np.sin(2 * np.pi * 55.0 * t) * 0.5 + np.sin(2 * np.pi * 82.5 * t + 0.4) * 0.3
             + np.sin(2 * np.pi * 110.0 * t + 1.1) * 0.15)
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * (2 / sec) * t)       # 2 cycles / loop
    drone *= lfo
    wind = lowpass(rng.randn(n), 380.0)
    wind = highpass(wind, 60.0)
    wlfo = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * (3 / sec) * t + 1.3))
    wind = norm(wind, 1.0) * wlfo
    x = norm(drone, 0.5) * 0.55 + wind * 0.42
    save("ambience", norm(x, 0.55))


def jump():
    n = int(0.16 * SR)
    x = lowpass(rng.randn(n), 900.0) * env_ad(n, 0.08, 2.2)
    x += np.sin(2 * np.pi * np.linspace(150, 260, n).cumsum() / SR) * env_ad(n, 0.05, 2.5) * 0.25
    save("jump", norm(x, 0.35))


def land():
    n = int(0.22 * SR)
    t = t_axis(0.22)
    x = np.sin(2 * np.pi * 68 * t) * env_ad(n, 0.01, 4.0)
    x += lowpass(rng.randn(n), 500.0) * env_ad(n, 0.01, 3.5) * 0.7
    save("land", norm(x, 0.55))


def step():
    n = int(0.08 * SR)
    x = lowpass(rng.randn(n), 700.0) * env_ad(n, 0.04, 3.0)
    save("step", norm(x, 0.22))


def lever():
    n = int(0.28 * SR)
    x = np.zeros(n)
    for start in (0.0, 0.09):
        s = int(start * SR)
        m = int(0.06 * SR)
        click = highpass(rng.randn(m), 1500.0) * env_ad(m, 0.02, 4.0)
        click += np.sin(2 * np.pi * 210 * np.arange(m) / SR) * env_ad(m, 0.02, 4.0) * 0.6
        x[s:s + m] += click
    save("lever", norm(x, 0.5))


def door():
    sec = 1.6
    n = int(sec * SR)
    t = t_axis(sec)
    rumble = lowpass(rng.randn(n), 140.0)
    saw = ((t * 38.0) % 1.0) * 2 - 1
    grind = lowpass(saw, 300.0) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))
    env = np.clip(t / 0.15, 0, 1) * np.clip((sec - t) / 0.35, 0, 1)
    x = (norm(rumble, 1.0) * 0.7 + norm(grind, 1.0) * 0.4) * env
    save("door", norm(x, 0.5))


def checkpoint():
    sec = 2.2
    t = t_axis(sec)
    x = np.zeros_like(t)
    for f, a, d in ((196.0, 1.0, 2.2), (293.7, 0.45, 3.0), (392.0, 0.3, 3.6), (587.3, 0.12, 4.5)):
        x += np.sin(2 * np.pi * f * t) * a * np.exp(-t * d)
    x *= np.clip(t / 0.01, 0, 1)
    save("checkpoint", norm(x, 0.4))


def death():
    sec = 0.9
    n = int(sec * SR)
    t = t_axis(sec)
    x = np.sin(2 * np.pi * 52 * t) * np.exp(-t * 5.0) * 1.0
    sweep = np.sin(2 * np.pi * np.linspace(200, 55, n).cumsum() / SR) * np.exp(-t * 3.5) * 0.5
    thud = lowpass(rng.randn(n), 350.0) * np.exp(-t * 9.0) * 0.8
    save("death", norm(x + sweep + thud, 0.6))


def end():
    sec = 6.0
    t = t_axis(sec)
    x = np.zeros_like(t)
    for f, a in ((73.4, 1.0), (110.0, 0.7), (146.8, 0.5), (174.6, 0.35), (220.0, 0.25)):
        x += np.sin(2 * np.pi * f * t + f) * a
    env = np.clip(t / 2.0, 0, 1) * np.clip((sec - t) / 2.5, 0, 1)
    save("end", norm(x * env, 0.45))


for fn in (ambience, jump, land, step, lever, door, checkpoint, death, end):
    fn()
print("ok", sorted(os.listdir(OUT)))
