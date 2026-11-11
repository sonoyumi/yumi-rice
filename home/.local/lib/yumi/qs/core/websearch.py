# Ядро веб-поиска без GTK: часть бывшего ~/.local/bin/yumi-menu-websearch (16.10 — в архиве yumi-archive/legacy-menus).
#!/usr/bin/env python3
"""yumi-menu-websearch — веб-поиск на GTK (каркас yumi-panel; замена `hyde-shell rofi.websearch`).
  yumi-menu-websearch [--center|--bar]   открыть / закрыть (повторный вызов закрывает)
  yumi-menu-websearch --close            закрыть
  yumi-menu-websearch --resolve ТЕКСТ    без окна: напечатать, что откроет Enter (для проверки)

Как пользоваться:
  • набрать запрос и Enter — поиск в выбранном поисковике (↑/↓ — сменить поисковик);
  • «имя:запрос» — сразу в нужный: «yt:lofi», «aw:pipewire», «aur:paru», «github:hyprland»
    (имя — ключ, короткое имя, начало ключа/названия от 2 букв);
  • адрес («archlinux.org», «https://…», «localhost:8080») открывается как адрес;
  • пустая строка + Enter — главная страница поисковика;
  • Tab — к спискам; щелчок по поисковику при введённом запросе ищет сразу; щелчок по истории повторяет запрос.
Открывает `uwsm app -- xdg-open <адрес>` (браузер по умолчанию, в своей области systemd).

Поисковики: DATA_DIR/websearch.lst (формат HyDE «значок | ключ | адрес» + «| название | короткие имена»);
  свои добавки/замены — ~/.config/yumi/panel/websearch.lst (тот же формат).
История: $XDG_CACHE_HOME/yumi-panel/websearch-history.json (последние HISTORY_MAX запросов).

Переменные для проверки:
  YP_DRYRUN=1               адрес только печатается (stdout и stderr), браузер не открывается, окно не закрывается;
                            история пишется, только если задан YP_WEBSEARCH_CACHE
  YP_WEBSEARCH_CACHE=каталог  свой каталог истории (тесты)
  YP_WEBSEARCH_DATA=каталог   свой каталог с websearch.lst
  YP_SEARCH=текст           сразу ввести текст;  YP_WS_ENTER=1 — через 0,8 с «нажать» Enter (только с YP_DRYRUN)
  YP_PRINT_SHAPE=1          через 0,7 с напечатать в stderr «[shape] x y w h» — рамку меню в слое (для снимков)
Откат: удалить этот файл (и вернуть бинд SUPER+SHIFT+/ на `hyde-shell rofi.websearch`)"""
import os
import sys
import json
import re
import shutil
import time
import urllib.parse
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

HOME = os.path.expanduser("~")
_HERE = os.path.dirname(os.path.realpath(__file__))
# каталог данных меню (будущий общий: ~/.local/share/yumi-panel/data); пока его нет — data/ рядом со скриптом
DATA_DIR = os.environ.get("YP_WEBSEARCH_DATA") or next(
    (d for d in (os.path.join(HOME, ".local/share/yumi-panel/data"), os.path.join(_HERE, "data"))
     if os.path.isfile(os.path.join(d, "websearch.lst"))),
    os.path.join(HOME, ".local/share/yumi-panel/data"))
USER_LST = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "yumi/panel/websearch.lst")
CACHE_DIR = os.environ.get("YP_WEBSEARCH_CACHE") or os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "yumi-panel")
HISTORY = os.path.join(CACHE_DIR, "websearch-history.json")
HISTORY_MAX = 200
DEFAULT_ENGINE = "google"
DRY = bool(os.environ.get("YP_DRYRUN"))


# ---------- данные (без GTK — работают и в --resolve) ----------
class Engine:
    def __init__(self, icon, key, url, name="", aliases=()):
        self.icon, self.key, self.url = icon or "󰖟", key, url
        self.name = name or key
        self.aliases = [a.lower() for a in aliases if a]

    def search_url(self, query):
        return self.url.replace("%s", urllib.parse.quote(query, safe=""))

    def home_url(self):
        p = urllib.parse.urlsplit(self.url)
        return f"{p.scheme}://{p.netloc}/"


