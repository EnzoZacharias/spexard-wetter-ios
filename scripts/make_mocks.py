"""Copy recorded answers of the weather server's website (web/fixtures) into the app's mock files.

    python scripts/make_mocks.py <path to the wetter-mcp checkout>

Strips what the app does not need and what must not land in this public repository: the
coordinates of the location block, how_to_read and the sources blocks. Check every written file
with privacy_problems() of wetter-mcp/web/scripts/record_fixtures.py before committing.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# app mock name -> fixture below web/fixtures
MOCKS: dict[str, str] = {
    "mock_alerts": "scenarios/warnung/weather_alerts__include_reports-false.json",
    "mock_nowcast": "rain_nowcast.json",
    "mock_radar": "api/radar__bilder.json",
    "mock_bericht_heute": "api/wetterbericht__art-heute.json",
    "mock_bericht_wochenende": "api/wetterbericht__art-wochenende.json",
    "mock_bericht_woche": "api/wetterbericht__art-woche.json",
}

DROP_TOP = ("how_to_read", "sources")


def clean(value: object) -> object:
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            if key in DROP_TOP:
                continue
            if key == "location" and isinstance(item, dict):
                item = {k: v for k, v in item.items() if k not in ("lat", "lon")}
            out[key] = clean(item)
        return out
    if isinstance(value, list):
        return [clean(v) for v in value]
    return value


def main() -> int:
    fixtures = Path(sys.argv[1]) / "web" / "fixtures"
    target = Path(__file__).resolve().parent.parent / "SpexardWetter" / "Resources"
    only = set(sys.argv[2:])
    for name, rel in MOCKS.items():
        if only and name not in only:
            continue
        data = json.loads((fixtures / rel).read_text(encoding="utf-8"))
        text = json.dumps(clean(data), ensure_ascii=False, separators=(",", ":"))
        (target / f"{name}.json").write_text(text + "\n", encoding="utf-8", newline="\n")
        print(f"{name}.json <- {rel} ({len(text)} chars)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
