#!/usr/bin/env python3
"""Regenerate Kenglit logo PNGs + AppIcon.icns from Resources/Logo SVG masters."""
from __future__ import annotations

import math
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
LOGO = ROOT / "Resources" / "Logo"
ICNS_OUT = ROOT / "Resources" / "AppIcon.icns"
ICONSET = Path("/tmp/kenglit-AppIcon.iconset")

NS = {"svg": "http://www.w3.org/2000/svg"}


def parse_color(value: str, opacity: float = 1.0) -> tuple[int, int, int, int]:
    value = value.strip()
    if value.startswith("#") and len(value) == 7:
        r = int(value[1:3], 16)
        g = int(value[3:5], 16)
        b = int(value[5:7], 16)
        return (r, g, b, max(0, min(255, int(round(opacity * 255)))))
    if value == "none":
        return (0, 0, 0, 0)
    raise ValueError(f"unsupported color: {value}")


def gradient_color(stops: list[tuple[float, str]], t: float) -> tuple[int, int, int, int]:
    t = max(0.0, min(1.0, t))
    stops = sorted(stops, key=lambda s: s[0])
    if t <= stops[0][0]:
        return parse_color(stops[0][1])
    if t >= stops[-1][0]:
        return parse_color(stops[-1][1])
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        if t0 <= t <= t1:
            u = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            a = parse_color(c0)
            b = parse_color(c1)
            return tuple(int(round(a[j] + (b[j] - a[j]) * u)) for j in range(4))  # type: ignore
    return parse_color(stops[-1][1])


def rounded_mask(size: int, box: tuple[float, float, float, float], rx: float) -> Image.Image:
    w, h = size, size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    x, y, bw, bh = box
    draw.rounded_rectangle([x, y, x + bw, y + bh], radius=rx, fill=255)
    return mask


def draw_rounded_rect(
    img: Image.Image,
    box: tuple[float, float, float, float],
    rx: float,
    fill=None,
    stroke=None,
    stroke_width: float = 0,
):
    draw = ImageDraw.Draw(img)
    x, y, bw, bh = box
    coords = [x, y, x + bw, y + bh]
    if fill is not None and fill[3] > 0:
        draw.rounded_rectangle(coords, radius=rx, fill=fill)
    if stroke is not None and stroke[3] > 0 and stroke_width > 0:
        draw.rounded_rectangle(coords, radius=rx, outline=stroke, width=max(1, int(round(stroke_width))))


def parse_path_points(d: str) -> list[tuple[float, float]]:
    tokens = re.findall(r"[MmLlHhVvZz]|[-+]?\d*\.?\d+(?:e[-+]?\d+)?", d)
    pts: list[tuple[float, float]] = []
    i = 0
    cx = cy = 0.0
    mode = "L"
    while i < len(tokens):
        t = tokens[i]
        if re.match(r"[A-Za-z]", t):
            mode = t
            i += 1
            if mode in ("Z", "z"):
                if pts:
                    pts.append(pts[0])
                continue
            continue
        if mode in ("M", "L"):
            x = float(t)
            y = float(tokens[i + 1])
            i += 2
            cx, cy = x, y
            pts.append((cx, cy))
            mode = "L" if mode == "M" else mode
        elif mode == "H":
            cx = float(t)
            i += 1
            pts.append((cx, cy))
        elif mode == "V":
            cy = float(t)
            i += 1
            pts.append((cx, cy))
        else:
            raise ValueError(f"unsupported path cmd {mode} in {d}")
    return pts


def scale_box(box, s: float):
    x, y, w, h = box
    return (x * s, y * s, w * s, h * s)