def load_engines():
    """[Engine] в порядке файла; пользовательский файл добавляет новые и заменяет одноимённые."""
    engines = {}
    for path in (os.path.join(DATA_DIR, "websearch.lst"), USER_LST):
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except OSError:
            continue
        for line in lines:
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            p = [x.strip() for x in line.split("|")]
            if len(p) < 3 or not p[1] or not p[2]:
                continue
            aliases = [a.strip() for a in p[4].split(",")] if len(p) > 4 else []
            engines[p[1]] = Engine(p[0], p[1], p[2], p[3] if len(p) > 3 else "", aliases)
    if not engines:
        engines[DEFAULT_ENGINE] = Engine("󰊭", DEFAULT_ENGINE, "https://www.google.com/search?q=%s", "Google", ["g"])
    return list(engines.values())


def find_engine(engines, name):
    """Поисковик по имени: точный ключ → короткое имя → начало ключа/названия → вхождение. Без учёта регистра."""
    n = name.strip().lower()
    if not n:
        return None
    for test in (lambda e: e.key.lower() == n,
                 lambda e: n in e.aliases,
                 lambda e: len(n) >= 2 and (e.key.lower().startswith(n) or e.name.lower().startswith(n)),
                 lambda e: len(n) >= 3 and (n in e.key.lower() or n in e.name.lower())):
        for e in engines:
            if test(e):
                return e
    return None


URL_SCHEME = re.compile(r"^[a-z][a-z0-9+.-]*://\S+$", re.I)
URL_BARE = re.compile(r"^(localhost|[\w-]+(\.[\w-]+)*\.[a-z]{2,}|\d{1,3}(\.\d{1,3}){3})(:\d+)?([/?#]\S*)?$", re.I)


def as_url(text):
    """Адрес, если текст похож на адрес (схема или домен с точкой), иначе None."""
    t = text.strip()
    if not t or " " in t:
        return None
    if URL_SCHEME.match(t) or re.match(r"^(about|file|mailto):", t, re.I):
        return t
    if URL_BARE.match(t):
        return ("http://" if t.lower().startswith(("localhost", "127.", "192.168.", "10.")) else "https://") + t
    return None


def resolve(text, engines, current):
    """Что сделает Enter: (вид, поисковик, запрос, адрес); вид = url | search | home | none."""
    t = text.strip()
    m = re.match(r"^([^\s:/]{1,30}):(?!//)\s*(.*)$", t)
    if m:
        e = find_engine(engines, m.group(1))
        if e and not URL_BARE.match(t):     # «localhost:8080» — адрес, а не поисковик «localhost»
            q = m.group(2).strip()
            return ("search", e, q, e.search_url(q)) if q else ("home", e, "", e.home_url())
    url = as_url(t)
    if url:
        return "url", None, t, url
    if not t:
        return ("home", current, "", current.home_url()) if current else ("none", None, "", "")
    return "search", current, t, current.search_url(t)


def load_history():
    try:
        data = json.load(open(HISTORY, encoding="utf-8"))
        return [h for h in data if isinstance(h, dict) and h.get("q")]
    except (OSError, ValueError):
        return []


def save_history(hist, engine_key, query):
    """Новый запрос — наверх, без повторов (поисковик + текст)."""
    hist = [h for h in hist if not (h.get("e") == engine_key and h.get("q") == query)]
    hist.insert(0, {"e": engine_key, "q": query, "t": int(time.time())})
    hist = hist[:HISTORY_MAX]
    if DRY and not os.environ.get("YP_WEBSEARCH_CACHE"):
        print(f"[dry-run] история: {engine_key}: {query} (не записана)", file=sys.stderr, flush=True)
        return hist
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = HISTORY + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(hist, f, ensure_ascii=False, indent=0)
        os.replace(tmp, HISTORY)
    except OSError as e:
        print("история не записана:", e, file=sys.stderr)
    return hist


