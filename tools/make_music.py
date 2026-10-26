#!/usr/bin/env python3
"""Музыка игры, записанная нотами в этом файле.

Скрипт пишет MIDI (tools/music/*.mid), озвучивает их свободным SoundFont FluidR3_GM (лицензия MIT)
через fluidsynth и кодирует в OGG (assets/music/*.ogg). Темы:

- menu — главное меню: «Смело, товарищи, в ногу»;
- world_calm — спокойная тема мировой карты;
- world_tension — слой напряжения поверх неё (тот же темп и длина, звучат вместе): Реакция выше 60
  или открыто окно революции;
- battle — марш местных сражений: «Варшавянка»;
- victory — короткая тема победы: последняя фраза припева «Интернационала»;
- anthem — финал выигранной партии: весь припев «Интернационала»;
- defeat — короткая тема поражения.

Мелодии трёх песен — общественное достояние; их ноты переписаны с вокальных строк старых изданий,
гармония и аранжировки свои. Остальные темы сочинены для игры. Всё, что здесь записано, — CC0.
Петли озвучиваются дважды подряд, и берётся второй проход: так хвост реверберации конца переходит
в начало без щелчка.
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
FLAT_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


def pitch(name: str) -> int:
    """«C#4» → 61. Октава как в научной нотации (C4 = до первой октавы = 60)."""
    n = NOTE_NAMES[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        n += 1 if name[i] == "#" else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + n


CHORDS = {
    "": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "sus4": (0, 5, 7), "dim7": (0, 3, 6, 9),
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


def transpose_chord(name: str, shift: int) -> str:
    """«Dm» на +5 → «Gm»; новые названия — через бемоли."""
    if shift == 0:
        return name
    root, _ = chord(name)
    suffix = name[2:] if len(name) > 1 and name[1] in "#b" else name[1:]
    return FLAT_NAMES[(root + shift) % 12] + suffix


def seq(text: str, shift: int = 0) -> list[tuple[int | str, float]]:
    """Мелодия записью «A4/4 A4/8. G4/16 | R/8 G4/2+8»: высота/длительность (4 — четверть, 8. — восьмая
    с точкой, 2+8 — половинная, залигованная с восьмой), R — пауза, «|» — тактовая черта для чтения.
    shift — транспонировать на столько полутонов."""
    out: list[tuple[int | str, float]] = []
    for tok in text.split():
        if tok == "|":
            continue
        name, dur = tok.split("/")
        beats = 0.0
        for part in dur.split("+"):
            beats += 4.0 / int(part.rstrip(".")) * (1.5 if part.endswith(".") else 1.0)
        out.append(("R" if name == "R" else pitch(name) + shift, beats))
    return out


def harmony(text: str, shift: int = 0) -> list[tuple[float, float, str]]:
    """Аккорды по тактам в 4/4: «Dm | Dm:1 A:1 Dm:2 | A7» → [(доля, длительность, аккорд)].
    Аккорды без «:n» делят остаток такта поровну."""
    out = []
    for i, bar in enumerate(text.split("|")):
        items = bar.split()
        fixed = [float(x.split(":")[1]) for x in items if ":" in x]
        free = len(items) - len(fixed)
        beat = 4.0 * i
        for x in items:
            length = float(x.split(":")[1]) if ":" in x else (4.0 - sum(fixed)) / free
            out.append((beat, length, transpose_chord(x.split(":")[0], shift)))
            beat += length
    return out


def check_bars(name: str, text: str, pickup: bool = False) -> None:
    """Каждый такт мелодии — ровно четыре доли (кроме затакта и последнего, протянутого такта)."""
    bars = [sum(length for _, length in seq(bar)) for bar in text.split("|")]
    inner = bars[1:-1] if pickup else bars[:-1]
    bad = [i for i, b in enumerate(inner) if abs(b - 4.0) > 1e-6]
    if bad or bars[-1] < 4.0 - 1e-6:
        raise ValueError(f"{name}: неполные такты {bad} — {bars}")


def chord_at(chords: list[tuple[float, float, str]], beat: float) -> str:
    for start, length, name in chords:
        if start <= beat < start + length:
            return name
    return chords[-1][2]


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

    def line(self, start: float, items: list, vel: int = 80, octave_shift: int = 0, legato: float = 0.95) -> float:
        """Мелодия: [(«E5», 1), («R», 0.5), …] — нота (название или номер MIDI) и длительность в долях;
        R — пауза. legato — какую часть длительности нота звучит."""
        beat = start
        for p, length in items:
            if p != "R":
                n = pitch(p) if isinstance(p, str) else p
                self.note(beat, length * legato, n + 12 * octave_shift, vel)
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


# --- Песни: мелодии из общественного достояния, своя гармония и аранжировка ----------------------

def pad(track: Track, chords: list, off: float, low: int, vel: int, count: int = 3) -> None:
    """Выдержанные аккорды на всю длину каждой гармонии."""
    for start, length, c in chords:
        for p in voiced(c, low, count):
            track.note(off + start, length, p, vel)


def march_bass(track: Track, chords: list, off: float, octave: int, vel: int) -> None:
    """«Умпа»: бас на сильных долях — основной тон на смене аккорда и на первой доле, иначе квинта."""
    for start, length, c in chords:
        for j in range(int(length)):
            t = start + j
            if t % 2 == 0:
                p = bass_note(c, octave) if j == 0 or t % 4 == 0 else fifth(c, octave) - 12
                track.note(off + t, 0.9, p, vel if t % 4 == 0 else vel - 10)


def march_chords(track: Track, chords: list, off: float, low: int, vel: int) -> None:
    """«Па»: короткие аккорды на слабых долях."""
    end = int(chords[-1][0] + chords[-1][1])
    for t in range(1, end, 2):
        for p in voiced(chord_at(chords, t), low):
            track.note(off + t, 0.45, p, vel)


def snare_bar(drums: Track, b: float, vel: int, fill: bool = False) -> None:
    """Такт марша на малом барабане: восьмые с акцентами, в конце фразы — дробь шестнадцатыми."""
    accents = [1.0, 0.55, 0.75, 0.55, 0.9, 0.55, 0.75, 0.6]
    for k, a in enumerate(accents):
        if fill and k >= 6:
            continue
        drums.note(b + 0.5 * k, 0.4, 38, int(vel * a))
    if fill:
        for k in range(4):
            drums.note(b + 3 + 0.25 * k, 0.2, 38, int(vel * (0.6 + 0.12 * k)))


# «Варшавянка»: куплет (16 тактов) и припев (8), ре минор; в игре звучит в соль миноре.
VARSH_VERSE = """
A4/4 A4/8. G4/16 F4/4 F4/8. E4/16 | D4/4 D4/8. C#4/16 D4/4 F4/4 | E4/4 A4/8. A4/16 A4/8 G4/8 F4/8 E4/8 |
D4/8 E4/8 F4/8 G4/8 A4/2 |
A4/4 A4/8. A4/16 D5/4 A4/8. G4/16 | F4/4 F4/8. E4/16 D4/4 F4/4 | E4/4 A4/8. A4/16 A4/8 G4/8 F4/8 E4/8 |
D4/4 F4/8. E4/16 D4/2 |
F4/4 F4/8. F4/16 C4/4 F4/4 | G4/4 G4/8. G4/16 C4/4 G4/4 | G4/4 G4/8. G4/16 C5/8 Bb4/8 A4/8 G4/8 |
A4/4 A4/8. G4/16 A4/4 A4/4 |
A4/4 A4/8. A4/16 D5/4 A4/8. G4/16 | F4/4 F4/8. E4/16 D4/4 F4/4 | E4/4 A4/8. A4/16 A4/8 G4/8 F4/8 E4/8 |
D4/4 F4/8. E4/16 D4/4 E4/4
"""
VARSH_CHORUS = """
F4/4 F4/8. F4/16 C4/4 F4/4 | G4/4 G4/8. G4/16 C4/4 G4/4 | G4/4 G4/8. G4/16 C5/8 Bb4/8 A4/8 G4/8 |
A4/4 A4/8. G4/16 A4/2 |
A4/4 A4/8. A4/16 D5/4 A4/8 G4/8 | F4/4 F4/8. E4/16 D4/4 F4/4 | E4/4 A4/8. A4/16 A4/8 G4/8 F4/8 E4/8 |
D4/4 F4/8. E4/16 D4/2
"""
VARSH_VERSE_CHORDS = ("Dm | Dm | A7 | Dm | Dm | Bb:2 Dm:2 | A7 | Dm | "
                      "F | C | C7 | F | Dm | Bb:2 Dm:2 | A7 | Dm:3 C7:1")
VARSH_CHORUS_CHORDS = "F | C | C7 | F | Dm | Bb:2 Dm:2 | A7 | Dm"
VARSH_SHIFT = 5
BATTLE_BARS = 48


def battle(tracks: dict[int, Track], off: float) -> None:
    """Куплет и припев дважды: сначала труба соло, потом вся медь; во втором припеве — тутти с тарелками."""
    drums = get(tracks, 9, 0, volume=100, reverb=35)
    timp = get(tracks, 1, 47, volume=92, reverb=45)
    brass = get(tracks, 2, 61, volume=76, reverb=50)
    trumpet = get(tracks, 3, 56, volume=100, reverb=55, pan=70)
    horns = get(tracks, 4, 60, volume=88, reverb=60, pan=54)
    tuba = get(tracks, 5, 58, volume=92, reverb=40)
    trombone = get(tracks, 6, 57, volume=84, reverb=50, pan=80)
    strings = get(tracks, 0, 48, volume=72, reverb=70, pan=40)
    verse, chorus = seq(VARSH_VERSE, VARSH_SHIFT), seq(VARSH_CHORUS, VARSH_SHIFT)
    vchords, cchords = harmony(VARSH_VERSE_CHORDS, VARSH_SHIFT), harmony(VARSH_CHORUS_CHORDS, VARSH_SHIFT)
    plan = [(0, verse, vchords, 0), (16, chorus, cchords, 1), (24, verse, vchords, 2), (40, chorus, cchords, 3)]
    for bar0, melody, chords, level in plan:
        b0 = off + 4 * bar0
        bars = int(sum(length for _, length in melody) / 4)
        march_bass(tuba, chords, b0, 2, 78 + 4 * level)
        march_chords(brass, chords, b0, 55, 46 + 6 * level)
        if level >= 2:
            pad(strings, chords, b0, 55, 40 + 4 * level)
        else:
            pad(strings, chords, b0, 50, 34, 2)
        for i in range(bars):
            b = b0 + 4 * i
            snare_bar(drums, b, 70 + 8 * level, fill=i % 4 == 3)
            drums.note(b, 0.5, 36, 80 + 6 * level)
            drums.note(b + 2, 0.5, 36, 66 + 6 * level)
            if level == 3 and i % 2 == 0:
                drums.note(b, 1, 49, 70)
            if level >= 1:
                timp.note(b, 0.9, bass_note(chord_at(chords, 4 * i), 2), 64 + 6 * level)
        drums.note(b0, 2, 49, 80 + 10 * level)
        # Дробь литавр перед припевом.
        if level in (0, 2):
            last = b0 + 4 * (bars - 1)
            for k in range(8):
                timp.note(last + 2 + 0.25 * k, 0.25, bass_note(chord_at(chords, 4 * bars - 1), 2), 50 + 6 * k)
        trumpet.line(b0, melody, vel=84 + 6 * level, legato=0.85)
        if level in (1, 3):
            horns.line(b0, melody, vel=78 + 6 * level, octave_shift=-1, legato=0.9)
        if level >= 2:
            trombone.line(b0, melody, vel=70 + 6 * level, octave_shift=-1, legato=0.85)
        if level == 3:
            strings.line(b0, melody, vel=64, octave_shift=1, legato=0.9)


# «Смело, товарищи, в ногу»: вступление и куплет (по партии корнета, записанной до мажором);
# в игре звучит в си-бемоль мажоре, как в духовом оркестре.
SMELO_INTRO = """
G4/4 F#4/8. G4/16 A4/4 G4/8. F4/16 | G4/2 E4/2 | G4/4 F#4/8. G4/16 A4/4 B4/8. B4/16 | C5/1
"""
SMELO_SONG = """
A4/4 A4/8. B4/16 C5/4 B4/8. A4/16 | G4/4 E5/4 E5/2 | F5/4 D5/8. C5/16 B4/4 A4/8. B4/16 | C5/1
"""
SMELO_INTRO_CHORDS = "C:1 F#dim7:1 F:1 C:1 | C | C:1 F#dim7:1 G7:2 | C"
SMELO_CHORDS = "F:3 G7:1 | C | G7 | C"
SMELO_QUIET_CHORDS = "Am:2 F:1 G7:1 | C | Dm:2 G7:2 | C"
SMELO_SHIFT = -2
MENU_BARS = 20


def menu(tracks: dict[int, Track], off: float) -> None:
    """Вступление на валторне, куплет у кларнета, у меди, тихо у струнных и последний раз — тутти."""
    strings = get(tracks, 0, 48, volume=74, reverb=80, pan=44)
    pizz = get(tracks, 1, 45, volume=74, reverb=50, pan=56)
    tuba = get(tracks, 2, 58, volume=78, reverb=45)
    horn = get(tracks, 3, 60, volume=82, reverb=80, pan=72)
    clarinet = get(tracks, 4, 71, volume=80, reverb=75, pan=60)
    trumpet = get(tracks, 5, 56, volume=86, reverb=65, pan=66)
    brass = get(tracks, 6, 61, volume=64, reverb=60)
    timp = get(tracks, 7, 47, volume=78, reverb=60)
    harp = get(tracks, 8, 46, volume=72, reverb=80, pan=36)
    drums = get(tracks, 9, 0, volume=70, reverb=45)
    intro, song = seq(SMELO_INTRO, SMELO_SHIFT), seq(SMELO_SONG, SMELO_SHIFT)
    plan = [(0, intro, SMELO_INTRO_CHORDS, "intro"), (4, song, SMELO_CHORDS, "clarinet"), (8, song, SMELO_CHORDS, "brass"),
            (12, song, SMELO_QUIET_CHORDS, "strings"), (16, song, SMELO_CHORDS, "tutti")]
    for bar0, melody, chord_text, part in plan:
        b0 = off + 4 * bar0
        chords = harmony(chord_text, SMELO_SHIFT)
        loud = part in ("brass", "tutti")
        pad(strings, chords, b0, 53, 46 if loud else 38)
        if part == "strings":
            # Тихий куплет: арфа перебирает аккорды, бас — щипком.
            for start, length, c in chords:
                tones = voiced(c, 55, 3) + [voiced(c, 55, 3)[0] + 12]
                for k in range(int(length * 2)):
                    harp.note(b0 + start + 0.5 * k, 0.5, tones[k % 4], 46)
                pizz.note(b0 + start, 1, bass_note(c, 2), 52)
            strings.line(b0, melody, vel=66, octave_shift=1)
            for k in range(8):
                drums.note(b0 + 14 + 0.25 * k, 0.25, 38, 28 + 6 * k)
            continue
        march_bass(pizz if not loud else tuba, chords, b0, 2, 58 if not loud else 72)
        march_chords(pizz if not loud else brass, chords, b0, 55, 40 if not loud else 54)
        for i in range(4):
            b = b0 + 4 * i
            snare_bar(drums, b, 34 if not loud else 58, fill=i == 3)
            drums.note(b, 0.5, 36, 46 if not loud else 66)
            if loud:
                timp.note(b, 0.9, bass_note(chord_at(chords, 4 * i), 2), 66)
        if part == "intro":
            horn.line(b0, melody, vel=64)
        elif part == "clarinet":
            clarinet.line(b0, melody, vel=70, legato=0.88)
        elif part == "brass":
            trumpet.line(b0, melody, vel=82, legato=0.88)
            horn.line(b0, melody, vel=70, octave_shift=-1)
        else:
            drums.note(b0, 2, 49, 76)
            trumpet.line(b0, melody, vel=90, legato=0.88)
            horn.line(b0, melody, vel=78, octave_shift=-1)
            strings.line(b0, melody, vel=60, octave_shift=1)


# «Интернационал» (музыка П. Дегейтера): припев, соль мажор; в игре звучит в си-бемоль мажоре.
# Первая доля такта 0 — вступление: дробь и аккорд, затакт «Э-то» на четвёртой доле.
INTER_CHORUS = """
B4/8. A4/16 | G4/2 D4/4. B3/8 | E4/2 C4/8 R/8 A4/8. G4/16 | F#4/2 E4/4 D4/4 | D4/2+8 R/8 D4/4 |
B4/2 A4/4 D4/8 D4/8 | G4/2 F#4/4. F#4/8 | E4/4. D#4/8 E4/4 A4/4 | A4/2+8 R/8 B4/8. A4/16 |
G4/2 D4/4. B3/8 | E4/2 C4/8 R/8 A4/8. G4/16 | F#4/2 E4/4 D4/4 | B4/2. B4/4 |
D5/2 C5/4 B4/8 B4/8 | A4/4. B4/8 C5/4 R/8 C5/8 | B4/4. B4/8 A4/4. A4/8 | G4/1+4
"""
INTER_CHORUS_CHORDS = ("D7:3 G:1 | G | C:3 D7:1 | D7 | G | G:2 D:2 | C:2 D:2 | Em:1.5 B7:0.5 Em:1 A7:1 | D:3 D7:1 | "
                       "G | C:3 D7:1 | D7 | G:3 E7:1 | E7:2 Am:1 E7:1 | D7 | G:2 D7:2 | G:6")
# Последняя фраза: «с Интернационалом воспрянет род людской».
INTER_FINAL = "B4/4 | D5/2 C5/4 B4/8 B4/8 | A4/4. B4/8 C5/4 R/8 C5/8 | B4/4. B4/8 A4/4. A4/8 | G4/1+4"
INTER_FINAL_CHORDS = "G:3 E7:1 | E7:2 Am:1 E7:1 | D7 | G:2 D7:2 | G:6"
INTER_SHIFT = 3


def anthem_part(tracks: dict[int, Track], off: float, melody_text: str, chord_text: str, pickup: float,
                grand_from: int) -> None:
    """Медь и струнные под мелодию «Интернационала»; с такта grand_from — тутти."""
    trumpet = get(tracks, 3, 56, volume=100, reverb=70, pan=70)
    horns = get(tracks, 4, 60, volume=92, reverb=75, pan=54)
    brass = get(tracks, 2, 61, volume=80, reverb=70)
    trombone = get(tracks, 6, 57, volume=86, reverb=65, pan=80)
    strings = get(tracks, 0, 48, volume=80, reverb=80, pan=40)
    tuba = get(tracks, 5, 58, volume=92, reverb=55)
    timp = get(tracks, 1, 47, volume=96, reverb=60)
    drums = get(tracks, 9, 0, volume=96, reverb=60)
    chords = harmony(chord_text, INTER_SHIFT)
    melody = seq(melody_text, INTER_SHIFT)
    for start, length, c in chords:
        grand = start >= 4 * grand_from
        for p in voiced(c, 53, 4):
            brass.note(off + start, length, p, 72 if grand else 58)
            strings.note(off + start, length, p + 12, 66 if grand else 52)
        tuba.note(off + start, length, bass_note(c, 2), 86 if grand else 72)
        if start % 4 == 0 or grand:
            timp.note(off + start, 0.9, bass_note(c, 2), 78 if grand else 60)
    # Вступление: аккорд с тарелкой и дробь малого барабана до затакта.
    drums.note(off, 2, 49, 90)
    for k in range(int(pickup * 4) - 4):
        drums.note(off + 1 + 0.25 * k, 0.25, 38, 40 + 4 * k)
    end = chords[-1][0]
    drums.note(off + end, 4, 49, 110)
    drums.note(off + end, 1, 36, 110)
    for k in range(12):
        timp.note(off + end - 3 + 0.25 * k, 0.25, bass_note(chords[-1][2], 2), 56 + 4 * k)
    grand_beat = 4 * grand_from
    beat = off + pickup
    for p, length in melody:
        t = beat - off
        if p != "R":
            grand = t >= grand_beat
            trumpet.note(beat, length * 0.92, p, 100 if grand else 88)
            horns.note(beat, length * 0.95, p - 12, 90 if grand else 82)
            if grand:
                trombone.note(beat, length * 0.92, p - 12, 82)
                strings.note(beat, length * 0.95, p + 12, 70)
        beat += length


def victory(tracks: dict[int, Track], off: float) -> None:
    anthem_part(tracks, off, INTER_FINAL, INTER_FINAL_CHORDS, pickup=3, grand_from=1)


def anthem(tracks: dict[int, Track], off: float) -> None:
    anthem_part(tracks, off, INTER_CHORUS, INTER_CHORUS_CHORDS, pickup=3.0, grand_from=9)


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
    for name, text, pickup in [("Варшавянка, куплет", VARSH_VERSE, False), ("Варшавянка, припев", VARSH_CHORUS, False),
                               ("Смело, товарищи, вступление", SMELO_INTRO, False), ("Смело, товарищи", SMELO_SONG, False),
                               ("Интернационал, припев", INTER_CHORUS, True), ("Интернационал, финал", INTER_FINAL, True)]:
        check_bars(name, text, pickup)
    calm_beats = 4 * len(CALM_BARS)
    make("world_calm", 80, calm_beats, world_calm, loop=True, peak=0.6)
    make("world_tension", 80, calm_beats, world_tension, loop=True, peak=0.6)
    make("battle", 112, 4 * BATTLE_BARS, battle, loop=True, peak=0.7)
    make("menu", 100, 4 * MENU_BARS, menu, loop=True, peak=0.65)
    make("victory", 92, 26, victory, loop=False, peak=0.8)
    make("anthem", 92, 80, anthem, loop=False, peak=0.8)
    make("defeat", 66, 26, defeat, loop=False, peak=0.7)


if __name__ == "__main__":
    main()
