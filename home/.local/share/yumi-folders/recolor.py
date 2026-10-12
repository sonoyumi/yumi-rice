#!/usr/bin/env python3
"""Перекрашивает папки Papirus в палитру обоев (wallbash 1xa1..1xa9).
Каждый цвет значка заменяется оттенком палитры той же светлоты; белые блики и почти чёрное остаются."""
import colorsys, os, re, sys
pal_file, src, dst = sys.argv[1:4]
pal = {}
for line in open(pal_file):
    m = re.match(r'dcol_1xa(\d)="#?([0-9A-Fa-f]{6})"', line.strip())
    if m: pal[int(m.group(1))] = m.group(2)
if len(pal) < 9: sys.exit(f"палитра неполная: {pal_file}")
def sub(m):
    h = m.group(1)
    if len(h) == 3: h = ''.join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    _, l, s = colorsys.rgb_to_hls(r, g, b)
    if l > 0.93 or (s < 0.08 and (l > 0.85 or l < 0.12)):
        return '#' + h
    return '#' + pal[min(9, max(1, round(1 + l * 8)))]
os.makedirs(dst, exist_ok=True)
for name in os.listdir(src):
    if not name.endswith('.svg'): continue
    svg = open(os.path.join(src, name), encoding='utf-8').read()
    out = re.sub(r'#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})\b', sub, svg)
    tmp = os.path.join(dst, '.' + name + '.tmp')
    with open(tmp, 'w', encoding='utf-8') as f: f.write(out)
    os.replace(tmp, os.path.join(dst, name))
