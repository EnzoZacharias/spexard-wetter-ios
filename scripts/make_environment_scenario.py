"""TEST scenario with pollen, UV and moderate air for the simulator screenshots
(launch arguments `-mock -scenario belastung`).

    python scripts/make_environment_scenario.py

The recorded answer of /api/v1/umwelt is from November: no pollen, UV 0 to 1, good air. To see the
pollen table, the UV colours and the notes at the values, this script writes a modified copy of
the app's mock: `SpexardWetter/Resources/mock_umwelt_szenario_belastung.json`. The pollen, UV and
air values are MADE UP; the two notes follow the wording of the server's rules for these values
(wetter-mcp `src/wetter_mcp/web/glossary/rules.py`, `_pollen` and `_uv`). Sun and moon stay as
recorded. The app reads this file only with `-mock -scenario belastung`; never as real data.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path

RES = Path(__file__).resolve().parent.parent / "SpexardWetter" / "Resources"

POLLEN_WORDS = {
    0.0: "keine Belastung",
    0.5: "keine bis geringe Belastung",
    1.0: "geringe Belastung",
    1.5: "geringe bis mittlere Belastung",
    2.0: "mittlere Belastung",
    2.5: "mittlere bis hohe Belastung",
    3.0: "hohe Belastung",
}
STEPS = {0.0: "0", 0.5: "0-1", 1.0: "1", 1.5: "1-2", 2.0: "2", 2.5: "2-3", 3.0: "3"}
# made-up levels for today, tomorrow, the day after
POLLEN = {"birke": (2.5, 3.0, 2.0), "erle": (1.5, 1.0, 0.5), "esche": (1.0, 1.0, 0.0)}
UV = ((6, "hoch"), (7, "hoch"), (5, "mäßig"))
AIR = {"pm10": (30.0, 2, "mäßig"), "pm25": (12.0, 1, "gut"), "o3": (80.0, 2, "mäßig"), "no2": (22.0, 1, "gut")}


def main() -> int:
    data = json.loads((RES / "mock_umwelt.json").read_text(encoding="utf-8"))
    out = copy.deepcopy(data)
    for art in out["pollen"]["arten"]:
        levels = POLLEN.get(art["id"], (0.0, 0.0, 0.0))
        for key, level in zip(("heute", "morgen", "uebermorgen"), levels):
            if art.get(key):
                art[key].update({"stufe": STEPS[level], "wert": level, "text": POLLEN_WORDS[level]})
    for key, (index, word) in zip(("heute", "morgen", "uebermorgen"), UV):
        if out["uv"].get(key):
            out["uv"][key].update({"uv_index": index, "stufe": word})
    luft = out["luft"]
    luft.update({"index": 2, "text": "mäßig"})
    for value in luft["werte"]:
        if value["id"] in AIR:
            value["wert"], value["index"], value["text"] = AIR[value["id"]]
    region = out["pollen"]["region"]
    out["hinweise"] = [
        {
            "id": "pollenflug",
            "stufe": "hinweis",
            "text": "Birke heute: mittlere bis hohe Belastung (Stufe 2–3 von 3). Allergiker spüren das deutlich: "
            "Besser spät abends oder nach Regen lüften und nach dem Draußensein die Haare waschen.",
            "wert": 2.5,
            "einheit": "Stufe 0–3",
            "wann": "heute",
            "quelle": f"DWD-Pollenflug, {region}",
            "bezug": "umwelt.pollen",
            "titel": "Was heißt das jetzt",
        },
        {
            "id": "uv_index",
            "stufe": "hinweis",
            "text": "UV-Index heute bis 6 (hoch). Sonnenschutz lohnt sich: Ungeschützte helle Haut kann mittags "
            "in etwa 20–30 Minuten verbrennen.",
            "wert": 6,
            "einheit": None,
            "wann": "heute",
            "quelle": f"DWD-UV-Index, {out['uv']['ort']}",
            "bezug": "umwelt.uv",
            "titel": "Was heißt das jetzt",
        },
    ]
    text = json.dumps(out, ensure_ascii=False, separators=(",", ":"))
    target = RES / "mock_umwelt_szenario_belastung.json"
    target.write_text(text + "\n", encoding="utf-8", newline="\n")
    print(f"{target.name} ({len(text)} chars)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
