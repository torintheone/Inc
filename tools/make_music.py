#!/usr/bin/env python3
"""Музыка игры: собственные темы, записанные нотами в этом файле.

Скрипт пишет MIDI (tools/music/*.mid), озвучивает их свободным SoundFont FluidR3_GM (лицензия MIT)
через fluidsynth и кодирует в OGG (assets/music/*.ogg). Темы:

- menu — главное меню;
- world_calm — спокойная тема мировой карты;
- world_tension — слой напряжения поверх неё (тот же темп и длина, звучат вместе): Реакция выше 60
  или открыто окно революции;
- battle — марш местных сражений;
- victory, defeat — короткие темы победы и поражения.

Все мелодии и аранжировки сочинены для игры (CC0). Петли озвучиваются дважды подряд, и берётся второй
проход: так хвост реверберации конца переходит в начало без щелчка.
Запуск: python3 tools/make_music.py (нужны fluidsynth, ffmpeg и /usr/share/sounds/sf2/FluidR3_GM.sf2).
"""
from __future__ import annotations

import struct
import subprocess
import tempfile
import wave
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
MIDI_DIR = ROOT / "tools" / "music"
OUT = ROOT / "assets" / "music"
SOUNDFONT = Path("/usr/share/sounds/sf2/FluidR3_GM.sf2")
TPB = 480
RATE = 44100

NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def pitch(name: str) -> int:
    """«C#4» → 61. Октава как в научной нотации (C4 = до первой октавы = 60)."""
    n = NOTE_NAMES[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        n += 1 if name[i] == "#" else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + n


CHORDS = {
    "": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "sus4": (0, 5, 7),
}


def chord(name: str) -> tuple[int, tuple[int, ...]]:
    """«Am» → (9, (0, 3, 7)); «F#m» → (6, ...); «Bb» → (10, ...)."""
    root = NOTE_NAMES[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        root += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        root -= 1
        rest = rest[1:]
    return root % 12, CHORDS[rest]


@dataclass
class Track:
    channel: int
    program: int
    volume: int = 100
    reverb: int = 50
    pan: int = 64
    notes: list = field(default_factory=list)
    controls: list = field(default_factory=list)

    def note(self, beat: float, length: float, p: int | str, vel: int = 80) -> None:
        self.notes.append((beat, length, pitch(p) if isinstance(p, str) else p, vel))

    def line(self, start: float, items: list, vel: int = 80, octave_shift: int = 0) -> float:
        """Мелодия: [(«E5», 1), («R», 0.5), …] — нота и длительность в долях; R — пауза."""
        beat = start
        for p, length in items:
            if p != "R":
                self.note(beat, length * 0.95, pitch(p) + 12 * octave_shift, vel)
            beat += length
        return beat

    def cc(self, beat: float, number: int, value: int) -> None:
        self.controls.append((beat, number, value))


def voiced(name: str, low: int, count: int = 3) -> list[int]:
    """Звуки аккорда от ноты low вверх (тесное расположение)."""
    root, intervals = chord(name)
    out = []
    p = low
    while len(out) < count:
        if (p - root) % 12 in intervals:
            out.append(p)
        p += 1
    return out


def bass_note(name: str, octave: int) -> int:
    root, _ = chord(name)
    return 12 * (octave + 1) + root


def fifth(name: str, octave: int) -> int:
    return bass_note(name, octave) + 7


# --- MIDI ------------------------------------------------------------------------

def _vlq(n: int) -> bytes:
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))


