# Ядро «Пульта» без GTK: часть бывшего ~/.local/bin/yumi-pult (16.10 — в архиве yumi-archive/legacy-menus).
#!/usr/bin/env python3
"""yumi-pult — «Пульт» Yumi (как Spotlight/Raycast): одно окно по центру, поиск сразу по всему.
Две колонки: слева поле поиска, режимы и список, справа — предпросмотр выбранного и кнопки действий.
  yumi-pult [--center]   открыть / закрыть (повторный вызов закрывает; бинд SUPER+Space)
  yumi-pult --close      закрыть

Что ищет:
  программы   все .desktop (Hidden/NoDisplay/TryExec учтены — ~/.local/lib/yumi/panel/yumiapps.py, общий
              с yumi-menu-launcher; частота запусков у них общая: ~/.cache/yumi-panel/launcher-usage.json)
  команды     Yumi: режим работы, VPN, подсветка клавиатуры, ☕, скриншот, Waybar, Доктор, звук, меню,
              обои и коллекции обоев (Enter — включить коллекцию и поставить случайные из неё,
              Ctrl+Enter — открыть папку; `yumi-wallpaper collection`)
  файлы       fd по домашней папке в фоне (предыдущий поиск отменяется), кроме .cache, корзины,
              node_modules, .git, .venv, __pycache__ и т.п. (FD_EXCLUDE). Русские слова ищутся по основе
              («обложка» найдёт «Обложки»). Enter — открыть, Ctrl+Enter — показать в Dolphin
  счёт        «2+2*3», «=2^10», «sqrt(2)» — Enter копирует результат
  эмодзи      «:кот» (база yumi-menu-picker), Enter — скопировать, Ctrl+Enter — вставить
  веб         «?запрос» (поисковики yumi-menu-websearch; «?aw hyprland» — сразу Arch Wiki)
Пустой ввод: сверху недавние (журнал пульта ~/.local/state/yumi/pult-history.json: частота + давность),
ниже частые программы и недавние файлы (recently-used.xbel).
Клавиши: ↑/↓ PgUp/PgDn — выбор, Enter — действие, Ctrl+Enter (или Shift+Enter) — второе действие,
Tab / Shift+Tab — режим (Всё → Программы → Команды → Файлы → Эмодзи → Веб), Esc — очистить, повторно — закрыть.
Ввод в другой раскладке и транслитом тоже находит («вол» → volume, «ащч» → fox).

Проверка (ничего не меняет):
  YP_DRYRUN=1         команды только печатаются в stderr, окно не закрывается, журнал не пишется
  YP_SEARCH=текст     сразу ввести текст;  YP_TYPE=текст — «набрать» по букве (замер отклика)
  YP_SELECT=file|cmd|app|…  выбрать первую строку этого вида (для снимков предпросмотра)
  YP_KEYBOARD=none, YP_STAY=1, YP_MONITOR=<выход> — как у всех меню yumi-panel
  YP_TEST=enter|ctrl-enter  через 2,5 с «нажать» Enter / Ctrl+Enter на выбранной строке
  YP_TIMING=1         замеры в stderr: загрузка, первый кадр, отклик на ввод
  YP_PRINT_SHAPE=1    печатать рамку меню «[shape] x y w h» при каждом её изменении
  YUMI_PULT_ID=x      отдельный экземпляр (org.yumi.panel.pultx) — проверка рядом с настоящим пультом
Откат: удалить этот файл (и ~/.local/state/yumi/pult-history.json); бинд SUPER+Space — из binds.lua."""
import ast
import hashlib
import json
import math
import operator
import os
import subprocess
import sys
import threading
import time
import urllib.parse
import warnings
from concurrent.futures import ThreadPoolExecutor
warnings.filterwarnings("ignore", category=DeprecationWarning)
sys.dont_write_bytecode = True                  # не оставлять __pycache__ рядом с ~/.local/bin

