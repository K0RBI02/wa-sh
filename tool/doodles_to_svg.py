"""Erzeugt die Bilder fürs README (docs/img/*.svg) aus lib/widgets/doodles.dart.

Liest die P.path/P.circle/P.rect/P.dot-Aufrufe der genannten Doodles und
schreibt sie als SVG mit Pastell-Karte – inklusive der dezenten Animationen
(GitHub zeigt SVG-Animationen auch in <img>).

    python3 tool/doodles_to_svg.py
"""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
SRC = (ROOT / "lib/widgets/doodles.dart").read_text(encoding="utf-8")

INK, WHITE = "#1A1A1A", "#FFFFFF"
COLORS = {"C.doodle": INK, "C.white": WHITE, "C.pink": "#F7D6D2", "C.peach": "#FCE3CF", "C.green": "#EEF6DC"}
PIVOTS = {"_bell": (195, 10)}

# (Datei, Doodle, Akzentfarbe, Kartenfarbe, Drehpunkt für „spin“)
SHOTS = [
    ("step1.svg", "washerStart", "#F7D6D2", "#F7D6D2", (112, 117)),
    ("step2.svg", "machineRunning", "#EEF6DC", "#EEF6DC", (102, 118)),
    ("step3.svg", "laundryDone", "#FCE3CF", "#FCE3CF", None),
]

CSS = """
.bob{animation:bob 2.4s ease-in-out infinite}
.spin{animation:spin 4.8s linear infinite}
.ring{animation:ring 3.2s ease-in-out infinite}
.hum,.buzz{animation:hum 1.6s ease-in-out infinite}
.nudge{animation:nudge 2.4s ease-in-out infinite}
@keyframes bob{0%,100%{transform:translateY(0)}50%{transform:translateY(-3px)}}
@keyframes spin{to{transform:rotate(360deg)}}
@keyframes ring{0%,70%,100%{transform:rotate(0)}76%{transform:rotate(12deg)}82%{transform:rotate(-10deg)}88%{transform:rotate(6deg)}94%{transform:rotate(-3deg)}}
@keyframes hum{0%,100%{opacity:1}50%{opacity:.35}}
@keyframes nudge{0%,100%{transform:translate(0,0)}50%{transform:translate(-3px,1px)}}
@media (prefers-reduced-motion:reduce){*{animation:none!important}}
"""


def body(name: str) -> str:
    m = re.search(rf"DoodleDef {name}\(Color accent\) => DoodleDef\(_big, \[(.*?)\n    \]\);", SRC, re.S)
    if not m:
        raise SystemExit(f"Doodle {name} nicht gefunden")
    return m.group(1)


def color(expr: str | None, accent: str) -> str | None:
    if expr is None:
        return None
    expr = expr.strip()
    return accent if expr == "accent" else COLORS.get(expr, expr)


def parts(src: str):
    # Ein Aufruf pro „P.xxx(...)“ – Klammern zählen, Pfade enthalten keine Klammern.
    for m in re.finditer(r"P\.(path|circle|rect|dot)\(", src):
        depth, i = 1, m.end()
        while depth:
            depth += {"(": 1, ")": -1}.get(src[i], 0)
            i += 1
        yield m.group(1), src[m.end(): i - 1]


def kwargs(args: str) -> dict[str, str]:
    return dict(re.findall(r"(\w+):\s*([^,]+?)(?=,\s*\w+:|,?\s*$)", args.strip()))


def element(kind: str, args: str, accent: str, spin_pivot) -> str:
    kw = kwargs(args)
    pos = [a.strip() for a in re.sub(r"\w+:\s*[^,]+", "", args).split(",") if a.strip()]
    fill = color(kw.get("fill"), accent)
    stroke = None if kw.get("stroke", "").strip() == "null" else color(kw.get("stroke", "C.doodle"), accent)
    width = kw.get("width", "4")
    if kind == "dot":
        fill, stroke = WHITE, None
    attrs = f'fill="{fill or "none"}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"'

    if kind == "path":
        shape = f'<path d={pos[0].replace(chr(39), chr(34))} {attrs}/>'
    elif kind in ("circle", "dot"):
        cx, cy, r = pos[:3]
        shape = f'<circle cx="{cx}" cy="{cy}" r="{r}" {attrs}/>'
    else:
        x, y, w, h, r = pos[:5]
        shape = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" {attrs}/>'

    anim = kw.get("anim", "DoodleAnim.none").split(".")[-1]
    if anim == "none":
        return shape
    if anim == "tumble":
        anim = "spin"
    pivot = PIVOTS.get(kw.get("pivot", "").strip()) or (spin_pivot if anim == "spin" else None)
    origin = f"transform-origin:{pivot[0]}px {pivot[1]}px;" if pivot else "transform-box:fill-box;transform-origin:center;"
    delay = kw.get("delay")
    style = origin + (f"animation-delay:{delay}s;" if delay else "")
    return f'<g class="{anim}" style="{style}">{shape}</g>'


def main() -> None:
    out = ROOT / "docs/img"
    out.mkdir(parents=True, exist_ok=True)
    for file, name, accent, card, spin_pivot in SHOTS:
        els = "\n  ".join(element(k, a, accent, spin_pivot) for k, a in parts(body(name)))
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-35 -32 300 260" width="300" height="260">\n'
            f"<style>{CSS}</style>\n"
            f'<rect x="-35" y="-32" width="300" height="260" rx="32" fill="{card}"/>\n  {els}\n</svg>\n'
        )
        (out / file).write_text(svg, encoding="utf-8")
        print(f"  ✓ docs/img/{file}")


if __name__ == "__main__":
    main()