def write_midi(path: Path, bpm: float, tracks: list[Track]) -> None:
    chunks = []
    tempo = int(60_000_000 / bpm)
    meta = _vlq(0) + b"\xff\x51\x03" + tempo.to_bytes(3, "big") + _vlq(0) + b"\xff\x58\x04\x04\x02\x18\x08"
    meta += _vlq(0) + b"\xff\x2f\x00"
    chunks.append(meta)
    for t in tracks:
        ch = t.channel
        events = [(0, 0, bytes([0xB0 | ch, 7, t.volume])), (0, 0, bytes([0xB0 | ch, 91, t.reverb])),
                  (0, 0, bytes([0xB0 | ch, 10, t.pan])), (0, 0, bytes([0xC0 | ch, t.program]))]
        for beat, number, value in t.controls:
            events.append((int(beat * TPB), 1, bytes([0xB0 | ch, number, value])))
        for beat, length, p, vel in t.notes:
            on = int(beat * TPB)
            off = on + max(int(length * TPB), 1)
            events.append((on, 2, bytes([0x90 | ch, p, max(1, min(vel, 127))])))
            events.append((off, 0, bytes([0x80 | ch, p, 0])))
        events.sort(key=lambda e: (e[0], e[1]))
        data = b""
        now = 0
        for tick, _, msg in events:
            data += _vlq(tick - now) + msg
            now = tick
        data += _vlq(0) + b"\xff\x2f\x00"
        chunks.append(data)
    body = b"MThd" + struct.pack(">IHHH", 6, 1, len(chunks), TPB)
    for c in chunks:
        body += b"MTrk" + struct.pack(">I", len(c)) + c
    path.write_bytes(body)


# --- Озвучка ---------------------------------------------------------------------

def render(mid: Path) -> np.ndarray:
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "out.wav"
        subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.5", "-r", str(RATE), "-F", str(wav), str(SOUNDFONT), str(mid)],
                       check=True, capture_output=True)
        with wave.open(str(wav)) as w:
            x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").reshape(-1, w.getnchannels())
    return x.astype(np.float64) / 32768.0


def encode(name: str, x: np.ndarray, peak: float = 0.8) -> None:
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data.tobytes())
        out = OUT / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(out)],
                       check=True)
    print(f"{out.relative_to(ROOT)}: {len(x) / RATE:.1f} с")


def trim_tail(x: np.ndarray, threshold: float = 0.003, fade: float = 1.5) -> np.ndarray:
    """Обрезать тишину в конце и плавно погасить хвост реверберации."""
    level = np.max(np.abs(x), axis=1)
    loud = np.nonzero(level > threshold * np.max(level))[0]
    end = int(loud[-1]) + 1 if len(loud) else len(x)
    x = x[:end].copy()
    k = min(int(fade * RATE), len(x))
    x[-k:] *= np.linspace(1.0, 0.0, k)[:, None]
    return x


def make(name: str, bpm: float, beats: float, build, loop: bool, peak: float = 0.8) -> np.ndarray:
    """build(tracks, offset) кладёт ноты пьесы со сдвигом offset долей."""
    tracks: dict[int, Track] = {}
    passes = 2 if loop else 1
    for k in range(passes):
        build(tracks, k * beats)
    mid = MIDI_DIR / f"{name}.mid"
    write_midi(mid, bpm, list(tracks.values()))
    x = render(mid)
    if loop:
        length = int(round(beats * 60.0 / bpm * RATE))
        x = x[length:2 * length]
    else:
        x = trim_tail(x)
    encode(name, x, peak)
    return x


def get(tracks: dict[int, Track], channel: int, program: int, **kw) -> Track:
    if channel not in tracks:
        tracks[channel] = Track(channel, program, **kw)
    return tracks[channel]


# --- Темы ------------------------------------------------------------------------

CALM_BARS = ["Am", "Am", "F", "F", "C", "C", "G", "G", "Am", "Am", "Dm", "Dm", "F", "F", "E", "E"] * 2
CALM_MELODY = [
    ("E5", 2), ("C5", 1), ("D5", 1), ("E5", 3), ("A4", 1), ("C5", 2), ("A4", 1), ("G4", 1), ("F4", 4),
    ("G4", 2), ("C5", 1), ("E5", 1), ("D5", 3), ("C5", 1), ("B4", 2), ("G4", 1), ("A4", 1), ("B4", 4),
    ("C5", 2), ("B4", 1), ("A4", 1), ("E5", 4), ("F5", 2), ("E5", 1), ("D5", 1), ("A4", 4),
    ("C5", 2), ("D5", 1), ("E5", 1), ("F5", 3), ("E5", 1), ("D5", 2), ("C5", 1), ("B4", 1), ("G#4", 2), ("B4", 2),
]
CALM_COUNTER = [("E5", 4), ("E5", 4), ("F5", 4), ("E5", 4), ("E5", 4), ("D5", 4), ("D5", 4), ("B4", 4)]