sys.path.insert(0, os.path.expanduser("~/.local/lib/yumi/panel"))
import yumipanel as yp  # noqa: E402  (сам перезапускает процесс с layer-shell)
from yumipanel import Gtk, Gdk, GLib, Gio, Pango, Layer  # noqa: E402
import gi  # noqa: E402
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf  # noqa: E402
import yumiapps as ya  # noqa: E402  (разбор .desktop, поиск, частота запусков — общие с лаунчером)

HOME = ya.HOME
DRY = yp.DRY
BIN = os.path.join(HOME, ".local/bin")
WALLS = os.path.join(HOME, "Pictures/Wallpapers")
DATA = os.path.join(HOME, ".local/share/yumi-panel/data")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local/state")), "yumi")
HISTORY = os.path.join(STATE, "pult-history.json")
WALL_COLL = os.path.join(STATE, "wall-collection")              # пишет `yumi-wallpaper collection`
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
DOCTOR = os.path.join(BIN, "yumi-doctor")
DOCTOR_CACHE = os.path.join(RUNTIME, "yumi/doctor.json")        # общий с меню «Система»
DOCTOR_FRESH = 600                                              # кэш доктора моложе 10 мин — не перепроверять

# размеры — логические px встроенного экрана; на MSI каркас умножает на UI-коэффициент (monitors.conf).
# Окно НЕ меняет размер между состояниями: список и предпросмотр постоянной высоты.
WIDTH = 860
HEAD_H = 64
LEFT_W = 470
LIST_H = 430
PREV_W = WIDTH - LEFT_W - 28 - 14 - 4       # минус поля тела и промежуток колонок
IMG_H = 200                                 # миниатюра картинки в предпросмотре

FD = "/usr/bin/fd"
FD_EXCLUDE = (".cache", ".local/share/Trash", "node_modules", ".git", ".venv", "__pycache__",
              ".local/share/flatpak", ".vscode/extensions", ".local/share/icons")
FD_LIMIT = 1500                             # fd останавливается после стольких совпадений
FD_MIN = {"all": 3, "files": 2}             # с какой длины запроса искать файлы
EXT_IMG = (".jpg", ".jpeg", ".png", ".gif", ".webp")

MODES = [("all", "󰍉", "Всё"), ("apps", "󰀻", "Программы"), ("cmds", "󰘳", "Команды"),
         ("files", "󰈞", "Файлы"), ("emoji", "󰞅", "Эмодзи"), ("web", "󰖟", "Веб")]
MODE_PH = {"all": "Программы, команды, файлы, счёт…", "apps": "Найти программу…",
           "cmds": "Команда Yumi…", "files": "Имя файла или папки…", "emoji": "Эмодзи: сердце, кот, огонь…",
           "web": "Что искать в интернете…"}
LIMITS = {"all": dict(cmds=6, apps=6, files=5), "apps": dict(apps=80), "cmds": dict(cmds=60), "files": dict(files=60)}


def b(name):
    return os.path.join(BIN, name)


def sh(*cmd):
    return yp.run(*cmd, timeout=2).strip()


def plural(n, one, few, many):
    n = abs(n) % 100
    if 10 < n < 20:
        return many
    return one if n % 10 == 1 else few if 2 <= n % 10 <= 4 else many


def ago(t):
    d = time.time() - t
    if d < 90:
        return "сейчас"
    if d < 3600:
        return f"{int(d // 60)} мин"
    if d < 86400:
        return f"{int(d // 3600)} ч"
    return "вчера" if d < 2 * 86400 else f"{int(d // 86400)} дн"


def cap(s):
    return s[:1].upper() + s[1:]


