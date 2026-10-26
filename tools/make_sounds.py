#!/usr/bin/env python3
"""Звуки игры: синтез из шума и синусоид, без чужих записей.

Пишет assets/sounds/*.wav (короткие) и *.ogg (длинные и петли) — щелчок интерфейса, удар печати,
телеграф, гул и рёв толпы, заводской гудок, барабан и дробь, колокол, пузырёк, сигнал, неудача,
шорох бумаги. Все звуки — собственные (CC0). Запуск: python3 tools/make_sounds.py (нужны numpy и ffmpeg).
"""
from __future__ import annotations

import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sounds"
RATE = 22050
rng = np.random.default_rng(1871)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def env(n: int, attack: float, release: float, curve: float = 3.0) -> np.ndarray:
    """Огибающая: быстрая атака и экспоненциальный спад."""
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    r = np.exp(-curve * np.maximum(t - attack, 0.0) / max(release, 1e-4))
    return a * r


def shaped_noise(n: int, low: float, high: float, tilt: float = 0.0) -> np.ndarray:
    """Шум в полосе low–high Гц (через спектр): так быстрее фильтров в цикле."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    band = np.exp(-0.5 * ((np.log(np.maximum(f, 1.0)) - np.log(np.sqrt(low * high))) / (0.5 * np.log(high / low))) ** 4)
    band *= np.maximum(f, 1.0) ** tilt
    out = np.fft.irfft(spec * band, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    return np.fft.irfft(spec / np.sqrt(1.0 + (f / cutoff) ** 4), len(x))


def normalize(x: np.ndarray, peak: float = 0.85) -> np.ndarray:
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name: str, x: np.ndarray, peak: float = 0.85) -> None:
    x = normalize(x, peak)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"{path.relative_to(ROOT)}: {len(x) / RATE:.2f} с")


def save_ogg(name: str, x: np.ndarray, peak: float = 0.85) -> None:
    save(name, x, peak)
    wav = OUT / f"{name}.wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                    str(OUT / f"{name}.ogg")], check=True)
    wav.unlink()


def loopable(x: np.ndarray, fade: float = 0.5) -> np.ndarray:
    """Петля без щелчка: хвост плавно накладывается на начало."""
    k = int(fade * RATE)
    head, body, tail = x[:k], x[k:-k], x[-k:]
    w = np.linspace(0.0, 1.0, k)
    return np.concatenate([head * w + tail * (1.0 - w), body])


# --- Интерфейс -----------------------------------------------------------------

def click() -> np.ndarray:
    n = int(0.045 * RATE)
    t = np.arange(n) / RATE
    tick = np.sin(2 * np.pi * 2400 * t) * env(n, 0.0005, 0.012, 4.0)
    return tick + 0.4 * shaped_noise(n, 2000, 9000) * env(n, 0.0002, 0.006, 4.0)


def stamp() -> np.ndarray:
    n = int(0.32 * RATE)
    t = np.arange(n) / RATE
    thump = np.sin(2 * np.pi * (70 + 60 * np.exp(-t * 40)) * t) * env(n, 0.001, 0.09, 3.0)
    slap = shaped_noise(n, 300, 3500) * env(n, 0.0005, 0.035, 4.0)
    return thump * 1.0 + slap * 0.7


def telegraph() -> np.ndarray:
    """Стук телеграфного аппарата: «клик» якоря и «клак» отпускания."""
    out = np.zeros(int(0.16 * RATE))
    for start, f, amp in ((0.0, 1650, 1.0), (0.075, 1250, 0.7)):
        n = int(0.05 * RATE)
        t = np.arange(n) / RATE
        hit = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.7 * t)) * env(n, 0.0003, 0.012, 4.0)
        hit += 0.6 * shaped_noise(n, 1500, 8000) * env(n, 0.0002, 0.004, 4.0)
        s = int(start * RATE)
        out[s:s + n] += amp * hit
    return out


def page() -> np.ndarray:
    n = int(0.22 * RATE)
    t = np.arange(n) / RATE
    x = shaped_noise(n, 1500, 7000) * np.sin(np.pi * t / t[-1]) ** 2
    return x * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t))


def bubble() -> np.ndarray:
    n = int(0.22 * RATE)
    t = np.arange(n) / RATE
    f = 480 + 900 * (t / t[-1]) ** 0.6
    phase = 2 * np.pi * np.cumsum(f) / RATE
    pop = np.sin(phase) * env(n, 0.003, 0.09, 3.0)
    shimmer = (np.sin(2 * np.pi * 1760 * t) + np.sin(2 * np.pi * 2640 * t)) * env(n, 0.02, 0.12, 3.0) * 0.25
    return pop + shimmer * (t > 0.05)


def alert() -> np.ndarray:
    """Короткий сигнал внимания: два тона медной окраски."""
    out = np.zeros(int(0.5 * RATE))
    for start, f in ((0.0, 523.25), (0.16, 783.99)):
        n = int(0.3 * RATE)
        t = np.arange(n) / RATE
        tone = sum(np.sin(2 * np.pi * f * k * t) / k ** 1.2 for k in range(1, 8))
        s = int(start * RATE)
        out[s:s + n] += tone * env(n, 0.015, 0.22, 3.0)
    return lowpass(out, 3500)


def fail() -> np.ndarray:
    n = int(0.45 * RATE)
    t = np.arange(n) / RATE
    f = 220 * np.exp(-t * 1.6)
    tone = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.005, 0.3, 3.0)
    thud = np.sin(2 * np.pi * 60 * t) * env(n, 0.002, 0.08, 3.0)
    return tone * 0.7 + thud


# --- Улица и бой ---------------------------------------------------------------

def crowd(seconds: float, excitement: float) -> np.ndarray:
    """Толпа: много «голосов» — шум через форманты гласных с медленно плавающей громкостью."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    formants = [(700, 1200), (400, 2000), (300, 800), (550, 1700), (450, 1000)]
    for i in range(36):
        f1, f2 = formants[i % len(formants)]
        voice = shaped_noise(n, f1 * 0.7, f1 * 1.4) + 0.6 * shaped_noise(n, f2 * 0.8, f2 * 1.25)
        rate = rng.uniform(0.6, 2.2) * (1.0 + excitement)
        phase = rng.uniform(0, 2 * np.pi)
        amp = np.clip(np.sin(2 * np.pi * rate * t + phase) + rng.uniform(-0.2, 0.4), 0.0, None) ** 1.5
        out += voice * amp * rng.uniform(0.4, 1.0)
    out += 0.5 * shaped_noise(n, 150, 600)
    return lowpass(out, 4000 + 2000 * excitement)


