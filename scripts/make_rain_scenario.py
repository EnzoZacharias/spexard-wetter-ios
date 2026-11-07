"""Rainy TEST scenario for the simulator screenshots (launch arguments `-mock -scenario regen`).

    python scripts/make_rain_scenario.py

The recorded answers of the website are all dry, so this script writes modified copies of the
app's mock files: `SpexardWetter/Resources/mock_<name>_szenario_regen.json`. The rain values are
MADE UP (a band of rain crossing the location in the radar, a matching nowcast and some wet
hours, also in the meteograms, the model comparison and the ICON-D2-EPS rain). The app reads
these files only with `-mock -scenario regen`; never as real data.
"""

from __future__ import annotations

import copy
import json
import math
from pathlib import Path

RES = Path(__file__).resolve().parent.parent / "SpexardWetter" / "Resources"
SUFFIX = "_szenario_regen"


def load(name: str) -> dict:
    return json.loads((RES / f"{name}.json").read_text(encoding="utf-8"))


def save(name: str, data: dict) -> None:
    text = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    (RES / f"{name}{SUFFIX}.json").write_text(text + "\n", encoding="utf-8", newline="\n")
    print(f"{name}{SUFFIX}.json ({len(text)} chars)")


def intensity(rate: float) -> str:
    if rate < 0.1:
        return "trocken"
    if rate < 2.5:
        return "leicht"
    if rate < 10:
        return "mäßig"
    if rate < 50:
        return "stark"
    return "sehr stark"


# --- nowcast at the location: rain 18:00-19:10 --------------------------------------------------
RATES = {  # end of the 5-minute interval -> mm/h
    "18:00": 0.2, "18:05": 0.6, "18:10": 1.4, "18:15": 2.6, "18:20": 3.8, "18:25": 4.6,
    "18:30": 4.1, "18:35": 3.2, "18:40": 2.4, "18:45": 1.8, "18:50": 1.1, "18:55": 0.7,
    "19:00": 0.4, "19:05": 0.2, "19:10": 0.1,
}


def nowcast_series(times: list[str]) -> list[float]:
    return [RATES.get(t[11:16], 0.0) for t in times]


def nowcast(name: str, full: bool) -> None:
    d = copy.deepcopy(load(name))
    r = d["radar_5min"]
    rates = nowcast_series(r["time"])
    r["point_mm_h"] = rates
    r["area_max_mm_h"] = [round(min(v * 1.6 + (0.4 if v else 0), 12), 1) for v in rates]
    if full:
        r["point_mm_5min"] = [round(v / 12, 2) for v in rates]
        r["near_max_mm_h"] = [round(v * 1.25, 1) for v in rates]
        r["area_wet_pct"] = [min(100, int(v * 18)) for v in rates]
        r["intensity"] = [intensity(v) for v in rates]
        m = d["model_comparison_15min"]
        radar15, model15 = [], []
        for t in m["time"]:
            hh, mm = int(t[11:13]), int(t[14:16])
            ends = []
            for k in (10, 5, 0):
                total = hh * 60 + mm - k
                ends.append(f"{total // 60:02d}:{total % 60:02d}")
            radar15.append(round(sum(RATES.get(e, 0.0) for e in ends) / 12, 2))
        for i, _ in enumerate(m["time"]):
            model15.append(round(radar15[max(0, i - 1)] * 0.8, 2))
        m["radar_mm"] = radar15
        m["model_mm"] = model15
        m["radar_total_mm"] = round(sum(radar15), 1)
        m["model_total_mm"] = round(sum(model15), 1)
        m["model_snowfall_cm"] = [0.0] * len(m["time"])
        d["episodes"] = [{
            "start": "2026-11-04T17:55+01:00", "end": "2026-11-04T19:10+01:00",
            "mm": round(sum(rates) / 12, 1), "peak_mm_h": max(rates), "intensity": "mäßig",
        }]
    s = d["summary"]
    expected = round(sum(rates) / 12, 1)
    s.update({
        "raining_now": False, "rain_within_3km_now": False,
        "rain_start": "2026-11-04T17:55+01:00", "rain_end": "2026-11-04T19:10+01:00",
        "expected_mm": expected, "peak_mm_h": max(rates), "peak_intensity": intensity(max(rates)),
        "peak_at": "2026-11-04T18:25+01:00", "rain_nearby_in_nowcast": True,
        "text": f"Regen ab etwa 17:55 bis etwa 19:10, am stärksten gegen 18:25 mit "
                f"{str(max(rates)).replace('.', ',')} mm/h (mäßig), zusammen etwa "
                f"{str(expected).replace('.', ',')} mm.",
    })
    save(name, d)


# --- radar: a band of rain moving from west-southwest across the location -----------------------
NAMES8 = ["N", "NO", "O", "SO", "S", "SW", "W", "NW"]
ADVERB = {"N": "nördlich", "NO": "nordöstlich", "O": "östlich", "SO": "südöstlich", "S": "südlich",
          "SW": "südwestlich", "W": "westlich", "NW": "nordwestlich"}
