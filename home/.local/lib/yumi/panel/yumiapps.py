"""yumiapps — общее для меню программ и файлов: разбор .desktop, нечёткий поиск, частота запусков,
поиск файлов по имени, недавние файлы. Пользуются yumi-menu-launcher и yumi-pult.

Импортировать ПОСЛЕ yumipanel (он перезапускает процесс с layer-shell и выбирает версии GTK).
Частота запусков программ: ~/.cache/yumi-panel/launcher-usage.json — общая у лаунчера и пульта.
Откат: вернуть прежний yumi-menu-launcher (функции были в нём) и удалить этот файл."""
import json
import math
import os
import shutil
import sys
import time

from gi.repository import Gio, GLib

HOME = os.path.expanduser("~")
DRY = bool(os.environ.get("YP_DRYRUN"))           # как yumipanel.DRY: в проверке ничего не пишем
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "yumi-panel")
USAGE = os.path.join(CACHE, "launcher-usage.json")
SKIP_DIRS = ("node_modules", "__pycache__", "site-packages", "venv", "target", "build", "dist")

# язык названий: исходная локаль пользователя, если она не C/POSIX, иначе русский
_lang = (os.environ.get("LANGUAGE") or os.environ.get("YP_ORIG_LC_ALL") or os.environ.get("YP_ORIG_LANG") or "")
_lang = _lang.split(":")[0].split(".")[0]
LOCALES = [l for l in (_lang, _lang.split("_")[0]) if l and l not in ("C", "POSIX")] or ["ru_RU", "ru"]
DESKTOPS = [d.lower() for d in os.environ.get("XDG_CURRENT_DESKTOP", "Hyprland").split(":") if d]


# ---------- программы ----------
def app_dirs():
    """Папки applications по приоритету: сначала ~/.local/share, потом XDG_DATA_DIRS (Flatpak, /usr/share)."""
    data_home = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
    dirs = [data_home] + [d for d in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if d]
    for extra in (os.path.join(data_home, "flatpak/exports/share"), "/var/lib/flatpak/exports/share",
                  "/usr/local/share", "/usr/share"):
        if extra not in dirs:
            dirs.append(extra)
    out, seen = [], set()
    for d in dirs:
        p = os.path.realpath(os.path.join(d, "applications"))
        if p not in seen and os.path.isdir(p):
            seen.add(p)
            out.append(p)
    return out


def kf_str(kf, key, loc=False):
    try:
        if loc:
            for l in LOCALES:
                try:
                    v = kf.get_locale_string("Desktop Entry", key, l)
                    if v:
                        return v
                except GLib.Error:
                    pass
            return kf.get_locale_string("Desktop Entry", key, None)
        return kf.get_string("Desktop Entry", key)
    except GLib.Error:
        return ""


def kf_list(kf, key, loc=False):
    try:
        if loc:
            for l in LOCALES + [None]:
                try:
                    v = kf.get_locale_string_list("Desktop Entry", key, l)
                    if v:
                        return list(v)
                except GLib.Error:
                    pass
            return []
        return list(kf.get_string_list("Desktop Entry", key))
    except GLib.Error:
        return []


def kf_bool(kf, key):
    try:
        return kf.get_boolean("Desktop Entry", key)
    except GLib.Error:
        return False


def exec_name(cmd):
    """«env FOO=1 /usr/bin/firefox %u» → «firefox»."""
    for tok in cmd.split():
        if tok == "env" or "=" in tok or tok.startswith("%"):
            continue
        return os.path.basename(tok.strip('"'))
    return ""


def load_apps():
    """[{id, name, generic, comment, keywords, exec, icon, flatpak, terminal}] — одна запись на ID,
    верхняя по приоритету. Учтены Hidden, NoDisplay, TryExec, OnlyShowIn/NotShowIn."""
    found = {}
    for adir in app_dirs():
        for root, _dirs, files in os.walk(adir):
            for fn in files:
                if not fn.endswith(".desktop"):
                    continue
                path = os.path.join(root, fn)
                did = os.path.relpath(path, adir).replace("/", "-")
                if did in found:
                    continue                      # уже есть выше по приоритету (в т.ч. скрытая — она и закрывает)
                kf = GLib.KeyFile()
                try:
                    kf.load_from_file(path, GLib.KeyFileFlags.NONE)
                except GLib.Error:
                    continue
                found[did] = None                 # занять ID, даже если запись не покажем
                if kf_str(kf, "Type") != "Application" or kf_bool(kf, "Hidden") or kf_bool(kf, "NoDisplay"):
                    continue
                only = [d.lower() for d in kf_list(kf, "OnlyShowIn")]
                nots = [d.lower() for d in kf_list(kf, "NotShowIn")]
                if (only and not set(only) & set(DESKTOPS)) or set(nots) & set(DESKTOPS):
                    continue
                tryexec = kf_str(kf, "TryExec")
                if tryexec and not (os.path.isabs(tryexec) and os.access(tryexec, os.X_OK) or shutil.which(tryexec)):
                    continue
                name = kf_str(kf, "Name", True)
                if not name:
                    continue
                cmd = kf_str(kf, "Exec")
                found[did] = {
                    "id": did, "name": name, "generic": kf_str(kf, "GenericName", True),
                    "comment": kf_str(kf, "Comment", True), "keywords": kf_list(kf, "Keywords", True),
                    "exec": exec_name(cmd), "icon": kf_str(kf, "Icon"),
                    "flatpak": "flatpak/exports" in path, "terminal": kf_bool(kf, "Terminal"),
                }
    apps = [a for a in found.values() if a]
    apps.sort(key=lambda a: a["name"].casefold())
    return apps


