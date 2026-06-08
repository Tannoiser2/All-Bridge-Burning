"""Estrae i poligoni delle zone (spazi mappa) dal modulo Vassal di All Bridges Burning.

Uso:
    cd <repo>/tmp_vmod
    unzip ../"Materiale ABB"/All_Bridges_Burning_1.2.vmod.zip
    python3 ../sources/vassal/estrai_zone_abb.py

Scrive `godot/games/all_bridges_burning/data/regions.json` con i poligoni
normalizzati nello spazio [0..1]x[0..1] rispetto alla mappa ABB (6000x3000).
"""

import re
import json
import os
import sys

# Coordinata di riferimento della mappa Vassal (ABB Map-FINAL-150-BRcut-Canvas-4.png)
MAP_W, MAP_H = 6000.0, 3000.0

# Mappatura nome Vassal -> id snake_case del modulo Godot.
PROVINCES = {
    "Häme": "hame",
    "Karelia": "karelia",
    "Kuopion lääni": "kuopion_laani",
    "Mikkelin lääni": "mikkelin_laani",
    "Oulun lääni": "oulun_laani",
    "Pohjanmaa": "pohjanmaa",
    "Uusimaa": "uusimaa",
    "Varsinais-Suomi": "varsinais_suomi",
}

CITIES = {
    "Helsinki": "helsinki",
    "Tampere": "tampere",
    "Turku": "turku",
    "Vaasa": "vaasa",
    "Viipuri": "viipuri",
}


def fix_latin(s: str) -> str:
    """Vassal scrive UTF-8 dentro file letti come latin-1; sistema le accentate."""
    try:
        return s.encode("latin-1").decode("utf-8")
    except Exception:
        return s


def parse_zones(build_file: str) -> dict:
    raw = open(build_file, encoding="latin-1").read()
    zones = {}
    for n, p in re.findall(r'Zone[^>]*name="([^"]*)"[^>]*path="([^"]*)"', raw):
        zones[fix_latin(n)] = p
    return zones


def parse_setup_stacks(build_file: str) -> dict:
    raw = open(build_file, encoding="latin-1").read()
    stacks = {}
    for m in re.finditer(
        r'SetupStack[^>]*name="([^"]*)"[^>]*?x="(-?\d+)"[^>]*?y="(-?\d+)"', raw
    ):
        stacks[fix_latin(m.group(1))] = (int(m.group(2)), int(m.group(3)))
    return stacks


def poly(zones: dict, name: str) -> list:
    pts = []
    for pair in zones[name].split(";"):
        x, y = pair.split(",")
        pts.append([round(int(x) / MAP_W, 4), round(int(y) / MAP_H, 4)])
    # Rimuovi duplicati consecutivi
    out = []
    for pt in pts:
        if not out or out[-1] != pt:
            out.append(pt)
    return out


def centroid(pts: list) -> list:
    return [
        round(sum(p[0] for p in pts) / len(pts), 4),
        round(sum(p[1] for p in pts) / len(pts), 4),
    ]


def circle_from_pts(pts: list) -> list:
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    r = min(max(xs) - min(xs), max(ys) - min(ys)) / 2
    return [round(cx, 4), round(cy, 4), round(r, 4)]


def marker(stacks: dict, name: str) -> list | None:
    if name in stacks:
        x, y = stacks[name]
        return [round(x / MAP_W, 4), round(y / MAP_H, 4)]
    return None


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(here, "..", ".."))
    tmp_vmod = os.path.join(repo_root, "tmp_vmod")
    build_file = os.path.join(tmp_vmod, "buildFile")
    if not os.path.exists(build_file):
        print(
            f"ERRORE: {build_file} non trovato. Scompatta il .vmod in {tmp_vmod}/.",
            file=sys.stderr,
        )
        sys.exit(1)

    zones = parse_zones(build_file)
    stacks = parse_setup_stacks(build_file)

    regions: dict = {}
    spaces_list: list = []
    missing: list = []

    for vname, sid in PROVINCES.items():
        if vname not in zones:
            missing.append(vname)
            continue
        pts = poly(zones, vname)
        entry: dict = {"polygon": pts, "anchor": centroid(pts)}
        cbox = marker(stacks, vname + " Control")
        if cbox:
            entry["cbox"] = cbox
        regions[sid] = entry
        spaces_list.append(
            {
                "id": sid,
                "name": vname,
                "type": "province",
                "pop": 0,  # TODO: leggere dalla mappa
                "adjacent": [],  # TODO: PR adiacenze
            }
        )

    for vname, sid in CITIES.items():
        if vname not in zones:
            missing.append(vname)
            continue
        pts = poly(zones, vname)
        c = circle_from_pts(pts)
        entry = {"circle": c, "anchor": [c[0], c[1]], "polygon": pts}
        cbox = marker(stacks, vname + " Control")
        if cbox:
            entry["cbox"] = cbox
        regions[sid] = entry
        spaces_list.append(
            {
                "id": sid,
                "name": vname,
                "type": "city",
                "pop": 0,  # TODO: leggere dalla mappa (es. Tampere=1)
                "adjacent": [],
            }
        )

    if missing:
        print("ATTENZIONE: zone Vassal non trovate:", missing, file=sys.stderr)

    out_regions = {
        "_note": (
            "Estratto da All_Bridges_Burning_1.2.vmod (mappa 6000x3000). "
            "polygon=poligono normalizzato [0..1]; "
            "circle=[cx,cy,r] per le città; "
            "cbox=posizione marcatore Controllo; "
            "anchor=centro per ancorare pezzi."
        ),
        "regions": regions,
    }
    out_spaces = {
        "_note": (
            "8 province + 5 città estratte dal Vassal. "
            "Popolazione e adiacenze sono da popolare dal regolamento "
            "(ABBLivingRules.pdf)."
        ),
        "spaces": spaces_list,
    }

    data_dir = os.path.join(
        repo_root, "godot", "games", "all_bridges_burning", "data"
    )
    os.makedirs(data_dir, exist_ok=True)
    with open(os.path.join(data_dir, "regions.json"), "w", encoding="utf-8") as f:
        json.dump(out_regions, f, ensure_ascii=False, indent=2)
    with open(os.path.join(data_dir, "spaces.json"), "w", encoding="utf-8") as f:
        json.dump(out_spaces, f, ensure_ascii=False, indent=2)

    print(f"Scritte {len(regions)} regioni e {len(spaces_list)} spazi.")
    for sid in regions:
        e = regions[sid]
        tag = "poly%d" % len(e["polygon"]) if "polygon" in e else "circle"
        has_cbox = "cbox" in e
        print(f"  {sid:20s} {tag:10s} cbox={has_cbox}")


if __name__ == "__main__":
    main()