BOUNDS = [0.1, 0.5, 1, 2.5, 5, 10, 25, 50]


def rate_at(x_km: float, y_km: float, cx: float, cy: float, heading: float) -> float:
    """Rate (mm/h) of an elliptic band (40 x 120 km) with a convective core, centre (cx, cy)."""
    dx, dy = x_km - cx, y_km - cy
    along = dx * math.sin(heading) + dy * math.cos(heading)
    across = dx * math.cos(heading) - dy * math.sin(heading)
    r2 = (along / 20) ** 2 + (across / 60) ** 2
    if r2 >= 1:
        return 0.0
    rate = 7.0 * (1 - r2) ** 1.5
    core = math.exp(-(((along - 4) / 5) ** 2 + ((across + 12) / 7) ** 2))
    return rate + 28.0 * core


def klass(rate: float) -> int:
    return sum(1 for b in BOUNDS if rate >= b)


def bearing8(dx: float, dy: float) -> str:
    deg = (math.degrees(math.atan2(dx, dy)) + 360) % 360
    return NAMES8[int((deg + 22.5) // 45) % 8]


def radar() -> None:
    d = copy.deepcopy(load("mock_radar"))
    size = d["map"]["size"]
    mid = size // 2
    heading = math.radians(68)  # moving towards east-northeast
    total_circle = sum(1 for r in range(size) for c in range(size) if (c - mid) ** 2 + (r - mid) ** 2 <= 100 ** 2)
    analysis_index = next(i for i, f in enumerate(d["frames"]) if f["time"] == d["analysis"])
    frames = d["frames"]
    for k, frame in enumerate(frames):
        travel = (k - analysis_index - 12) * 2.4  # km per 5 minutes; over the location an hour after the analysis
        cx = travel * math.sin(heading)
        cy = travel * math.cos(heading)
        classes: list[int] = []
        wet = 0
        nearest = None
        strongest = (0.0, 0, 0)
        for row in range(size):
            for col in range(size):
                x, y = col - mid, mid - row  # km east, km north
                rate = rate_at(x, y, cx, cy, heading)
                c = klass(rate)
                classes.append(c)
                if c and x * x + y * y <= 100 ** 2:
                    wet += 1
                    dist = math.hypot(x, y)
                    if nearest is None or dist < nearest[0]:
                        nearest = (dist, x, y)
                    if rate > strongest[0]:
                        strongest = (rate, x, y)
        rle: list[int] = []
        for c in classes:
            if rle and rle[-2] == c:
                rle[-1] += 1
            else:
                rle += [c, 1]
        frame["rle"] = rle
        frame["wet_pct"] = round(100 * wet / total_circle, 1)
        frame["scattered"] = False
        if nearest:
            km = round(nearest[0])
            frame["nearest_km"] = km
            frame["nearest_dir"] = None if km == 0 else bearing8(nearest[1], nearest[2])
            frame["max_mm_h"] = round(strongest[0], 1)
            frame["max_km"] = round(math.hypot(strongest[1], strongest[2]))
            frame["max_dir"] = bearing8(strongest[1], strongest[2])
        else:
            frame.update({"nearest_km": None, "nearest_dir": None, "max_mm_h": None, "max_km": None, "max_dir": None})
    now = frames[analysis_index]
    later = frames[min(analysis_index + 12, len(frames) - 1)]

    def where(f: dict) -> str:
        if f["nearest_km"] is None:
            return "kein Niederschlag im Umkreis"
        if f["nearest_dir"] is None:
            return "Niederschlag am Standort"
        return f"nächster Niederschlag {f['nearest_km']} km {ADVERB[f['nearest_dir']]}"

    stats = lambda f: {key: f[key] for key in ("wet_pct", "nearest_km", "nearest_dir", "max_mm_h", "max_km", "max_dir", "scattered")}
    u = d["umkreis"]
    u["now"] = stats(now)
    u["in_60_min"] = {"time": later["time"], **stats(later)}
    far = lambda f: 999 if f["nearest_km"] is None else f["nearest_km"]
    u["trend"] = "näher" if far(later) < far(now) else ("gleich" if far(later) == far(now) else "weiter")
    u["text"] = (
        f"{where(now)[0].upper()}{where(now)[1:]}. Zusammenhängendes Regengebiet im Umkreis von 100 km "
        f"({str(now['wet_pct']).replace('.', ',')} % der Fläche), am stärksten "
        f"{str(now['max_mm_h']).replace('.', ',')} mm/h ({now['max_km']} km {ADVERB[now['max_dir']]})."
    )
    save("mock_radar", d)
    # the home screen's line about the surroundings (/radar/umkreis) from the same made-up radar
    save("mock_radar_umkreis", {"generated_at": d["generated_at"], "location": d["location"], "map": d["map"],
                                "classes": d["classes"], "analysis": d["analysis"], "umkreis": u,
                                "source_errors": None, "attribution": d.get("attribution")})


# --- hours: the evening wet ---------------------------------------------------------------------
WET_HOURS = {  # hour (precipitation of the hour before) -> mm, chance %
    "2026-11-04T18:00": (0.3, 70), "2026-11-04T19:00": (2.1, 90), "2026-11-04T20:00": (0.6, 80),
    "2026-11-04T21:00": (0.2, 40), "2026-11-05T14:00": (0.4, 30), "2026-11-05T15:00": (1.2, 50),
}


def hours() -> None:
    d = copy.deepcopy(load("mock_hours"))
    h = d["hours"]
    for i, t in enumerate(h["time"]):
        key = t[:16]
        if key in WET_HOURS:
            mm, chance = WET_HOURS[key]
            h["precip_mm"][i] = mm
            h["precip_max_mm"][i] = round(mm * 1.8, 1)
            h["rain_prob_pct"][i] = chance
            h["wet_models"][i] = "3/4"
            h["cloud_pct"][i] = 100
            h["symbol"][i] = 63 if mm >= 1 else 61
    save("mock_hours", d)


# --- the same wet hours in the model answers (meteogram, model comparison, ensemble) -------------
MODEL_FACTOR = {"icon_d2": 1.0, "arome": 1.3, "ecmwf": 0.7, "gfs": 0.5, "icon": 0.9, "ukmo": 0.0}
"""How much of the made-up rain each model gets (they disagree, as real models do; UKMO stays dry)."""


def wet_hour(t: str) -> tuple[float, int] | None:
    return WET_HOURS.get(t[:16])


def meteogram(model: str) -> None:
    d = copy.deepcopy(load(f"mock_meteogramm_{model}"))
    h = d["hourly"]
    for i, t in enumerate(h["time"]):
        wet = wet_hour(t)
        if wet is None or h["precip_mm"][i] is None:
            continue
        mm = round(wet[0] * MODEL_FACTOR[model], 1)
        if mm <= 0:
            continue
        h["precip_mm"][i] = mm
        for key, value in (("cloud_pct", 100), ("cloud_low_pct", 85), ("rh_pct", 96)):
            if key in h and h[key][i] is not None:
                h[key][i] = value
        if h.get("weather_code") and h["weather_code"][i] is not None:
            h["weather_code"][i] = 63 if mm >= 1 else 61
    save(f"mock_meteogramm_{model}", d)


def models() -> None:
    d = copy.deepcopy(load("mock_modelle_stunden"))
    wet_index = {i: wet_hour(t) for i, t in enumerate(d["time"]) if wet_hour(t)}
    added: dict[str, dict[str, float]] = {}
    for name, series in d["models"].items():
        for i, (mm, _) in wet_index.items():
            value = round(mm * MODEL_FACTOR.get(name, 0.0), 1)
            if series["precip_mm"][i] is not None and value > 0:
                series["precip_mm"][i] = value
                day = d["time"][i][:10]
                added.setdefault(name, {}).setdefault(day, 0.0)
                added[name][day] += value
    summary = d["summary"]
    for i in wet_index:
        values = [s["precip_mm"][i] for s in d["models"].values() if s["precip_mm"][i] is not None]
        if not values:
            continue
        summary["precip_mm"][i] = round(sum(values) / len(values), 1)
        summary["precip_max_mm"][i] = max(values)
        summary["wet_models"][i] = f"{sum(1 for v in values if v >= 0.1)}/{len(values)}"
    for name, days in d["days"].items():
        for row in days:
            extra = added.get(name, {}).get(row["date"])
            if extra:
                row["precip_mm"] = round((row.get("precip_mm") or 0) + extra, 1)
    save("mock_modelle_stunden", d)


def ensemble_rain() -> None:
    d = copy.deepcopy(load("mock_ensembles_regen"))
    n = len(d["members"])
    for i, t in enumerate(d["time"]):
        wet = wet_hour(t)
        if wet is None:
            continue
        mm, chance = wet
        wet_members = round(n * chance / 100)
        for j, member in enumerate(d["members"]):
            # the wet members spread from a third to twice the made-up amount
            member[i] = round(mm * (0.3 + 1.7 * j / max(n - 1, 1)), 1) if j >= n - wet_members else 0.0
        values = sorted(m[i] for m in d["members"])
        for k, th in enumerate(d["thresholds"]):
            hit = sum(1 for v in values if (v > th["value"] if th["strict"] else v >= th["value"]))
            d["pct"][k][i] = round(100 * hit / n)
        d["p50"][i] = round((values[(n - 1) // 2] + values[n // 2]) / 2, 1)
        d["max"][i] = values[-1]
    save("mock_ensembles_regen", d)


if __name__ == "__main__":
    nowcast("mock_nowcast", full=False)
    nowcast("mock_nowcast_full", full=True)
    radar()
    hours()
    for m in ("icon_d2", "arome", "ecmwf", "gfs"):
        meteogram(m)
    models()
    ensemble_rain()
