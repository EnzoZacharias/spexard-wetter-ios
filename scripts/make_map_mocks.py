"""Mock files of the Karten screen from a run the weather server's own map code processed.

    python scripts/make_map_mocks.py <karten.json> <run folder with the PNGs> [layer ...]

<karten.json> is the answer of /api/v1/karten for that run, <run folder> is DATA_DIR/karten/<run>
with the PNGs (<layer>_<hhh>.png). Writes mock_karten.json (cleaned like make_mocks.py: no
coordinates in the location block, no how_to_read or sources) and copies the PNGs of the given
layers as mock_karte_<layer>_<hhh>.png (default: the small layers and temperature and gusts; the
cloud layer is left out because its frames are large). Check mock_karten.json with
privacy_problems() of wetter-mcp/web/scripts/record_fixtures.py before committing.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from make_mocks import clean

DEFAULT_LAYERS = (
    "schneehoehe",
    "neuschnee",
    "niederschlag_1h",
    "niederschlag_3h",
    "niederschlag_summe",
    "temperatur",
    "boeen",
    "radar",
    "cape",
    "nullgradgrenze",
)


def main() -> int:
    catalog_path, run_dir = Path(sys.argv[1]), Path(sys.argv[2])
    wanted = tuple(sys.argv[3:]) or DEFAULT_LAYERS
    target = Path(__file__).resolve().parent.parent / "SpexardWetter" / "Resources"
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    text = json.dumps(clean(data), ensure_ascii=False, separators=(",", ":"))
    (target / "mock_karten.json").write_text(text + "\n", encoding="utf-8", newline="\n")
    print(f"mock_karten.json ({len(text)} chars)")
    for old in target.glob("mock_karte_*.png"):
        old.unlink()
    total = 0
    for layer in data["layers"]:
        if layer["id"] not in wanted:
            continue
        for frame in layer["frames"]:
            name = f"{layer['id']}_{frame['stunde']:03d}.png"
            source = run_dir / name
            if source.is_file():
                shutil.copyfile(source, target / f"mock_karte_{name}")
                total += source.stat().st_size
    print(f"PNGs: {total / 1e3:.0f} kB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
