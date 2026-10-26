#!/usr/bin/env python3
"""Иллюстрации из Grok → единый стиль игры.

Берёт картинки из art/incoming/ (имя файла — id из ART_LIST.md, расширение любое: png, jpg, webp),
обрезает и масштабирует под формат из ART_LIST.md, приводит к палитре игры (киноварь, чёрный,
бумага, охра, сталь, бетон), накладывает общую бумажную фактуру и зерно и сохраняет в
assets/art/<id>.webp. Манифест assets/art/manifest.json помнит, из какого файла сделана картинка:
неизменённые картинки повторно не обрабатываются. Так разнобой между картинками выравнивается сам.

Запуск: python3 tools/process_art.py (нужны numpy и Pillow). --self-test — проверить на сгенерированных
картинках во временной папке, ничего не трогая в репозитории.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
INCOMING = ROOT / "art" / "incoming"
OUT = ROOT / "assets" / "art"
ART_LIST = ROOT / "ART_LIST.md"
EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
VERSION = 1

PALETTE = {
    "paper": "#EFE6D2", "ink": "#1A1A1A", "vermilion": "#C62828", "dark_red": "#8E1C1C",
    "ochre": "#D4A13A", "steel": "#3D5A80", "concrete": "#8A8A84",
}
# Сколько от исходной светотени оставить поверх палитры: детали лиц и фактуры не пропадают.
DETAIL = 0.28
# Наибольший размер в игре: события 1280×720, фоны 1600×900, карточки 512×512, портреты 600×800.
MAX_SIDE = {"ev": 1280, "bg": 1600, "card": 512, "class": 800, "line": 512, "app": 1024}
QUALITY = 82


def hex_rgb(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64) / 255.0


def to_lab(rgb: np.ndarray) -> np.ndarray:
    """sRGB (0–1) → CIELAB: в нём ближайший цвет палитры выбирается «на глаз», а не по каналам."""
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def formats() -> dict[str, tuple[int, int]]:
    """id → (ширина, высота) из ART_LIST.md: «Файл: `ev_lockout.png` · формат 16:9 (1600×900)»."""
    text = ART_LIST.read_text(encoding="utf-8")
    out = {}
    for name, w, h in re.findall(r"`([a-z0-9_]+)\.png` · формат [0-9:]+ \((\d+)×(\d+)\)", text):
        out[name] = (int(w), int(h))
    return out


def target_size(art_id: str, size: tuple[int, int]) -> tuple[int, int]:
    w, h = size
    limit = MAX_SIDE.get(art_id.split("_")[0], 1280)
    k = min(1.0, limit / max(w, h))
    return max(1, round(w * k)), max(1, round(h * k))


def crop_resize(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Обрезать по центру под нужные пропорции (чуть выше центра — там обычно лица) и уменьшить."""
    w, h = img.size
    tw, th = size
    want = tw / th
    if w / h > want:
        nw = round(h * want)
        box = ((w - nw) // 2, 0, (w - nw) // 2 + nw, h)
    else:
        nh = round(w / want)
        top = max(0, min(h - nh, round((h - nh) * 0.4)))
        box = (0, top, w, top + nh)
    return img.crop(box).resize(size, Image.Resampling.LANCZOS)


def paper_texture(size: tuple[int, int], seed: int = 1917) -> np.ndarray:
    """Общая бумажная фактура: крупные пятна, волокна и мелкое зерно (множитель около 1)."""
    rng = np.random.default_rng(seed)
    w, h = size

    def smooth_noise(cells_x: int, cells_y: int) -> np.ndarray:
        small = Image.fromarray((rng.random((cells_y, cells_x)) * 255).astype(np.uint8))
        return np.asarray(small.resize((w, h), Image.Resampling.BICUBIC), dtype=np.float64) / 255.0

    blots = smooth_noise(max(2, w // 160), max(2, h // 160)) * 0.6 + smooth_noise(max(2, w // 40), max(2, h // 40)) * 0.4
    fibers = smooth_noise(max(2, w // 3), max(2, h // 60))
    grain = rng.random((h, w))
    return 1.0 - 0.07 * (blots - 0.5) - 0.03 * (fibers - 0.5) - 0.05 * (grain - 0.5)


def stylize(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB").filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float64) / 255.0
    # Контраст: плакат любит плотные тёмные и чистые светлые.
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    lo, hi = np.percentile(lum, 3), np.percentile(lum, 97)
    rgb = np.clip((rgb - lo) / max(hi - lo, 1e-3), 0.0, 1.0)
    names = list(PALETTE)
    pal_rgb = np.stack([hex_rgb(PALETTE[n]) for n in names])
    pal_lab = to_lab(pal_rgb)
    lab = to_lab(rgb)
    # Цветность весит меньше яркости: светотень важнее точного оттенка.
    d = ((lab[..., None, :] - pal_lab[None, None]) * np.array([1.0, 0.7, 0.7])) ** 2
    nearest = pal_rgb[np.argmin(d.sum(-1), axis=-1)]
    # Тон картинки поверх палитры: тёмное — к чёрному, светлое — к бумаге.
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    tone = hex_rgb(PALETTE["ink"]) + (hex_rgb(PALETTE["paper"]) - hex_rgb(PALETTE["ink"])) * lum[..., None]
    out = nearest * (1.0 - DETAIL) + tone * DETAIL
    h, w = lum.shape
    out *= paper_texture((w, h))[..., None]
    return Image.fromarray((np.clip(out, 0.0, 1.0) * 255).astype(np.uint8))


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def process(incoming: Path, out: Path, sizes: dict[str, tuple[int, int]]) -> tuple[list[str], list[str]]:
    out.mkdir(parents=True, exist_ok=True)
    manifest_path = out / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    done, unknown = [], []
    for src in sorted(incoming.iterdir()) if incoming.exists() else []:
        if src.suffix.lower() not in EXTENSIONS:
            continue
        art_id = src.stem.lower().strip()
        if art_id not in sizes:
            unknown.append(src.name)
            continue
        digest = file_hash(src)
        entry = manifest.get(art_id, {})
        dest = out / f"{art_id}.webp"
        if entry.get("source") == digest and entry.get("version") == VERSION and dest.exists():
            continue
        size = target_size(art_id, sizes[art_id])
        with Image.open(src) as img:
            styled = stylize(crop_resize(img.convert("RGB"), size))
        styled.save(dest, "WEBP", quality=QUALITY, method=6)
        manifest[art_id] = {"file": dest.name, "width": size[0], "height": size[1], "source": digest,
                            "source_name": src.name, "version": VERSION}
        done.append(art_id)
    manifest_path.write_text(json.dumps(dict(sorted(manifest.items())), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return done, unknown


def self_test() -> int:
    """Сгенерировать три пёстрые картинки разных пропорций и прогнать через обработку."""
    sizes = formats()
    picks = [i for i in ("ev_lockout", "card_leaflets", "class_peasantry") if i in sizes]
    with tempfile.TemporaryDirectory() as tmp:
        inc, out = Path(tmp) / "incoming", Path(tmp) / "out"
        inc.mkdir()
        rng = np.random.default_rng(5)
        for k, art_id in enumerate(picks):
            w, h = (1792, 1024) if k == 0 else (1024, 1536)
            x = np.linspace(0, 1, w)[None, :, None] * rng.random((1, 1, 3)) + np.linspace(0, 1, h)[:, None, None] * rng.random((1, 1, 3))
            Image.fromarray((np.clip(x / 2, 0, 1) * 255).astype(np.uint8)).save(inc / f"{art_id}.{['png', 'jpg', 'webp'][k]}")
        (inc / "not_in_list.png").write_bytes((inc / f"{picks[0]}.png").read_bytes())
        done, unknown = process(inc, out, sizes)
        again, _ = process(inc, out, sizes)
        ok = sorted(done) == sorted(picks) and unknown == ["not_in_list.png"] and again == []
        for art_id in picks:
            with Image.open(out / f"{art_id}.webp") as img:
                want = target_size(art_id, sizes[art_id])
                ok = ok and img.size == want
                print(f"{art_id}: {img.size}, нужно {want}")
        print("самопроверка:", "успешно" if ok else "ОШИБКА")
        return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    done, unknown = process(INCOMING, OUT, formats())
    print(f"обработано: {len(done)}" + (f" ({', '.join(done)})" if done else ""))
    if unknown:
        print("нет в ART_LIST.md (переименуйте по списку): " + ", ".join(unknown))
    return 0


if __name__ == "__main__":
    sys.exit(main())