def crowd_roar() -> np.ndarray:
    x = crowd(2.6, 1.0)
    t = t_axis(2.6)
    swell = np.clip(t / 0.5, 0, 1) * np.exp(-np.maximum(t - 1.2, 0) * 1.4)
    return x * swell


def factory_whistle() -> np.ndarray:
    """Заводской гудок: аккорд паровых свистков с дыханием пара и лёгким вибрато."""
    seconds = 2.6
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    body = np.zeros(n)
    for f, a in ((311.13, 1.0), (392.0, 0.8), (466.16, 0.6)):
        phase = 2 * np.pi * np.cumsum(f * vib) / RATE
        body += a * (np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.15 * np.sin(3 * phase))
    steam = shaped_noise(n, 800, 6000)
    shape = np.clip(t / 0.35, 0, 1) * np.clip((seconds - t) / 0.8, 0, 1)
    pitch_in = np.clip(t / 0.25, 0.85, 1.0)
    return lowpass(body * shape * pitch_in + 0.35 * steam * shape, 5000)


def drum_hit() -> np.ndarray:
    """Большой барабан: низкий тон с падающей высотой и удар колотушки."""
    n = int(1.1 * RATE)
    t = np.arange(n) / RATE
    f = 55 + 45 * np.exp(-t * 18)
    boom = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.002, 0.55, 3.0)
    skin = shaped_noise(n, 120, 1200) * env(n, 0.001, 0.08, 4.0) * 0.5
    return boom + skin


def drum_roll() -> np.ndarray:
    """Дробь малого барабана, нарастающая и обрывающаяся ударом."""
    seconds = 1.6
    n = int(seconds * RATE)
    out = np.zeros(n)
    times = np.cumsum(np.full(40, 0.032) + rng.uniform(-0.003, 0.003, 40))
    for i, s in enumerate(times):
        if s >= seconds - 0.4:
            break
        m = int(0.06 * RATE)
        tt = np.arange(m) / RATE
        hit = (shaped_noise(m, 1500, 9000) * 0.8 + np.sin(2 * np.pi * 190 * tt) * 0.5) * env(m, 0.0005, 0.03, 4.0)
        k = int(s * RATE)
        out[k:k + m] += hit * (0.35 + 0.65 * i / 40)
    k = int((seconds - 0.38) * RATE)
    m = n - k
    tt = np.arange(m) / RATE
    out[k:] += (shaped_noise(m, 1200, 9000) * 1.3 + np.sin(2 * np.pi * 170 * tt)) * env(m, 0.0005, 0.12, 3.0)
    return out


def bell() -> np.ndarray:
    """Колокол: негармонические обертоны с разным временем затухания."""
    seconds = 4.5
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    f0 = 196.0
    partials = [(0.5, 1.0, 3.5), (1.0, 0.9, 2.8), (1.19, 0.6, 2.2), (1.5, 0.5, 1.8), (2.0, 0.55, 1.5),
                (2.5, 0.3, 1.1), (2.67, 0.35, 1.0), (3.0, 0.25, 0.8), (4.07, 0.2, 0.6), (5.4, 0.12, 0.4)]
    out = np.zeros(n)
    for ratio, amp, decay in partials:
        out += amp * np.sin(2 * np.pi * f0 * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t / decay)
    strike = shaped_noise(n, 1500, 8000) * env(n, 0.0005, 0.02, 4.0) * 0.4
    return (out + strike) * np.clip(t / 0.003, 0, 1)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save("click", click(), 0.6)
    save("stamp", stamp())
    save("telegraph", telegraph(), 0.5)
    save("page", page(), 0.45)
    save("bubble", bubble(), 0.6)
    save("alert", alert(), 0.6)
    save("fail", fail(), 0.7)
    save("drum_hit", drum_hit(), 0.9)
    save_ogg("drum_roll", drum_roll(), 0.75)
    save_ogg("crowd_loop", loopable(crowd(7.0, 0.2)), 0.5)
    save_ogg("crowd_roar", crowd_roar(), 0.7)
    save_ogg("factory_whistle", factory_whistle(), 0.7)
    save_ogg("bell", bell(), 0.8)


if __name__ == "__main__":
    main()