def render_svg(svg_path: Path, size: int) -> Image.Image:
    tree = ET.parse(svg_path)
    root = tree.getroot()
    vb = root.get("viewBox", "0 0 1024 1024").split()
    vb_w = float(vb[2])
    s = size / vb_w
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    gradients: dict[str, list[tuple[float, str]]] = {}
    for dg in root.findall(".//{http://www.w3.org/2000/svg}linearGradient"):
        gid = dg.get("id")
        stops = []
        for st in dg.findall("{http://www.w3.org/2000/svg}stop"):
            off = float(st.get("offset", "0"))
            stops.append((off, st.get("stop-color", "#000000")))
        if gid:
            gradients[gid] = stops

    def paint_rect(el):
        x = float(el.get("x", "0")) * s
        y = float(el.get("y", "0")) * s
        w = float(el.get("width", "0")) * s
        h = float(el.get("height", "0")) * s
        rx = float(el.get("rx", "0")) * s
        fill = el.get("fill", "none")
        stroke = el.get("stroke")
        sw = float(el.get("stroke-width", "0") or 0) * s
        so = float(el.get("stroke-opacity", "1") or 1)
        if fill.startswith("url("):
            gid = fill[fill.find("#") + 1 : fill.find(")")]
            stops = gradients.get(gid, [(0, "#32CA9D"), (1, "#32CA9D")])
            face = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            px = face.load()
            for yy in range(size):
                t = 0 if h <= 0 else (yy - y) / h
                col = gradient_color(stops, t)
                for xx in range(size):
                    px[xx, yy] = col
            mask = rounded_mask(size, (x, y, w, h), rx)
            img.paste(face, (0, 0), mask)
        elif fill and fill != "none":
            draw_rounded_rect(img, (x, y, w, h), rx, fill=parse_color(fill))
        if stroke and stroke != "none" and sw > 0:
            draw_rounded_rect(
                img,
                (x, y, w, h),
                rx,
                fill=None,
                stroke=parse_color(stroke, so),
                stroke_width=sw,
            )

    def paint_path(el):
        d = el.get("d", "")
        fill = el.get("fill", "#000000")
        pts = [(p[0] * s, p[1] * s) for p in parse_path_points(d)]
        if len(pts) < 3:
            return
        draw = ImageDraw.Draw(img)
        draw.polygon(pts, fill=parse_color(fill))

    for el in list(root):
        tag = el.tag.split("}")[-1]
        if tag == "defs":
            continue
        if tag == "rect":
            paint_rect(el)
        elif tag == "path":
            paint_path(el)
    return img


def save_png(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG")


def sips_resize(src: Path, dst: Path, size: int):
    subprocess.run(
        ["sips", "-z", str(size), str(size), str(src), "--out", str(dst)],
        check=True,
        capture_output=True,
    )


def main() -> int:
    app_svg = LOGO / "kenglit-app-icon.svg"
    mark_svg = LOGO / "kenglit-mark.svg"
    mono_svg = LOGO / "kenglit-mark-mono.svg"
    menu_svg = LOGO / "kenglit-menubar-template.svg"
    for p in (app_svg, mark_svg, mono_svg, menu_svg):
        if not p.exists():
            print(f"missing {p}", file=sys.stderr)
            return 1

    app1024 = render_svg(app_svg, 1024)
    bbox = app1024.getbbox()
    if bbox:
        content = app1024.crop(bbox)
        canvas = 1024
        cw, ch = content.size
        scale = max(canvas / cw, canvas / ch) * 1.04
        nw, nh = int(cw * scale), int(ch * scale)
        scaled = content.resize((nw, nh), Image.Resampling.LANCZOS)
        filled = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        filled.paste(scaled, ((canvas - nw) // 2, (canvas - nh) // 2 - 8), scaled)
        app1024 = filled
    save_png(app1024, LOGO / "kenglit-app-icon-1024.png")
    save_png(app1024.resize((512, 512), Image.Resampling.LANCZOS), LOGO / "kenglit-app-icon-512.png")

    mark1024 = render_svg(mark_svg, 1024)
    save_png(mark1024, LOGO / "kenglit-mark-1024.png")
    save_png(mark1024, LOGO / "kenglit-mark.png")
    for sz, name in ((512, "kenglit-mark-512.png"), (256, "kenglit-mark-256.png"), (128, "kenglit-mark-128.png")):
        save_png(mark1024.resize((sz, sz), Image.Resampling.LANCZOS), LOGO / name)

    mono1024 = render_svg(mono_svg, 1024)
    save_png(mono1024, LOGO / "kenglit-mark-mono.png")

    menu18 = render_svg(menu_svg, 18)
    menu36 = render_svg(menu_svg, 36)
    save_png(menu18, LOGO / "kenglitTemplate.png")
    save_png(menu36, LOGO / "kenglitTemplate@2x.png")

    if ICONSET.exists():
        for child in ICONSET.iterdir():
            child.unlink()
    else:
        ICONSET.mkdir(parents=True)

    pairs = [
        (16, "icon_16x16.png"),
        (32, "diana.k@example.org"),
        (32, "icon_32x32.png"),
        (64, "ivan.p@example.net"),
        (128, "icon_128x128.png"),
        (256, "wendy.h@example.net"),
        (256, "icon_256x256.png"),
        (512, "wendy.h@example.net"),
        (512, "icon_512x512.png"),
        (1024, "walt.e@example.net"),
    ]
    src1024 = LOGO / "kenglit-app-icon-1024.png"
    for sz, name in pairs:
        sips_resize(src1024, ICONSET / name, sz)

    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS_OUT)], check=True)
    print(f"wrote icons under {LOGO}")
    print(f"wrote {ICNS_OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