def read_text(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


# ---------- состояние системы (для подписей; только чтение) ----------
def read_states():
    """Медленные запросы (~10–35 мс каждый) — параллельно."""
    with ThreadPoolExecutor(4) as ex:
        fut = {k: ex.submit(sh, *cmd) for k, cmd in (("wf", (b("yumi-workflow"), "get")),
                                                      ("wf_list", (b("yumi-workflow"), "list")),
                                                      ("vpn", (b("yumi-vpn"), "state")),
                                                      ("caf", (b("yumi-caffeine"), "state")))}
        st = {k: f.result() for k, f in fut.items()}
    st["wf"] = st["wf"] or "01-default"
    st["wf_list"] = [l for l in st["wf_list"].split("\n") if l] or [st["wf"]]
    st["caf"] = st["caf"] == "true"
    try:
        with open(os.path.join(HOME, ".config/yumi/kb-light.json")) as f:
            st["kbd"] = json.load(f)
    except (OSError, ValueError):
        st["kbd"] = None
    wall = os.path.realpath(os.path.join(HOME, ".cache/yumi/theme/wall.set"))
    st["wall"] = wall
    st["wall_coll"] = os.path.relpath(wall, WALLS).split(os.sep)[0] if wall.startswith(WALLS + "/") else ""
    coll = read_text(WALL_COLL)
    st["coll"] = coll if coll and os.path.isdir(os.path.join(WALLS, coll)) else ""
    return st


def collections():
    try:
        return sorted(d for d in os.listdir(WALLS) if os.path.isdir(os.path.join(WALLS, d)) and not d.startswith("."))
    except OSError:
        return []


def coll_walls(name):
    out = []
    for root, dirs, files in os.walk(os.path.join(WALLS, name)):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "logo"]
        out += [os.path.join(root, f) for f in files if f.lower().endswith(EXT_IMG[:4]) and not f.startswith(".")]
    return sorted(out)


def nice_coll(c):
    return c.split(" ", 1)[1] if c[:2].isdigit() and " " in c else c


