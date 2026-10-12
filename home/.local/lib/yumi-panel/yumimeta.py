"""yumimeta — чистые «артист / название» треков yumi-music для MPRIS-клиентов (yumi-player, тексты, центр).

mpv-mpris берёт артиста из тегов потока (на SoundCloud это ник загрузившего, на YouTube — канал),
а yumi-music знает настоящие: он пишет ~/.cache/yumi-music/meta.tsv (ключ \\t артист \\t название \\t сек).
Ключ — как key_for() в yumi-music: id ролика YouTube или ссылка SoundCloud с [^A-Za-z0-9] → «_».
Откат: yumi-uninstall lyrics
"""
import os
import re

META = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "yumi-music", "meta.tsv")
_state = {"stamp": None, "map": {}}


def key_for(url):
    if not url:
        return None
    m = re.search(r"[?&]v=([A-Za-z0-9_-]+)", url) or re.search(r"youtu\.be/([A-Za-z0-9_-]+)", url)
    if m:
        return m.group(1)
    if re.match(r"https?://[\w.]*soundcloud\.com/", url):
        return "".join(chr(c) if chr(c).isascii() and chr(c).isalnum() else "_" for c in url.encode())[:120]
    return None


def _load():
    try:
        st = os.stat(META)
    except OSError:
        _state.update(stamp=None, map={})
        return _state["map"]
    stamp = (st.st_mtime_ns, st.st_size)
    if stamp != _state["stamp"]:
        m = {}
        with open(META, encoding="utf-8", errors="replace") as f:
            for line in f:
                p = line.rstrip("\n").split("\t")
                if len(p) >= 3 and p[0]:
                    m[p[0]] = {"artist": p[1], "title": p[2], "dur": float(p[3]) if len(p) > 3 and p[3] else 0}
        _state.update(stamp=stamp, map=m)
    return _state["map"]


def lookup(url):
    """{"artist", "title", "dur"} для трека yumi-music по его ссылке (xesam:url) или None."""
    k = key_for(url)
    return _load().get(k) if k else None
