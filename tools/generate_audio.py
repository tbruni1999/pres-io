#!/usr/bin/env python3
"""Genera los sonidos provisionales del prototipo (originales, sin licencias externas).

Uso: python3 tools/generate_audio.py
Escribe WAV mono 16 bits en assets/audio/. Solo usa la biblioteca estándar.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print(path, len(samples) / RATE, "s")


def chime(freqs, dur=0.32, gap=0.09):
    out = []
    for i, f in enumerate(freqs):
        n0 = int(i * gap * RATE)
        while len(out) < n0 + int(dur * RATE):
            out.append(0.0)
        for n in range(int(dur * RATE)):
            t = n / RATE
            env = math.exp(-t * 9.0) * min(1.0, t * 200)
            out[n0 + n] += 0.35 * env * (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t))
    return out


def footstep(seed):
    rnd = random.Random(seed)
    out, lp = [], 0.0
    for n in range(int(0.11 * RATE)):
        t = n / RATE
        lp += 0.18 * (rnd.uniform(-1, 1) - lp)
        out.append(0.9 * lp * math.exp(-t * 38.0) * min(1.0, t * 400))
    return out


def wind(seconds=8.0):
    rnd = random.Random(7)
    out, lp, lp2 = [], 0.0, 0.0
    total = int(seconds * RATE)
    for n in range(total):
        t = n / RATE
        lp += 0.02 * (rnd.uniform(-1, 1) - lp)
        lp2 += 0.05 * (lp - lp2)
        gust = 0.55 + 0.45 * math.sin(2 * math.pi * t / seconds) ** 2
        fade = min(1.0, t / 0.4, (seconds - t) / 0.4)
        out.append(2.2 * lp2 * gust * fade)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("ui_confirm.wav", chime([660.0, 880.0]))
    write("ui_error.wav", chime([220.0, 185.0], dur=0.25, gap=0.12))
    write("footstep_dirt.wav", footstep(3))
    write("ambient_wind.wav", wind())