def yumi_commands(st):
    """[dict(id, icon, title, sub, kw, act, alt, alt_label, on)] — act/alt: команда (tuple)."""
    wf, coll = st["wf"], st["coll"]
    kbd_on = (st["kbd"] or {}).get("on", True)
    yw = b("yumi-wallpaper")
    cmds = [
        dict(id="wf-next", icon="󰕮", title="Режим работы: следующий", sub=f"сейчас {wf}",
             kw="workflow режим next следующий работа", act=(b("yumi-workflow"), "next"),
             alt=(b("yumi-workflow"), "prev"), alt_label="предыдущий"),
        dict(id="vpn", icon="󰦝", title=f"VPN: {'выключить' if st['vpn'] else 'включить'}",
             sub=st["vpn"] or "выключен", kw="vpn впн warp proton wireguard туннель",
             act=(b("yumi-vpn"), "toggle"), alt=(b("yumi-menu-vpn"), "--center"), alt_label="меню VPN",
             on=bool(st["vpn"])),
        dict(id="kbd", icon="󰌌", title=f"Подсветка клавиатуры: {'выключить' if kbd_on else 'включить'}",
             sub=(f"{st['kbd'].get('brightness', 100)}% · {'из обоев' if st['kbd'].get('source') == 'wall' else 'свой цвет'}"
                  if st["kbd"] else "OpenRGB"),
             kw="подсветка клавиатура keyboard light rgb openrgb", act=(b("yumi-kb-light"), "toggle"),
             alt=(b("yumi-kb-light"), "up"), alt_label="ярче +10 %", on=kbd_on),
        dict(id="caf", icon="󰅶", title=f"☕ Кофеин: {'выключить' if st['caf'] else 'не засыпать'}",
             sub="включён — экран не гаснет" if st["caf"] else "выключен",
             kw="кофеин caffeine кофе не засыпать сон idle", act=(b("yumi-caffeine"), "toggle"), on=st["caf"]),
        dict(id="shot", icon="󰹑", title="Скриншот области", sub="выделить область или окно",
             kw="скриншот снимок экрана screenshot print", act=(b("yumi-screenshot"), "s"),
             alt=(b("yumi-screenshot"), "p"), alt_label="весь экран"),
        dict(id="ocr", icon="󰈙", title="Скриншот: распознать текст", sub="OCR → буфер обмена",
             kw="скриншот ocr текст распознать", act=(b("yumi-screenshot"), "sc")),
        dict(id="waybar", icon="󰑓", title="Перезапустить бар", sub="служба yumi-quickshell.service",
             kw="бар панель quickshell перезапуск restart", act=(b("yumi-bar-restart"),)),
        dict(id="doctor", icon="󰓙", title="Доктор — проверка системы", sub="службы, конфиг, обои, диск, снимки",
             kw="доктор doctor проверка диагностика здоровье",
             act=("kitty", "--title", "Доктор Yumi-Rice", "--hold", "-e", DOCTOR, "-v"), act_label="подробно",
             alt=("kitty", "--title", "Доктор Yumi-Rice", "--hold", "-e", DOCTOR, "--fix"),
             alt_label="безопасно починить"),
        dict(id="mute", icon="󰝟", title="Звук: выключить / включить", sub="динамики по умолчанию",
             kw="звук громкость volume волюм mute тишина", act=(b("yumi-volume"), "-o", "m"),
             alt=(b("yumi-menu-sound"), "--center"), alt_label="меню звука"),
        dict(id="wall-next", icon="󰸉", title="Обои: следующие",
             sub=f"в коллекции «{coll}»" if coll else "по всем коллекциям",
             kw="обои wallpaper следующие next", act=(yw, "next"), alt=(yw, "prev"), alt_label="предыдущие"),
        dict(id="wall-rnd", icon="󰒝", title="Обои: случайные",
             sub=f"из коллекции «{coll}»" if coll else "из всех коллекций",
             kw="обои wallpaper случайные random", act=(yw, "random")),
        dict(id="m-wall", icon="󰋩", title="Выбрать обои", sub="меню обоев (миниатюры)",
             kw="обои wallpaper выбрать меню", act=(b("yumi-menu-wallpaper"), "--center")),
        dict(id="m-control", icon="󰒓", title="Центр управления", sub="меню yumi-menu-control",
             kw="центр управления control настройки", act=(b("yumi-menu-control"), "--center")),
        dict(id="m-clip", icon="󰅌", title="Буфер обмена", sub="история копирования",
             kw="буфер обмена clipboard история", act=(b("yumi-menu-clipboard"), "--center")),
        dict(id="m-power", icon="󰐥", title="Питание", sub="блокировка, сон, перезагрузка",
             kw="питание выключить перезагрузка сон power", act=(b("yumi-menu-power"), "--center")),
    ]
    if coll:
        cmds.append(dict(id="coll-off", icon="󰉓", title="Обои: по всем коллекциям",
                         sub=f"сейчас только «{coll}»", kw="обои коллекция все выключить off сбросить",
                         act=(yw, "collection", "off")))
    for name in st["wf_list"]:
        cmds.append(dict(id="wf-" + name, icon="󰕮", title=f"Режим работы: {name}",
                         sub="текущий" if name == wf else "переключить", kw=f"режим workflow {name}",
                         act=(b("yumi-workflow"), "set", name), on=name == wf))
    for c in collections():
        cmds.append(dict(id="coll-" + c, icon="󰉏", title=f"Обои: коллекция «{nice_coll(c)}»",
                         sub=("включена · " if c == coll else "") + "случайные обои из неё",
                         kw=f"обои коллекция wallpaper collection {c}", coll=c,
                         act=("sh", "-c", '"$0" collection "$1" >/dev/null && exec "$0" random', yw, c),
                         act_label="включить", alt=("uwsm", "app", "--", "xdg-open", os.path.join(WALLS, c)),
                         alt_label="открыть папку", on=c == coll))
    for c in cmds:
        c.setdefault("alt", None)
        c.setdefault("alt_label", "")
        c.setdefault("act_label", "выполнить")
        c.setdefault("on", False)
    return cmds