def fuzzy(q, text):
    """Очки совпадения q с text (оба в нижнем регистре): 0 — нет совпадения."""
    if not text:
        return 0
    if text == q:
        return 100
    if text.startswith(q):
        return 80
    i = text.find(q)
    if i >= 0:
        return 65 if not text[i - 1].isalnum() else 45          # с начала слова — выше
    # буквы по порядку с пропусками («ffx» → firefox); короче разброс — выше
    pos, first, gaps = 0, -1, 0
    for ch in q:
        j = text.find(ch, pos)
        if j < 0:
            return 0
        if first < 0:
            first = j
        elif j > pos:
            gaps += j - pos
        pos = j + 1
    return max(5, 30 - gaps * 2 - first)


def app_score(a, q):
    """Совпадение по всем словам запроса; у названия вес выше, чем у описания и команды."""
    total = 0
    for w in q.split():
        best = max(fuzzy(w, a["name"].casefold()),
                   fuzzy(w, a["exec"].casefold()) * 0.8,
                   max((fuzzy(w, k.casefold()) for k in a["keywords"]), default=0) * 0.7,
                   fuzzy(w, a["generic"].casefold()) * 0.6,
                   (40 * 0.5 if w in a["comment"].casefold() else 0))
        if best <= 0:
            return 0
        total += best
    return total


# ---------- частота запусков ----------
def load_json_dict(path):
    try:
        with open(path) as f:
            d = json.load(f)
            return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def save_json_dict(path, data):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=0)
        os.replace(tmp, path)
    except OSError:
        pass


def load_usage():
    return load_json_dict(USAGE)


def usage_boost(u):
    """Частота (логарифм числа запусков) + свежесть (за последние сутки/неделю)."""
    if not u:
        return 0
    age = time.time() - u.get("t", 0)
    return 8 * math.log2(1 + u.get("n", 0)) + (6 if age < 86400 else 3 if age < 7 * 86400 else 0)


def bump(table, key):
    """+1 запуск и «сейчас» у записи key в словаре {key: {n, t}}."""
    u = table.setdefault(key, {"n": 0, "t": 0})
    u["n"] = u.get("n", 0) + 1
    u["t"] = int(time.time())
    return u


def save_usage(usage, did):
    if DRY:
        print("[dry-run] счётчик запусков:", did, "->", USAGE, file=sys.stderr, flush=True)
        return
    bump(usage, did)
    save_json_dict(USAGE, usage)


# ---------- файлы ----------
def short(path):
    return "~" + path[len(HOME):] if path == HOME or path.startswith(HOME + "/") else path


def find_cmd(word):
    """Команда поиска по имени для лаунчера (без скрытых и мусорных папок), вывод — по пути в строке."""
    fd = shutil.which("fd") or shutil.which("fdfind")
    if fd:
        cmd = [fd, "--color=never", "--ignore-case", "--fixed-strings", "--max-depth", "8",
               "--absolute-path", "--no-ignore-vcs"]
        for d in SKIP_DIRS:
            cmd += ["--exclude", d]
        return cmd + ["--", word, HOME]
    pat = "*" + "".join("[" + c + "]" if c in "*?[]\\" else c for c in word) + "*"
    cmd = ["nice", "-n", "10", "find", HOME, "-mindepth", "1", "-maxdepth", "8", "(", "-name", ".*"]
    for d in SKIP_DIRS:
        cmd += ["-o", "-name", d]
    return cmd + [")", "-prune", "-o", "-iname", pat, "-print"]


def file_score(path, words):
    name = os.path.basename(path).casefold()
    base = name.rsplit(".", 1)[0] if "." in name[1:] else name
    s = 0
    for w in words:
        if w not in name:
            return None
        s += 100 if base == w else 70 if name.startswith(w) else 45
    return s - path.count("/") * 2


def recent_files(limit=40):
    """Недавно открытые файлы из ~/.local/share/recently-used.xbel (то, что пишут GTK-программы)."""
    bf = GLib.BookmarkFile()
    try:
        bf.load_from_file(os.path.join(HOME, ".local/share/recently-used.xbel"))
    except GLib.Error:
        return []
    items = []
    for uri in bf.get_uris():
        if not uri.startswith("file://"):
            continue
        try:
            path = GLib.filename_from_uri(uri)[0]
            when = bf.get_visited_date_time(uri).to_unix()
        except Exception:
            continue
        if os.path.exists(path) and "/." not in path[len(HOME):]:
            items.append((when, path))
    items.sort(reverse=True)
    return [p for _w, p in items[:limit]]


def file_gicon(path, is_dir):
    if is_dir:
        return Gio.ThemedIcon.new("folder")
    ctype, _uncertain = Gio.content_type_guess(path, None)
    return Gio.content_type_get_icon(ctype)


def default_app_id(path):
    """ID .desktop программы по умолчанию для файла (по MIME), или None."""
    try:
        info = Gio.File.new_for_path(path).query_info("standard::content-type", Gio.FileQueryInfoFlags.NONE, None)
        app = Gio.AppInfo.get_default_for_type(info.get_content_type(), False)
        return app.get_id() if app else None
    except GLib.Error:
        return None
