"""yumilyrics — тексты песен для yumi-player.

Источники по порядку:
  1) YouTube Music по id ролика (ytmusicapi из venv yumi-music, тексты Musixmatch с таймингами) —
     только для ссылок youtube.com / music.youtube.com / youtu.be;
  2) LRCLIB: /api/get по артисту, названию и длительности, затем /api/search.
Ответы кэшируются в ~/.cache/yumi-player/lyrics/ (найденные — навсегда, «текста нет» — на сутки;
сетевые ошибки не кэшируются).

fetch(...) -> {"lines": [(сек, строка), ...], "synced": bool, "source": str} или None
Откат: yumi-uninstall player
"""
import hashlib
import json
import os
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "yumi-player", "lyrics")
YT_PY = os.path.expanduser("~/.local/share/yumi-music/venv/bin/python")
YT_HELPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "yumilyrics-yt")
LRCLIB = "https://lrclib.net/api/"
UA = "yumi-player/1.0 (lyrics)"
MISS_TTL = 86400

_LRC_TIME = re.compile(r"\[(\d+):(\d+(?:[.:]\d+)?)\]")
_WORD_TIME = re.compile(r"<\d+:\d+(?:\.\d+)?>")
# «(Official Video)», «[Lyrics]», «(prod. X)», «*OUT EVERYWHERE!*» и т.п. — мешают поиску
_JUNK = re.compile(r"\s*[(\[][^)\]]*\b(official|video|audio|lyrics?|visuali[sz]er|prod\.?|remaster\w*|hd|4k|mv|"
                   r"клип|премьера|текст)\b[^)\]]*[)\]]", re.I)


class NetError(Exception):
    pass


def parse_lrc(text):
    """LRC → [(сек, строка)], по времени. Метки слов (enhanced LRC) пока убираются."""
    out = []
    for line in (text or "").splitlines():
        stamps = _LRC_TIME.findall(line)
        if not stamps:
            continue
        words = _WORD_TIME.sub("", _LRC_TIME.sub("", line)).strip()
        for m, s in stamps:
            out.append((int(m) * 60 + float(s.replace(":", ".")), words))
    out.sort(key=lambda x: x[0])
    return out


def clean(title, artist):
    """(артист, название) без мусора YouTube/SoundCloud; «Артист — Название» в заголовке разбирается."""
    t = _JUNK.sub("", title or "")
    t = re.sub(r"\*[^*]*\*", "", t)
    a = re.sub(r"\s*-\s*Topic$", "", (artist or "").strip())
    for sep in (" — ", " – ", " - "):
        if sep in t:
            left, right = t.split(sep, 1)
            if not a or left.strip().lower() == a.lower():
                a, t = left.strip(), right
            break
    t = re.sub(r"\s+\(?(?:ft|feat)\.?\s.*$", "", t, flags=re.I)
    return a.strip(), t.strip(" -—–")


def candidates(title, artist):
    """Пары (артист, название) для поиска по порядку. На SoundCloud «артист» — часто ник загрузившего,
    а настоящий артист сидит в названии «Песня - Артист» или «Артист - Песня»: пробуем обе половины."""
    a, t = clean(title, artist)
    out = [(a, t)]
    for sep in (" — ", " – ", " - "):
        if sep in t:
            left, right = (x.strip() for x in t.split(sep, 1))
            out += [(left, right), (right, left)]
            break
    return [c for i, c in enumerate(out) if c[1] and c not in out[:i]]


def yt_id(url):
    try:
        u = urllib.parse.urlparse(url or "")
    except ValueError:
        return None
    host = u.netloc.lower()
    if host.endswith("youtu.be"):
        return u.path.strip("/") or None
    if host.endswith("youtube.com"):
        return (urllib.parse.parse_qs(u.query).get("v") or [None])[0]
    return None