# ---------- русский ввод: транслит, «не та раскладка», основа слова ----------
_TR = dict(zip("абвгдезийклмнопрстуфхцы", "abvgdeziyklmnoprstufhcy"))
_TR.update({"ё": "e", "ж": "zh", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ь": "", "э": "e", "ю": "yu", "я": "ya"})
_RU = "йцукенгшщзхъфывапролджэячсмитьбю"
_EN = "qwertyuiop[]asdfghjkl;'zxcvbnm,."
_RU_END = "аяоеёыиуюьй"


def stem(w):
    """Грубая основа русского слова: «обложка» → «обложк» (найдёт «Обложки»)."""
    if len(w) >= 5 and w[-1] in _RU_END and any("а" <= c <= "я" for c in w):
        w = w[:-1]
        if len(w) >= 5 and w[-1] in _RU_END:
            w = w[:-1]
    return w


def variants(q):
    """Запрос + основа + транслит («вол» → «vol») + другая раскладка («ащч» → «fox», «ghbdtn» → «привет»)."""
    out = [q, " ".join(stem(w) for w in q.split())]
    if any(c in _TR for c in q):
        out.append("".join(_TR.get(c, c) for c in q))
        out.append("".join(_EN[_RU.index(c)] if c in _RU else c for c in q))
    elif any(c in _EN for c in q):
        out.append("".join(_RU[_EN.index(c)] if c in _EN else c for c in q))
    return [v for i, v in enumerate(out) if v and v not in out[:i]]


# ---------- калькулятор ----------
_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
        ast.Pow: operator.pow, ast.Mod: operator.mod, ast.FloorDiv: operator.floordiv,
        ast.USub: operator.neg, ast.UAdd: operator.pos}
_FN = {"sqrt": math.sqrt, "sin": math.sin, "cos": math.cos, "tan": math.tan, "log": math.log10, "ln": math.log,
       "abs": abs, "round": round}
_CONST = {"pi": math.pi, "e": math.e, "пи": math.pi}


def calc(q):
    """«2+2*3», «=2^10», «sqrt(2)». Строка результата или None (не выражение)."""
    s = q.strip()
    explicit = s.startswith("=")
    s = s.lstrip("=").replace(",", ".").replace("^", "**").replace("×", "*").replace("÷", "/").replace("√", "sqrt")
    if not s or (not explicit and not any(o in s for o in "+-*/%(")):
        return None
    if not explicit and not any(ch.isdigit() for ch in s):
        return None

    def ev(n):
        if isinstance(n, ast.Expression):
            return ev(n.body)
        if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)) and not isinstance(n.value, bool):
            return n.value
        if isinstance(n, ast.BinOp) and type(n.op) in _OPS:
            a, c = ev(n.left), ev(n.right)
            if isinstance(n.op, ast.Pow) and abs(c) > 1000:
                raise ValueError
            return _OPS[type(n.op)](a, c)
        if isinstance(n, ast.UnaryOp) and type(n.op) in _OPS:
            return _OPS[type(n.op)](ev(n.operand))
        if isinstance(n, ast.Name) and n.id in _CONST:
            return _CONST[n.id]
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in _FN and len(n.args) == 1:
            return _FN[n.func.id](ev(n.args[0]))
        raise ValueError
    try:
        v = ev(ast.parse(s, mode="eval"))
    except Exception:
        return None
    if isinstance(v, float):
        if v != v or v in (float("inf"), float("-inf")):
            return None
        v = round(v, 10)
        if v.is_integer():
            v = int(v)
    return f"{v:,}".replace(",", " ") if isinstance(v, int) else f"{v:.10g}"


# ---------- эмодзи и веб ----------
def load_emoji():
    out = []
    try:
        with open(os.path.join(DATA, "emoji.db"), encoding="utf-8") as f:
            for line in f:
                ch, _, rest = line.rstrip("\n").partition(" ")
                if ch:
                    out.append((ch, rest))
    except OSError:
        pass
    return out