def world_calm(tracks: dict[int, Track], off: float) -> None:
    pad = get(tracks, 0, 48, volume=82, reverb=80)
    piano = get(tracks, 1, 0, volume=84, reverb=60, pan=50)
    bass = get(tracks, 2, 43, volume=75, reverb=50)
    horn = get(tracks, 3, 60, volume=66, reverb=85, pan=76)
    oboe = get(tracks, 4, 68, volume=70, reverb=80, pan=40)
    for i, c in enumerate(CALM_BARS):
        b = off + 4 * i
        for p in voiced(c, 57):
            pad.note(b, 4, p, 46)
        r = bass_note(c, 3)
        for k, step in enumerate([0, 7, 12, 16 if chord(c)[1][1] == 4 else 15, 12, 7, 0, 7]):
            piano.note(b + 0.5 * k, 0.5, r + step, 34 + (6 if k == 0 else 0))
        bass.note(b, 4, bass_note(c, 2), 52)
    oboe.line(off + 32, CALM_COUNTER, vel=46)
    horn.line(off + 64, CALM_MELODY, vel=62)


def world_tension(tracks: dict[int, Track], off: float) -> None:
    trem = get(tracks, 0, 44, volume=80, reverb=60)
    timp = get(tracks, 1, 47, volume=95, reverb=50)
    pizz = get(tracks, 2, 45, volume=70, reverb=40, pan=44)
    trb = get(tracks, 3, 57, volume=78, reverb=60, pan=84)
    drums = get(tracks, 9, 0, volume=80, reverb=40)
    for i, c in enumerate(CALM_BARS):
        b = off + 4 * i
        r = bass_note(c, 2)
        trem.note(b, 4, r + 12, 50)
        trem.note(b, 4, r + 19, 44)
        # Нарастание на каждые четыре такта: громкость полосой через выразительность (CC11).
        for k in range(8):
            trem.cc(b + 0.5 * k, 11, 70 + ((i % 4) * 8 + k * 2))
        timp.note(b, 1, r, 70)
        timp.note(b + 2, 1, r, 55)
        timp.note(b + 3.5, 0.5, r + 7 - 12 if r + 7 - 12 >= 40 else r + 7, 50)
        for k in range(8):
            pizz.note(b + 0.5 * k, 0.4, r + 12 + (7 if k % 2 else 0), 40 + (10 if k % 4 == 0 else 0))
        if i % 2 == 0:
            trb.note(b, 1.2, r + 12, 62)
            trb.note(b, 1.2, r + 19, 56)
        drums.note(b, 0.5, 36, 70)
        drums.note(b + 1.5, 0.5, 36, 50)
        if i % 4 == 3:
            for k in range(4):
                drums.note(b + 3 + 0.25 * k, 0.25, 38, 30 + 12 * k)


BATTLE_BARS = ["Dm", "Dm", "Bb", "C", "Dm", "A", "Dm", "A", "F", "C", "Dm", "A", "Bb", "C", "A", "A"] * 2
BATTLE_MELODY = [
    ("A4", 1), ("D5", 1.5), ("E5", 0.5), ("F5", 1), ("E5", 1), ("D5", 1), ("A4", 2),
    ("D5", 1), ("F5", 1.5), ("G5", 0.5), ("F5", 1), ("E5", 2), ("C5", 2),
    ("D5", 1), ("F5", 1), ("A5", 2), ("G5", 1), ("F5", 1), ("E5", 2),
    ("F5", 1), ("E5", 1), ("D5", 1), ("A4", 1), ("C#5", 2), ("E5", 2),
    ("F5", 1.5), ("E5", 0.5), ("D5", 1), ("C5", 1), ("E5", 2), ("G4", 2),
    ("A4", 1), ("D5", 1), ("F5", 1), ("D5", 1), ("E5", 2), ("C#5", 2),
    ("D5", 1), ("F5", 1), ("Bb5", 2), ("A5", 1), ("G5", 1), ("E5", 2),
    ("C#5", 1), ("E5", 1), ("A5", 2), ("A5", 3), ("R", 1),
]


