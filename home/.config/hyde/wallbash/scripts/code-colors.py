#!/usr/bin/env python3
# Разные цвета для частей кода в VS Code (тема Wallbash), в гамме текущей темы HyDE.
# Шаблон always/code-wallbash.dcol (после стандартного шаблона расширения) ставит в подсветке синтаксиса метки #@func, #@type и т.д.;
# здесь они заменяются оттенками акцента темы, повёрнутыми по цветовому кругу.
# Ключевые слова, операторы и комментарии остаются цветами палитры.
import colorsys
import glob
import json
import os
import re

cache = os.environ.get("cacheDir") or os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "hyde")
CODE = os.path.join(cache, "wallbash", "code.json")
DCOL = os.path.join(cache, "wall.dcol")

# Сдвиг оттенка от цвета ключевых слов (4xa8), в градусах. Для розово-фиолетового акцента:
# функции — голубой, типы — золотой, строки — зелёный, числа — оранжевый,
# параметры — бирюзовый, встроенные и self — лиловый, escape-символы — жёлтый
ROLES = {"func": -82, "type": 121, "string": 188, "number": 95, "param": -117, "builtin": -32, "escape": 140}


def palette():
    d = {}
    with open(DCOL) as f:
        for line in f:
            m = re.match(r'dcol_(\w+)="([0-9A-Fa-f]{6}|dark|light)"', line.strip())
            if m:
                d[m[1]] = m[2]
    return d


def hls(hex_):
    r, g, b = (int(hex_[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)


def to_hex(h, l, s):
    return "".join(f"{round(c * 255):02X}" for c in colorsys.hls_to_rgb(h % 1, l, s))


def main():
    pal = palette()
    h, _, _ = hls(pal.get("4xa8", "E1AAF0"))
    text = open(CODE).read()
    # Тёмный или светлый — по настоящему фону редактора: в режиме «всегда тёмный» HyDE
    # инвертирует палитру светлых обоев, и dcol_mode в wall.dcol тогда не совпадает с фоном
    bg = re.search(r'"editor\.background":\s*"#([0-9A-Fa-f]{6})', text)
    dark = hls(bg[1])[1] < 0.5 if bg else pal.get("mode", "dark") == "dark"
    # Светлые пастельные на тёмном фоне, тёмные насыщенные на светлом
    l, s = (0.78, 0.70) if dark else (0.38, 0.65)
    colors = {r: to_hex(h + off / 360, l, s) for r, off in ROLES.items()}
    text = re.sub(r"#@(\w+)", lambda m: "#" + colors.get(m[1], pal.get("txt1", "FFFFFF")), text)
    json.loads(text)  # не записывать сломанный JSON
    with open(CODE, "w") as f:
        f.write(text)
    # Расширение не всегда замечает новый code.json — кладём тему ему напрямую (VS Code перечитает её сам)
    for theme in glob.glob(os.path.expanduser("~/.vscode*/extensions/thehydeproject.wallbash-*/themes/wallbash.json")):
        with open(theme, "w") as f:
            f.write(text)
    # yumi-tone: интерфейс VS Code в тоне обоев (хук берёт code.json и перекрашивает цвета интерфейса)
    hook = os.path.expanduser("~/.config/yumi-accent/hooks.d/50-vscode")
    if os.access(hook, os.X_OK):
        import subprocess
        subprocess.run([hook], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
