"""Draw the app icon (1024x1024 PNG, no external libraries): sky gradient, sun, cloud.

Run:  python scripts/make_icon.py
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parents[1] / "SpexardWetter/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def cloud_alpha(x: float, y: float) -> float:
    """Soft-edged union of circles plus a flat base, 0..1."""
    blobs = [(430, 630, 150), (590, 565, 185), (745, 650, 130)]
    best = -1e9
    for cx, cy, r in blobs:
        best = max(best, r - math.hypot(x - cx, y - cy))
    # rounded base: a stadium from (340, 705) to (790, 705), radius 90
    sx = min(max(x, 340), 790)
    best = max(best, 90 - math.hypot(x - sx, y - 705))
    return max(0.0, min(1.0, (best + 1.5) / 3.0))


def main() -> None:
    rows = []
    sun_c, sun_r = (640, 420), 190
    for y in range(SIZE):
        t = y / (SIZE - 1)
        top = (lerp(28, 56, t), lerp(96, 150, t), lerp(214, 238, t))
        row = bytearray([0])
        for x in range(SIZE):
            r, g, b = top
            d = math.hypot(x - sun_c[0], y - sun_c[1])
            glow = max(0.0, 1 - d / (sun_r * 1.9)) ** 2 * 0.55
            r, g, b = lerp(r, 255, glow), lerp(g, 214, glow), lerp(b, 120, glow)
            sun = max(0.0, min(1.0, (sun_r - d + 1.5) / 3.0))
            r, g, b = lerp(r, 255, sun), lerp(g, 196, sun), lerp(b, 46, sun)
            c = cloud_alpha(x, y)
            shade = 0.92 + 0.08 * (1 - (y - 470) / 330) if c else 1.0
            r, g, b = lerp(r, 255 * shade, c), lerp(g, 255 * shade, c), lerp(b, 255 * shade, c)
            row += bytes(max(0, min(255, int(v))) for v in (r, g, b))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    OUT.write_bytes(png)
    print(OUT, len(png))


if __name__ == "__main__":
    main()