RU_EMOJI = {"сердце": "heart", "кот": "cat", "кошка": "cat", "огонь": "fire", "смех": "laugh", "улыбка": "smile",
            "звезда": "star", "солнце": "sun", "луна": "moon", "цветок": "flower", "собака": "dog", "кофе": "coffee",
            "музыка": "music", "слёзы": "tears", "плач": "cry", "палец": "thumbs", "ок": "ok", "дом": "house"}


def load_engines():
    """[(icon, key, url, name, [алиасы])] — как в yumi-menu-websearch."""
    out = []
    for path in (os.path.join(DATA, "websearch.lst"), os.path.join(HOME, ".config/yumi/panel/websearch.lst")):
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except OSError:
            continue
        for line in lines:
            if line.startswith("#") or "|" not in line:
                continue
            p = [x.strip() for x in line.split("|")]
            if len(p) >= 3:
                out.append(dict(icon=p[0] or "󰖟", key=p[1], url=p[2], name=(p[3] if len(p) > 3 and p[3] else p[1]),
                                alias=[a.strip().casefold() for a in (p[4] if len(p) > 4 else "").split(",") if a.strip()]
                                + [p[1].casefold()]))
    return out or [dict(icon="󰖟", key="google", url="https://www.google.com/search?q=%s", name="Google", alias=[])]


# ---------- журнал запусков пульта ----------
class History:
    """{ключ: {n, t, title}}; ключ — «cmd:vpn», «app:kitty.desktop», «file:/путь», «emoji:🐱»."""

    def __init__(self):
        self.data = ya.load_json_dict(HISTORY)

    def add(self, key, title):
        if DRY:
            print("[dry-run] журнал пульта:", key, "->", HISTORY, file=sys.stderr, flush=True)
            return
        u = ya.bump(self.data, key)
        u["title"] = title
        if len(self.data) > 300:                          # старые и редкие — вон
            keep = sorted(self.data.items(), key=lambda kv: -ya.usage_boost(kv[1]))[:200]
            self.data = dict(keep)
        ya.save_json_dict(HISTORY, self.data)

    def top(self, prefixes=None, limit=8):
        items = [(k, u) for k, u in self.data.items() if not prefixes or k.split(":", 1)[0] in prefixes]
        items.sort(key=lambda kv: (-ya.usage_boost(kv[1]), -kv[1].get("t", 0)))
        return items[:limit]


# ---------- миниатюры ----------
def thumb_path(path):
    """Готовая миниатюра freedesktop (~/.cache/thumbnails), если её уже сделал Dolphin/GTK."""
    uri = Gio.File.new_for_path(path).get_uri()
    h = hashlib.md5(uri.encode()).hexdigest()
    for size in ("x-large", "large", "normal"):
        p = os.path.join(HOME, ".cache/thumbnails", size, h + ".png")
        if os.path.exists(p):
            try:
                if os.path.getmtime(p) >= os.path.getmtime(path) - 1:
                    return p
            except OSError:
                pass
    return None


def load_picture_async(path, w, h, cancel, done):
    """Картинка, уменьшенная под w×h (с сохранением пропорций), без блокировки окна → done(texture)."""
    src = thumb_path(path) or path
    f = Gio.File.new_for_path(src)

    def on_pixbuf(_s, res):
        try:
            pb = GdkPixbuf.Pixbuf.new_from_stream_finish(res)
            pb = pb.apply_embedded_orientation() or pb
            done(Gdk.Texture.new_for_pixbuf(pb))
        except GLib.Error:
            pass

    def on_open(_f, res):
        try:
            stream = f.read_finish(res)
        except GLib.Error:
            return
        GdkPixbuf.Pixbuf.new_from_stream_at_scale_async(stream, w, h, True, cancel, on_pixbuf)
    f.read_async(GLib.PRIORITY_DEFAULT, cancel, on_open)


