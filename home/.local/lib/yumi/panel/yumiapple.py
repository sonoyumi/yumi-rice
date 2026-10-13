"""yumiapple — синхронные тексты из Apple Music (аккаунт пользователя) для yumilyrics.

Ключи:
  - разработчика — публичный JWT веб-плеера music.apple.com (берётся из его скрипта, кэш до истечения);
  - пользователя — media-user-token, его кладёт сам пользователь в ~/.config/yumi/music/apple-media-user-token
    (права 0600; уходит только на amp-api.music.apple.com). Нужна подписка Apple Music.
search(artist, title, dur) -> (id песни, её длина) | (None, 0);  lyrics(id) -> [(сек, строка)], synced
Ключ пользователя истёк/неверен → AppleAuthError (yumilyrics не кэширует такой ответ).
Откат: yumi-uninstall apple-lyrics
"""
import base64
import difflib
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")
TOKEN = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "yumi", "music",
                     "apple-media-user-token")
DEVCACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "yumi-player", "apple-dev.json")
API = "https://amp-api.music.apple.com/v1/"
UA = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
_TT = "{http://www.w3.org/ns/ttml}"
_ROLE = "{http://www.w3.org/ns/ttml#metadata}role"
_state = {}


class AppleAuthError(Exception):
    pass


def available():
    return os.path.exists(TOKEN)


def _http(url, headers=None, timeout=15):
    h = {"User-Agent": UA, "Origin": "https://music.apple.com", "Referer": "https://music.apple.com/", **(headers or {})}
    with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def _dev_token():
    """JWT веб-плеера: из кэша, пока не истёк, иначе из главного скрипта music.apple.com."""
    if _state.get("dev") and _state.get("exp", 0) > time.time() + 3600:
        return _state["dev"]
    try:
        c = json.load(open(DEVCACHE))
        if c.get("exp", 0) > time.time() + 3600:
            _state.update(c)
            return c["dev"]
    except (OSError, ValueError):
        pass
    page = _http("https://music.apple.com/it/browse")
    js = re.findall(r'src="(/assets/index[^"]+\.js)"', page)
    if not js:
        raise urllib.error.URLError("music.apple.com: не найден скрипт веб-плеера")
    src = _http("https://music.apple.com" + js[0], timeout=30)
    for tok in re.findall(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}", src):
        p = tok.split(".")[1]
        try:
            pl = json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))
        except ValueError:
            continue
        if pl.get("iss") and pl.get("exp", 0) > time.time():
            _state.update(dev=tok, exp=pl["exp"])
            os.makedirs(os.path.dirname(DEVCACHE), exist_ok=True)
            with open(DEVCACHE, "w") as f:
                json.dump({"dev": tok, "exp": pl["exp"]}, f)
            return tok
    raise urllib.error.URLError("music.apple.com: нет действующего ключа веб-плеера")


def _api(path, user=False):
    h = {"Authorization": "Bearer " + _dev_token()}
    if user:
        try:
            h["media-user-token"] = open(TOKEN).read().strip()
        except OSError:
            raise AppleAuthError("нет ключа Apple Music")
    try:
        return json.loads(_http(API + path, h))
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            if not user:
                _state.clear()                    # ключ веб-плеера сменился — взять заново
                try:
                    os.remove(DEVCACHE)
                except OSError:
                    pass
            raise AppleAuthError(f"Apple Music: HTTP {e.code}") from e
        if e.code == 404:
            return None
        raise


def storefront():
    if not _state.get("sf"):
        d = _api("me/storefront", user=True)
        _state["sf"] = (d or {}).get("data", [{}])[0].get("id") or "it"
    return _state["sf"]


def _norm(s):
    s = re.sub(r"\(.*?\)|\[.*?\]", " ", (s or "").lower().replace("ё", "е"))
    s = re.sub(r"\b(feat|ft|featuring|prod|with)\b.*$", " ", s)
    return re.sub(r"[^0-9a-zа-я]+", " ", s).strip()


def search(artist, title, dur=0):
    """Та же песня в каталоге: похожее название + тот же артист; при равенстве — ближе по длине."""
    first = re.split(r",|&| x | X |\bfeat\.?|\bft\.?| and ", artist or "")[0].strip()
    q = urllib.parse.urlencode({"term": f"{first} {title}"[:120], "types": "songs", "limit": 10})
    d = _api(f"catalog/{storefront()}/search?{q}")
    best, best_s, best_d = None, 0.0, 0
    for s in (((d or {}).get("results") or {}).get("songs") or {}).get("data") or []:
        a = s.get("attributes") or {}
        sd = round((a.get("durationInMillis") or 0) / 1000)
        st = difflib.SequenceMatcher(None, _norm(title), _norm(a.get("name"))).ratio()
        names = _norm(a.get("artistName"))
        sa = 1.0 if _norm(first) and (_norm(first) in names or names in _norm(first)) else 0.0
        if not sa:
            continue
        score = st * 0.7 + sa * 0.3 - (0.002 * abs(sd - dur) if dur and sd else 0)
        if not a.get("hasLyrics"):
            score -= 0.05
        if score > best_s:
            best, best_s, best_d = s["id"], score, sd
    return (best, best_d) if best_s >= 0.75 else (None, 0)


def _t(v):
    """«1:02.345» / «62.345» / «0:01:02.345» → секунды."""
    sec = 0.0
    for part in (v or "0").split(":"):
        sec = sec * 60 + float(part)
    return sec


def _text(el):
    """Текст строки: основной голос, бэк-вокал (x-bg) — в скобках."""
    out = []
    if el.text:
        out.append(el.text)
    for ch in el:
        t = "".join(ch.itertext())
        if ch.get(_ROLE) == "x-bg":
            t = "(" + re.sub(r"[()]", "", t).strip() + ")"
        out.append(t)
        if ch.tail:
            out.append(ch.tail)
    return re.sub(r"\s+", " ", "".join(out)).strip()


def lyrics(song_id):
    """[(сек, строка)], synced — синхронный (пословный → построчный) или простой текст; [] — нет."""
    sf = storefront()
    for ep in ("syllable-lyrics", "lyrics"):
        d = _api(f"catalog/{sf}/songs/{song_id}/{ep}", user=True)
        if not d or not d.get("data"):
            continue
        a = d["data"][0].get("attributes") or {}
        ttml = a.get("ttml") or ""
        if not ttml and a.get("ttmlLocalizations"):
            ttml = a["ttmlLocalizations"] if isinstance(a["ttmlLocalizations"], str) else ""
        if not ttml:
            continue
        root = ET.fromstring(ttml)
        timed = (root.get("{http://music.apple.com/lyric-ttml-internal}timing") or "").lower() != "none"
        lines = []
        for p in root.iter(_TT + "p"):
            s = _text(p)
            if s:
                lines.append((round(_t(p.get("begin")), 3) if timed and p.get("begin") else 0, s))
        if lines:
            return lines, timed and any(t for t, _ in lines)
    return [], False