def battle(tracks: dict[int, Track], off: float) -> None:
    drums = get(tracks, 9, 0, volume=100, reverb=35)
    timp = get(tracks, 1, 47, volume=95, reverb=45)
    brass = get(tracks, 2, 61, volume=82, reverb=55)
    trumpet = get(tracks, 3, 56, volume=96, reverb=60, pan=70)
    horns = get(tracks, 4, 60, volume=85, reverb=60, pan=54)
    tuba = get(tracks, 5, 58, volume=90, reverb=40)
    strings = get(tracks, 0, 48, volume=70, reverb=70)
    for i, c in enumerate(BATTLE_BARS):
        b = off + 4 * i
        accents = [100, 55, 80, 55, 90, 55, 80, 60]
        for k, v in enumerate(accents):
            drums.note(b + 0.5 * k, 0.4, 38, v)
        if i % 4 == 3:
            for k in range(4):
                drums.note(b + 3 + 0.25 * k, 0.2, 38, 70 + 8 * k)
        drums.note(b, 0.5, 36, 95)
        drums.note(b + 2, 0.5, 36, 85)
        if i % 16 == 0:
            drums.note(b, 2, 49, 100)
        timp.note(b, 1, bass_note(c, 2), 80)
        for k in (0, 2):
            for p in voiced(c, 55):
                brass.note(b + k, 0.8, p, 70 if k == 0 else 60)
        tuba.note(b, 1, bass_note(c, 2), 85)
        tuba.note(b + 2, 1, fifth(c, 2) - (12 if fifth(c, 2) > 52 else 0), 75)
        for p in voiced(c, 50, 2):
            strings.note(b, 4, p, 50)
    trumpet.line(off, BATTLE_MELODY, vel=88)
    trumpet.line(off + 64, BATTLE_MELODY, vel=100)
    horns.line(off + 64, BATTLE_MELODY, vel=82, octave_shift=-1)


MENU_BARS = ["Em", "Em", "C", "C", "G", "G", "D", "D", "Em", "C", "G", "D", "Em", "C", "D", "D",
             "C", "D", "Em", "Em", "C", "D", "G", "G"]
MENU_MELODY = [
    ("B4", 2), ("E5", 1), ("F#5", 1), ("G5", 2), ("E5", 2), ("D5", 1), ("B4", 1), ("G4", 2), ("A4", 4),
    ("B4", 1), ("E5", 1), ("G5", 1), ("F#5", 1), ("E5", 2), ("C5", 2), ("D5", 1), ("E5", 1), ("F#5", 1), ("A5", 1),
    ("F#5", 4), ("G5", 2), ("E5", 1), ("C5", 1), ("F#5", 2), ("D5", 1), ("A4", 1), ("B4", 1), ("E5", 1), ("G5", 2),
    ("F#5", 2), ("E5", 2), ("C5", 1), ("E5", 1), ("G5", 2), ("A5", 2), ("F#5", 2), ("G5", 4), ("D5", 2), ("B4", 2),
]


def menu(tracks: dict[int, Track], off: float) -> None:
    piano = get(tracks, 1, 0, volume=88, reverb=60)
    strings = get(tracks, 0, 48, volume=72, reverb=80)
    bass = get(tracks, 2, 43, volume=78, reverb=50)
    horn = get(tracks, 3, 60, volume=70, reverb=85, pan=72)
    brass = get(tracks, 4, 61, volume=60, reverb=70)
    timp = get(tracks, 5, 47, volume=70, reverb=60)
    for i, c in enumerate(MENU_BARS):
        b = off + 4 * i
        r = bass_note(c, 3)
        for k in range(4):
            for p in voiced(c, 55 if k % 2 == 0 else 60):
                piano.note(b + k, 0.9, p, 38 if k else 46)
        for p in voiced(c, 52, 3):
            strings.note(b, 4, p, 48)
        bass.note(b, 4, bass_note(c, 2), 56)
        if i >= 16:
            for p in voiced(c, 55):
                brass.note(b, 2, p, 50)
            timp.note(b, 1, r - 12, 55)
    horn.line(off + 32, MENU_MELODY, vel=74)


