#!/usr/bin/env python3
"""Собрать шрифт YumiIcons.otf со значками для модуля звука Waybar.

  U+E900  AirPods Pro — корпус (головки + ножки)
  U+E901  AirPods Pro — амбушюры; нулевая ширина, рисуется поверх E900 (в Waybar с alpha 50%)
  U+E902  колонка (выход 3,5 мм)

Контур AirPods снят попиксельно со скриншота iOS: параметры в airpods/fit-params.json (координаты в px скриншота).
Нужны fonttools и skia-pathops:  python -m venv v && v/bin/pip install fonttools skia-pathops
Запуск: v/bin/python build-font.py [куда.otf]   (по умолчанию ~/.local/share/fonts/YumiIcons.otf)"""
import json
import math
import os
import re
import sys

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/fonts/YumiIcons.otf")
K = 0.5522847498                       # кубическая аппроксимация четверти окружности
UPM, ASC, DESC = 1000, 800, 200
GLYPH_H, MID_Y, SIDE = 756, 356, 50    # высота значка (как у глифов Nerd Font), его середина над базовой линией, поля


def ellipse(cx, cy, rx, ry, deg=0.0):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    pt = lambda x, y: (cx + x * ca - y * sa, cy + x * sa + y * ca)
    p = pathops.Path()
    p.moveTo(*pt(rx, 0))
    for (x1, y1), (x2, y2), (x3, y3) in (((rx, K * ry), (K * rx, ry), (0, ry)),
                                          ((-K * rx, ry), (-rx, K * ry), (-rx, 0)),
                                          ((-rx, -K * ry), (-K * rx, -ry), (0, -ry)),
                                          ((K * rx, -ry), (rx, -K * ry), (rx, 0))):
        p.cubicTo(*pt(x1, y1), *pt(x2, y2), *pt(x3, y3))
    p.close()
    return p


