"""yumilyrics — тексты песен для yumi-player.

Источники по порядку:
  0) YouTube Music по id ролика (ссылки youtube.com / music.youtube.com / youtu.be) — текст этого же ролика;
  1) Apple Music (аккаунт пользователя, yumiapple; 13.10) — синхронные тексты, много русского рэпа;
  1б) YouTube Music поиском той же официальной песни (тексты Musixmatch с таймингами);
  2) LRCLIB: /api/get по артисту, названию и длительности, затем /api/search.
Правила (v3, 13.10):
  - тайминги показываются, только если длина найденной песни совпадает с треком ±3 с, а последняя строка
    начинается до конца трека; иначе тот же текст без таймингов («другая версия трека»);
  - sped up / slowed / nightcore — ищется оригинал, тайминги растягиваются в отношении длин;
  - ремикс / edit / flip — текст оригинала без таймингов (ролик YouTube — по id, если длина совпала); мэшап из нескольких песен — без текста;
  - длина трека неизвестна — ответ не кэшируется (повторим, когда узнаем).
Кэш ~/.cache/yumi-player/lyrics/ (найденные — навсегда, «текста нет» — на сутки, сетевые ошибки — нет);
в записи хранится длина трека и найденной песни: запись под другую длину перепроверяется.

fetch(...) -> {"lines": [(сек, строка), ...], "synced": bool, "source": str} или None
Откат: yumi-uninstall lyrics
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
VER = 3
TOL = 3                                   # допуск длины для таймингов, сек

_LRC_TIME = re.compile(r"\[(\d+):(\d+(?:[.:]\d+)?)\]")
_WORD_TIME = re.compile(r"<\d+:\d+(?:\.\d+)?>")
# «(Official Video)», «[Lyrics]», «(prod. X)», «*OUT EVERYWHERE!*» и т.п. — мешают поиску
_JUNK = re.compile(r"\s*[(\[][^)\]]*\b(official|video|audio|lyrics?|visuali[sz]er|prod\.?|remaster\w*|hd|4k|mv|"
                   r"клип|премьера|текст)\b[^)\]]*[)\]]", re.I)
# версии трека: ускоренные (тайминги растягиваются), ремиксы (тайминги чужие), мэшапы (текст чужой)
_SPEED = re.compile(r"\b(sped[\s-]*up|speed[\s-]*up|nightcore|slowed|slow(?:ed)?\s*\+\s*reverb|ускор\w*|замедл\w*)\b", re.I)
_REMIX = re.compile(r"\b(remix|rmx|edit|flip|bootleg|vip|re-?work|club\s+(?:mix|version)|extended|ремикс)\b", re.I)
_INSTR = re.compile(r"\b(минус\w*|instrumental|инструментал\w*|karaoke|караоке|acapella-free|no vocals)\b", re.I)
_MASHUP = re.compile(r"\b(mash-?up|мэшап|мешап|megamix)\b", re.I)
_VERSION_TAG = re.compile(r"\s*[(\[][^)\]]*\b(sped|speed|slowed|reverb|nightcore|remix|rmx|edit|flip|bootleg|vip|"
                          r"mix|version|mashup|ремикс|ускор\w*|замедл\w*)\b[^)\]]*[)\]]"
                          r"|\s*[-–—]\s*(sped up|speed up|slowed(?: \+ reverb)?|nightcore)\s*$", re.I)


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


def kind(title):
    """'instr' | 'mashup' | 'speed' | 'remix' | '' — какая это версия песни (по названию)."""
    t = title or ""
    if _INSTR.search(t):
        return "instr"
    if _MASHUP.search(t):
        return "mashup"
    if _SPEED.search(t):
        return "speed"
    # пометка ремикса — в скобках, после « - » или словом в конце («Droppers Rmx»), а не часть названия
    # («Flip Phone Twerk» — обычная песня)
    tags = " ".join(re.findall(r"[(\[]([^)\]]*)[)\]]", t)) + " " + (re.split(r"\s[-–—]\s", t)[-1] if re.search(r"\s[-–—]\s", t) else "")
    if _REMIX.search(tags) or re.search(r"\b(remix|rmx|ремикс)\s*$", t, re.I):
        return "remix"
    return ""


def clean(title, artist):
    """(артист, название) без мусора YouTube/SoundCloud; «Артист — Название» в заголовке разбирается."""
    t = _JUNK.sub("", title or "")
    t = re.sub(r"\*[^*]*\*", "", t)
    a = re.sub(r"\s*-\s*Topic$", "", (artist or "").strip())
    for sep in (" — ", " – ", " - "):
        if sep in t:
            left, right = t.split(sep, 1)
            # «Артист - Песня» в названии: и когда слева ровно артист, и когда артист + «feat …»
            if not a or left.strip().lower() == a.lower() or left.strip().lower().startswith(a.lower()):
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


def original_title(title):
    """Название без пометок версии: «Ты (sped up)» → «Ты», «Мамбл [YellowOrigami Edit]» → «Мамбл»."""
    t = title or ""
    for _ in range(3):
        t2 = _VERSION_TAG.sub("", t)
        if t2 == t:
            break
        t = t2
    return t.strip(" -—–") or title


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
    for attempt in range(3):                  # LRCLIB временами отвечает 503 — повторить с паузой
        try:
            with urllib.request.urlopen(req, timeout=8) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            err = e
            if e.code < 500 and e.code != 429:
                break
        except (OSError, ValueError) as e:
            err = e
        time.sleep(1 + attempt)
    raise NetError(err)


def _from_record(rec):
    if not rec:
        return None
    md = rec.get("duration") or 0
    if rec.get("syncedLyrics"):
        lines = parse_lrc(rec["syncedLyrics"])
        if lines:
            return {"lines": lines, "synced": True, "source": "LRCLIB", "mdur": md}
    if rec.get("plainLyrics"):
        return {"lines": [(0, s) for s in rec["plainLyrics"].splitlines()], "synced": False, "source": "LRCLIB",
                "mdur": md}
    if rec.get("instrumental"):
        return {"lines": [(0, "♪ Без слов")], "synced": False, "source": "LRCLIB", "mdur": md}
    return None


def from_lrclib(artist, title, length_s=0):
    """Запись LRCLIB: при известной длине — только версия ±TOL (синхронная лучше), иначе любая подходящая."""
    if not title:
        return None
    if artist and length_s:
        res = _from_record(_get("get", {"artist_name": artist, "track_name": title, "duration": round(length_s)}))
        if res:
            return res
    for q in ({"track_name": title, "artist_name": artist} if artist else None, {"q": f"{artist} {title}".strip()}):
        if not q:
            continue
        found = _get("search", q) or []
        if length_s:
            found.sort(key=lambda r: abs((r.get("duration") or 0) - length_s))
            near = [r for r in found if abs((r.get("duration") or 0) - length_s) <= TOL]
            found = near or found[:1]           # нет той же длины — ближайшая (станет текстом без таймингов)
        for rec in sorted(found, key=lambda r: not r.get("syncedLyrics")):
            res = _from_record(rec)
            if res:
                return res
    return None


def from_ytmusic(vid=None, artist="", title="", length_s=0):
    """Musixmatch через YouTube Music: по id ролика или поиском той же официальной песни."""
    if not (os.access(YT_PY, os.X_OK) and os.path.exists(YT_HELPER)):
        return None
    if not vid and not title:
        return None
    args = [vid] if vid else ["--search", artist, title, str(round(length_s or 0))]
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
    return {"lines": [tuple(x) for x in d["lines"]], "synced": bool(d.get("synced")),
            "source": d.get("source") or "YouTube Music", "mdur": d.get("mdur") or 0}


def from_apple(artist="", title="", length_s=0):
    """Apple Music (аккаунт пользователя, yumiapple): синхронный текст той же песни из каталога."""
    try:
        import yumiapple
    except ImportError:
        return None
    if not (yumiapple.available() and title):
        return None
    try:
        sid, md = yumiapple.search(artist, title, length_s)
        if not sid:
            return None
        lines, synced = yumiapple.lyrics(sid)
    except yumiapple.AppleAuthError as e:
        raise NetError(e)                     # ключ истёк — не кэшировать «текста нет»
    except (OSError, ValueError) as e:
        raise NetError(e)
    if not lines:
        return None
    return {"lines": lines, "synced": synced, "source": "Apple Music", "mdur": md}


def _plain(res, note):
    return {"lines": [(0, s) for _, s in res["lines"] if s and s.strip() != "♪"], "synced": False,
            "source": res["source"] + " · " + note, "mdur": res.get("mdur", 0)}


def fit(res, length_s, k=""):
    """Подогнать найденный текст к треку: тайминги оставить / растянуть / убрать."""
    if not res or not res.get("synced"):
        return res
    if k == "remix":                          # чужая аранжировка: тайминги оригинала не подходят
        return _plain(res, "ремикс — без таймингов")
    if not length_s:
        return res
    md = res.get("mdur") or 0
    last = max((t for t, s in res["lines"] if s), default=0)
    if md and abs(md - length_s) <= TOL and last < length_s:
        return res
    if k == "speed" and md:
        r = length_s / md
        if 0.6 <= r <= 1.45 and last * r < length_s:
            return dict(res, lines=[(t * r, s) for t, s in res["lines"]],
                        source=res["source"] + (" · ускорено" if r < 1 else " · замедлено") + f" ×{1 / r:.2f}")
    if not md and last < length_s and k == "":
        return res                            # длину источник не дал, но текст в трек укладывается
    return _plain(res, "ремикс — без таймингов" if k == "remix" else "другая версия трека")


def _search(title, artist, length_s, k):
    """Шаги поиска для трека не с YouTube (или ремикса с YouTube) с учётом версии."""
    cands = candidates(title, artist)
    steps = []
    if k in ("speed", "remix"):
        orig = [(a, original_title(t)) for a, t in cands]
        # оригинал: для ускоренных длина не важна (растянем), для ремиксов — тоже (будет без таймингов)
        steps += [lambda ca=ca, ct=ct: from_apple(ca, ct, 0) for ca, ct in orig[:2] if ca]
        steps += [lambda ca=ca, ct=ct: from_ytmusic(None, ca, ct, 0) for ca, ct in orig[:2] if ca]
        steps += [lambda ca=ca, ct=ct: from_lrclib(ca, ct, 0) for ca, ct in orig]
    else:
        steps += [lambda ca=ca, ct=ct: from_apple(ca, ct, length_s) for ca, ct in cands[:2] if ca]
        steps += [lambda ca=ca, ct=ct: from_ytmusic(None, ca, ct, length_s) for ca, ct in cands[:2] if ca]
        steps += [lambda ca=ca, ct=ct: from_lrclib(ca, ct, length_s) for ca, ct in cands]
    return [lambda st=st: (k, st()) for st in steps]


def _key(title, artist, url):
    vid = yt_id(url)
    if vid:
        return f"yt-{vid}"
    a, t = clean(title, artist)
    return "v2-" + hashlib.sha1(f"{a.lower()}\x1f{t.lower()}".encode()).hexdigest()[:20]


def _read_cache(path, length_s):
    try:
        with open(path) as f:
            c = json.load(f)
    except (OSError, ValueError):
        return False, None
    if c.get("v") != VER:
        return False, None                    # запись старых правил — перепроверить
    if length_s and c.get("dur") and abs(c["dur"] - length_s) > TOL:
        return False, None                    # запись под другую длину трека
    if c.get("lines"):
        return True, {"lines": [tuple(x) for x in c["lines"]], "synced": c["synced"], "source": c["source"]}
    if time.time() - c.get("t", 0) < MISS_TTL:
        return True, None
    return False, None


def fetch(title, artist, length_s=0, url="", force=False):
    vid = yt_id(url)
    k = kind(title)
    # ключ прежний (yt-<id> / v2-<хэш>): плеер, меню и предзагрузка попадают в одну запись;
    # старые записи без "v": 3 перепроверяются при первом обращении
    path = os.path.join(CACHE, _key(title, artist, url) + ".json")
    if not force:
        hit, res = _read_cache(path, length_s)
        if hit:
            return res

    if k == "instr":                          # минусовка — петь нечего
        res, net_failed = {"lines": [(0, "♪ Без слов")], "synced": False, "source": "минусовка"}, False
    elif k == "mashup":                       # несколько песен в одной — чужой текст хуже, чем никакого
        res, net_failed = None, False
    else:
        res, net_failed = None, False
        # ролик YouTube — сам этот трек: даже ремикс получает тайминги, если длина совпала
        steps = [lambda: ("", from_ytmusic(vid))] if vid else []
        steps += _search(title, artist, length_s, k)
        for step in steps:
            try:
                fk, r = step()
            except NetError:
                net_failed = True
                continue
            if r:
                res = fit(r, length_s, fk)
                if res.get("synced") or k in ("speed", "remix"):
                    break
                # тайминги не подошли — запомнить как запасной, но поискать версию той же длины дальше
                if not res.get("synced"):
                    fallback, res = res, None
                    for step2 in steps[steps.index(step) + 1:]:
                        try:
                            fk2, r2 = step2()
                        except NetError:
                            net_failed = True
                            continue
                        if r2:
                            f2 = fit(r2, length_s, fk2)
                            if f2.get("synced"):
                                res = f2
                                break
                    res = res or fallback
                    break
    if (res or not net_failed) and length_s:
        os.makedirs(CACHE, exist_ok=True)
        tmp = path + ".tmp"
        rec = dict(res or {}, t=time.time(), v=VER, dur=round(length_s, 1), kind=k)
        with open(tmp, "w") as f:
            json.dump(rec, f, ensure_ascii=False)
        os.replace(tmp, path)
    if not res:
        return None
    return {"lines": res["lines"], "synced": res["synced"], "source": res["source"]}