def victory(tracks: dict[int, Track], off: float) -> None:
    trumpet = get(tracks, 3, 56, volume=100, reverb=70)
    brass = get(tracks, 2, 61, volume=90, reverb=70)
    strings = get(tracks, 0, 48, volume=80, reverb=80)
    timp = get(tracks, 1, 47, volume=100, reverb=60)
    drums = get(tracks, 9, 0, volume=100, reverb=60)
    tuba = get(tracks, 5, 58, volume=90, reverb=50)
    melody = [("G4", 0.5), ("C5", 0.5), ("E5", 0.5), ("G5", 0.5), ("G5", 2), ("A5", 1), ("G5", 1), ("F5", 1), ("A5", 1),
              ("G5", 3), ("D5", 1), ("E5", 1), ("G5", 1), ("C6", 2), ("C6", 4)]
    trumpet.line(off, melody, vel=100)
    for bar, c in enumerate(["C", "F", "G", "C", "C"]):
        b = off + 4 * bar
        length = 4 if bar < 4 else 6
        for p in voiced(c, 55, 4):
            brass.note(b, length, p, 80)
            strings.note(b, length, p + 12, 70)
        tuba.note(b, length, bass_note(c, 2), 90)
        timp.note(b, 1, bass_note(c, 2), 90)
    for k in range(16):
        timp.note(off + 12 + 0.25 * k, 0.25, bass_note("C", 2), 60 + 2 * k)
        drums.note(off + 12 + 0.25 * k, 0.25, 38, 50 + 3 * k)
    drums.note(off + 16, 4, 49, 110)
    drums.note(off + 16, 1, 36, 110)


def defeat(tracks: dict[int, Track], off: float) -> None:
    strings = get(tracks, 0, 48, volume=85, reverb=90)
    horn = get(tracks, 3, 60, volume=90, reverb=90)
    bass = get(tracks, 2, 43, volume=85, reverb=70)
    timp = get(tracks, 1, 47, volume=80, reverb=80)
    bells = get(tracks, 4, 14, volume=70, reverb=90)
    for bar, c in enumerate(["Cm", "Ab", "Fm", "G", "Cm"]):
        b = off + 4 * bar
        length = 4 if bar < 4 else 7
        for p in voiced(c, 55, 3):
            strings.note(b, length, p, 58)
        bass.note(b, length, bass_note(c, 2), 66)
    horn.line(off, [("G4", 4), ("Ab4", 2), ("C5", 2), ("F4", 2), ("Ab4", 1), ("G4", 1), ("F4", 2), ("D4", 2), ("C4", 6)], vel=78)
    for k in range(8):
        timp.note(off + 12 + 0.5 * k, 0.5, bass_note("G", 2), 40 + 4 * k)
    bells.note(off + 16, 6, pitch("C4"), 70)


def main() -> None:
    MIDI_DIR.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    calm_beats = 4 * len(CALM_BARS)
    make("world_calm", 80, calm_beats, world_calm, loop=True, peak=0.6)
    make("world_tension", 80, calm_beats, world_tension, loop=True, peak=0.6)
    make("battle", 116, 4 * len(BATTLE_BARS), battle, loop=True, peak=0.7)
    make("menu", 92, 4 * len(MENU_BARS), menu, loop=True, peak=0.65)
    make("victory", 100, 26, victory, loop=False, peak=0.8)
    make("defeat", 66, 26, defeat, loop=False, peak=0.7)


if __name__ == "__main__":
    main()