def _get(endpoint, params):
    req = urllib.request.Request(LRCLIB + endpoint + "?" + urllib.parse.urlencode(params), headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise NetError(e)
    except (OSError, ValueError) as e:
        raise NetError(e)


def _from_record(rec):
    if not rec:
        return None
    if rec.get("syncedLyrics"):
        lines = parse_lrc(rec["syncedLyrics"])
        if lines:
            return {"lines": lines, "synced": True, "source": "LRCLIB"}
    if rec.get("plainLyrics"):
        return {"lines": [(0, s) for s in rec["plainLyrics"].splitlines()], "synced": False, "source": "LRCLIB"}
    if rec.get("instrumental"):
        return {"lines": [(0, "♪ Без слов")], "synced": False, "source": "LRCLIB"}
    return None


def from_lrclib(artist, title, length_s=0):
    if not title:
        return None
    if artist:
        q = {"artist_name": artist, "track_name": title}
        if length_s:
            q["duration"] = round(length_s)
        res = _from_record(_get("get", q))
        if res:
            return res
    # поиск: сначала с синхронным текстом и близкой длительностью
    for q in ({"track_name": title, "artist_name": artist} if artist else None, {"q": f"{artist} {title}".strip()}):
        if not q:
            continue
        found = _get("search", q) or []
        if length_s:
            found.sort(key=lambda r: abs((r.get("duration") or 0) - length_s))
            found = [r for r in found if abs((r.get("duration") or 0) - length_s) <= 4] or found[:0]
        for rec in sorted(found, key=lambda r: not r.get("syncedLyrics")):
            res = _from_record(rec)
            if res:
                return res
    return None


def from_ytmusic(vid=None, artist="", title="", length_s=0):
    """Musixmatch через YouTube Music: по id ролика или поиском той же официальной песни (длина ±3 с)."""
    if not (os.access(YT_PY, os.X_OK) and os.path.exists(YT_HELPER)):
        return None
    args = [vid] if vid else ["--search", artist, title, str(round(length_s or 0))]
    if not vid and not title:
        return None
    try:
        r = subprocess.run([YT_PY, "-I", YT_HELPER, *args], capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired as e:
        raise NetError(e)
    if r.returncode == 2:
        raise NetError(r.stderr.strip())
    try:
        d = json.loads(r.stdout or "{}")
    except ValueError:
        return None
    if not d.get("lines"):
        return None
    return {"lines": [tuple(x) for x in d["lines"]], "synced": bool(d.get("synced")), "source": d.get("source") or "YouTube Music"}


def fetch(title, artist, length_s=0, url=""):
    vid = yt_id(url)
    a, t = clean(title, artist)
    # YouTube: текст определяется роликом — ключ по id (предзагрузка yumi-music и плеер попадают в одну запись)
    # v2: тексты не с YouTube теперь сначала ищутся в Musixmatch — старые записи LRCLIB не используем
    key = f"yt-{vid}" if vid else "v2-" + hashlib.sha1(f"{a.lower()}\x1f{t.lower()}".encode()).hexdigest()[:20]
    path = os.path.join(CACHE, key + ".json")
    try:
        with open(path) as f:
            c = json.load(f)
        if c.get("lines") or time.time() - c.get("t", 0) < MISS_TTL:
            return {"lines": [tuple(x) for x in c["lines"]], "synced": c["synced"], "source": c["source"]} \
                if c.get("lines") else None
    except (OSError, ValueError, KeyError):
        pass

    res, net_failed = None, False
    # 1) YouTube Music (Musixmatch) — по id или поиском той же песни: тайминги точнее LRCLIB; 2) LRCLIB
    steps = [lambda: from_ytmusic(vid)] if vid else \
        [lambda ca=ca, ct=ct: from_ytmusic(None, ca, ct, length_s) for ca, ct in candidates(title, artist)[:2] if ca]
    steps += [lambda ca=ca, ct=ct: from_lrclib(ca, ct, length_s) for ca, ct in candidates(title, artist)]
    for step in steps:
        try:
            res = step()
        except NetError:
            net_failed = True
            continue
        if res:
            break
    if res or not net_failed:
        os.makedirs(CACHE, exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(dict(res or {}, t=time.time()), f, ensure_ascii=False)
        os.replace(tmp, path)
    return res