def stroked(path, width):
    p = pathops.Path(path)
    p.stroke(width, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
    p.convertConicsToQuads(0.01)           # круглые концы skia даёт кониками — булевы операции их не берут
    return p


def op(a, b, kind):
    return pathops.op(a, b, kind)


def svg_path(d):
    """Только M/C/Z — так записан сплайн головки."""
    p = pathops.Path()
    for cmd, args in re.findall(r"([MCZ])([^MCZ]*)", d):
        v = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", args)]
        if cmd == "M":
            p.moveTo(*v)
        elif cmd == "C":
            for i in range(0, len(v), 6):
                p.cubicTo(*v[i:i + 6])
        else:
            p.close()
    return p


def mirrored(path, m):
    out = pathops.Path()
    path.draw(TransformPen(out.getPen() if hasattr(out, "getPen") else out, (-1, 0, 0, 1, m, 0)))
    return out


def airpods():
    P = json.load(open(os.path.join(HERE, "airpods", "fit-params.json")))
    cx, cy, rx, ry, ta, ex, ey, hx, hy, ha = P["tip"]
    x0, x1, yt, yb, rb, sg, ytr = P["stem"]
    head_raw = svg_path(P["head_d"])
    head = op(head_raw, ellipse(cx, cy, rx + P["gap"], ry + P["gap"], ta), pathops.PathOp.DIFFERENCE)
    sx1, sy1, sx2, sy2, sw = P["slit"]
    slit = pathops.Path()
    slit.moveTo(sx1, sy1)
    slit.lineTo(sx2, sy2)
    head = op(head, stroked(slit, sw), pathops.PathOp.DIFFERENCE)
    tip = op(ellipse(cx, cy, rx, ry, ta), ellipse(ex, ey, hx, hy, ha), pathops.PathOp.DIFFERENCE)
    stem = pathops.Path()
    stem.moveTo(x0, yt)
    stem.lineTo(x1, ytr)
    stem.lineTo(x1, yb - rb)
    stem.cubicTo(x1, yb - rb + K * rb, x1 - rb + K * rb, yb, x1 - rb, yb)
    stem.lineTo(x0 + rb, yb)
    stem.cubicTo(x0 + rb - K * rb, yb, x0, yb - rb + K * rb, x0, yb - rb)
    stem.close()
    keep_out = op(head_raw, stroked(head_raw, 2 * sg), pathops.PathOp.UNION)
    stem = op(stem, keep_out, pathops.PathOp.DIFFERENCE)
    body = op(head, stem, pathops.PathOp.UNION)
    m = 2 * P["axis"] + 1
    body = op(body, mirrored(body, m), pathops.PathOp.UNION)
    tips = op(tip, mirrored(tip, m), pathops.PathOp.UNION)
    return body, tips


def speaker():
    """Колонка в сетке 24×24: корпус со скруглёнными углами, пищалка и динамик с колпачком (вырезы)."""
    box = pathops.Path()
    x0, y0, x1, y1, r = 5.5, 1.5, 18.5, 22.5, 3.2
    box.moveTo(x0 + r, y0)
    box.lineTo(x1 - r, y0)
    box.cubicTo(x1 - r + K * r, y0, x1, y0 + r - K * r, x1, y0 + r)
    box.lineTo(x1, y1 - r)
    box.cubicTo(x1, y1 - r + K * r, x1 - r + K * r, y1, x1 - r, y1)
    box.lineTo(x0 + r, y1)
    box.cubicTo(x0 + r - K * r, y1, x0, y1 - r + K * r, x0, y1 - r)
    box.lineTo(x0, y0 + r)
    box.cubicTo(x0, y0 + r - K * r, x0 + r - K * r, y0, x0 + r, y0)
    box.close()
    box = op(box, ellipse(12, 6.4, 1.9, 1.9), pathops.PathOp.DIFFERENCE)
    box = op(box, ellipse(12, 15.0, 4.7, 4.7), pathops.PathOp.DIFFERENCE)
    return op(box, ellipse(12, 15.0, 2.2, 2.2), pathops.PathOp.UNION)


def bounds(*paths):
    xs, ys = [], []
    for p in paths:
        l, t, r, b = p.bounds
        xs += [l, r]
        ys += [t, b]
    return min(xs), min(ys), max(xs), max(ys)


def main():
    body, tips = airpods()
    l, t, r, b = bounds(body, tips)
    k = GLYPH_H / (b - t)
    adv = round((r - l) * k + 2 * SIDE)
    xf = (k, 0, 0, -k, SIDE - l * k, MID_Y + (t + b) / 2 * k)
    spk = speaker()
    sl, st, sr, sb = spk.bounds
    k2 = GLYPH_H / (sb - st)
    adv2 = round((sr - sl) * k2 + 2 * SIDE)
    xf2 = (k2, 0, 0, -k2, SIDE - sl * k2, MID_Y + (st + sb) / 2 * k2)

    glyphs = {".notdef": (pathops.Path(), (1, 0, 0, 1, 0, 0), 500),
              "airpods": (body, xf, adv),
              "airpods.tips": (tips, (xf[0], 0, 0, xf[3], xf[4] - adv, xf[5]), 0),
              "speaker": (spk, xf2, adv2)}
    order = list(glyphs)
    fb = FontBuilder(UPM, isTTF=False)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({0xE900: "airpods", 0xE901: "airpods.tips", 0xE902: "speaker"})
    cs, metrics = {}, {}
    for name, (path, x, w) in glyphs.items():
        pen = T2CharStringPen(w, None)
        path.draw(TransformPen(pen, x))
        cs[name] = pen.getCharString()
        metrics[name] = (w, 0)
    fb.setupCFF("YumiIcons-Regular", {"FullName": "YumiIcons"}, cs, {})
    for name, (path, x, w) in glyphs.items():
        metrics[name] = (w, round(cs[name].calcBounds(None)[0]) if path.bounds != (0, 0, 0, 0) else 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASC, descent=-DESC)
    fb.setupNameTable({"familyName": "YumiIcons", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=ASC, sTypoDescender=-DESC, usWinAscent=ASC, usWinDescent=DESC)
    fb.setupPost()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    fb.save(OUT)
    print("готово:", OUT, "ширина AirPods", adv, "колонки", adv2)


if __name__ == "__main__":
    main()
