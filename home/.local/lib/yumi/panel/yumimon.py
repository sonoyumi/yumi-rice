"""Мониторы оболочки yumi из ~/.config/yumi/monitors.conf (один файл вместо констант в скриптах).

Строка: выход  интерфейс  dpi_rofi  название  [ширина высота масштаб]
Монитора нет в файле → интерфейс 1.0, dpi 96, название = имя выхода."""
import os

PATH = os.path.expanduser("~/.config/yumi/monitors.conf")


def load():
    """{выход: {"ui": float, "dpi": int, "label": str, "size": (w, h) | None, "dpr": float | None}} в порядке файла."""
    out = {}
    try:
        lines = open(PATH, encoding="utf-8").read().splitlines()
    except OSError:
        return out
    for line in lines:
        f = line.split("#", 1)[0].split()
        if len(f) < 4:
            continue
        try:
            out[f[0]] = {"ui": float(f[1]), "dpi": int(f[2]), "label": f[3],
                         "size": (int(f[4]), int(f[5])) if len(f) >= 6 else None,
                         "dpr": float(f[6]) if len(f) >= 7 else None}
        except ValueError:
            continue
    return out


def ui_scale():
    """{выход: коэффициент} только для мониторов, где он не 1.0."""
    return {n: m["ui"] for n, m in load().items() if m["ui"] != 1.0}


def labels():
    return {n: m["label"] for n, m in load().items()}
