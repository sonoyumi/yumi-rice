"""yumi-tray — свой одноцветный трей для Waybar: StatusNotifierWatcher + Host на Gio D-Bus.

Демон (yumi-tray daemon, сервис systemd --user yumi-tray.service):
  • занимает org.kde.StatusNotifierWatcher (если его уже держит кто-то — работает как Host при нём);
  • следит за значками фоновых программ (StatusNotifierItem), их статусом и названием;
  • пишет список в $XDG_RUNTIME_DIR/yumi-tray/items.json — его читают пилюля (yumi-tray bar) и меню.
Значок программы — один глиф Nerd Font (карта GLYPHS ниже), неизвестные — 󰀻.
Скрытые (уже есть свои пилюли Wi-Fi/Bluetooth): ~/.config/yumi-tray/hidden. Откат: yumi-tray-uninstall
"""
import json
import os
import re
import sys

from gi.repository import Gio, GLib

WATCHER = "org.kde.StatusNotifierWatcher"
WATCHER_PATH = "/StatusNotifierWatcher"
ITEM_IFACE = "org.kde.StatusNotifierItem"
MENU_IFACE = "com.canonical.dbusmenu"

RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "yumi-tray")
STATE = os.path.join(RUNTIME, "items.json")
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "yumi-tray")
HIDDEN_FILE = os.path.join(CONFIG, "hidden")
DEFAULT_HIDDEN = ["nm-applet", "blueman"]      # у бара свои пилюли Wi-Fi и Bluetooth
DRY = bool(os.environ.get("YP_DRYRUN"))

FALLBACK = "󰀻"
# (шаблон по «отпечатку» программы: Id, Title, IconName, подсказка, flatpak-id, имя процесса) → (глиф, название)
GLYPHS = [
    (r"telegram|tdesktop|ayugram|kotatogram", "\uf2c6", "Telegram"),
    (r"vesktop|vencord|discord|webcord|armcord|legcord", "󰙯", None),
    (r"localsend", "󰦉", "LocalSend"),
    (r"steam", "󰓓", "Steam"),
    (r"\bobs\b|obs-studio|obsproject", "󰑋", "OBS Studio"),
    (r"spotify", "󰓇", "Spotify"),
    (r"nm-applet|networkmanager", "󰖩", "Сеть"),
    (r"blueman|bluetooth", "󰂯", "Bluetooth"),
    (r"keepass", "󰌋", "KeePassXC"),
    (r"nextcloud", "󰅟", "Nextcloud"),
    (r"syncthing", "󰓦", "Syncthing"),
    (r"dropbox", "󰇣", "Dropbox"),
    (r"slack", "󰒱", "Slack"),
    (r"element|matrix|nheko|fractal", "󰘨", None),
    (r"signal", "󰭹", "Signal"),
    (r"whatsapp|zapzap", "󰖣", "WhatsApp"),
    (r"skype", "󰒯", "Skype"),
    (r"zoom", "󰕧", "Zoom"),
    (r"thunderbird|evolution|geary|betterbird", "󰇮", None),
    (r"kdeconnect|valent|gsconnect", "󰄜", "KDE Connect"),
    (r"solaar|piper|ratbag", "󰍽", None),
    (r"easyeffects|pulseeffects", "󰺢", "EasyEffects"),
    (r"flameshot|spectacle", "󰄀", None),
    (r"copyq|clipman|cliphist|parcellite", "󰅌", None),
    (r"udiskie", "󰋊", "udiskie"),
    (r"qbittorrent|transmission|deluge|fragments|ktorrent", "󰇚", None),
    (r"nekoray|nekobox|hiddify|v2ray|clash|throne|amnezia|outline|wireguard|openvpn|proton.?vpn|mullvad", "󰦝", None),
    (r"obsidian", "󰠮", "Obsidian"),
    (r"chrom(e|ium)", "󰊯", None),
    (r"firefox|librewolf|zen", "󰈹", None),
    (r"vlc", "󰕼", "VLC"),
    (r"input-remapper|fcitx|ibus|kime", "󰌌", None),
    (r"kdenlive", "󰕧", "Kdenlive"),
    (r"pamac|octopi|update", "󰚰", None),
    (r"jetbrains|toolbox", "󰘦", None),
    (r"code|vscodium", "󰨞", None),
]
GENERIC = re.compile(r"^(chrome_status_icon_\d+|electron|status_icon|tray|systray|qt_.*|statusnotifieritem.*|\d+)$", re.I)


def hidden_list():
    try:
        with open(HIDDEN_FILE) as f:
            return [ln.strip().lower() for ln in f if ln.strip() and not ln.lstrip().startswith("#")]
    except OSError:
        return DEFAULT_HIDDEN


def proc_info(conn, bus):
    """PID владельца шины → (имя процесса, flatpak-id)."""
    try:
        pid = conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                             "GetConnectionUnixProcessID", GLib.Variant("(s)", (bus,)),
                             GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
    except Exception:
        return "", ""
    comm = flat = ""
    try:
        with open(f"/proc/{pid}/comm") as f:
            comm = f.read().strip()
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            exe = os.path.basename(f.read().split(b"\0")[0].decode(errors="replace"))
            if exe and exe != comm:
                comm = f"{comm} {exe}"
        with open(f"/proc/{pid}/cgroup") as f:
            m = re.search(r"app-flatpak-([A-Za-z0-9_.\-]+?)-\d+\.scope", f.read())
            flat = m.group(1) if m else ""
    except OSError:
        pass
    return comm, flat


def describe(props, comm, flat):
    """Свойства SNI → (глиф, название, ключ программы для «без дублей»)."""
    tip = props.get("ToolTip")
    tip_title = tip[2] if isinstance(tip, (tuple, list)) and len(tip) > 2 else ""
    ident = props.get("Id") or ""
    title = props.get("Title") or ""
    fields = [ident, title, props.get("IconName") or "", tip_title, flat, comm]
    finger = " ".join(fields).lower()
    glyph, name = FALLBACK, None
    for pat, g, n in GLYPHS:
        m = re.search(pat, finger)
        if m:
            glyph, name = g, n or (m.group(0).capitalize() if m.group(0).isalpha() else None)
            break
    if not name:
        for cand in (title, tip_title, ident, flat.split(".")[-1] if flat else "", comm.split()[0] if comm else ""):
            if cand and not GENERIC.match(cand):
                name = cand
                break
    name = name or "Программа"
    app_key = (flat or (comm.split()[0] if comm else "") or ident or name).lower()
    return glyph, name, app_key, finger


# ---------- демон: Watcher + Host ----------
WATCHER_XML = """
<node>
  <interface name="org.kde.StatusNotifierWatcher">
    <method name="RegisterStatusNotifierItem"><arg type="s" direction="in" name="service"/></method>
    <method name="RegisterStatusNotifierHost"><arg type="s" direction="in" name="service"/></method>
    <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
    <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
    <property name="ProtocolVersion" type="i" access="read"/>
    <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
    <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
    <signal name="StatusNotifierHostRegistered"/>
    <signal name="StatusNotifierHostUnregistered"/>
  </interface>
</node>"""


class Daemon:
    def __init__(self):
        self.conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.items = {}          # "bus/path" → {...}
        self.order = []
        self.subs = {}           # ключ → id подписки на сигналы элемента
        self.hosts = set()
        self.own_watcher = False
        self.ext_subs = []
        self.write_timer = 0
        os.makedirs(RUNTIME, exist_ok=True)
        self.write()             # сразу пустой список: пилюля не ждёт

        node = Gio.DBusNodeInfo.new_for_xml(WATCHER_XML)
        self.reg_id = self.conn.register_object(WATCHER_PATH, node.interfaces[0], self.on_call, self.on_get, None)
        self.conn.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                                   "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE, self.on_owner, None)
        self.host_name = f"org.kde.StatusNotifierHost-{os.getpid()}"
        Gio.bus_own_name_on_connection(self.conn, self.host_name, Gio.BusNameOwnerFlags.NONE, None, None)
        Gio.bus_own_name_on_connection(self.conn, WATCHER, Gio.BusNameOwnerFlags.NONE,
                                       self.on_acquired, self.on_lost)

    # --- имя Watcher ---
    def on_acquired(self, *_):
        log("Watcher: org.kde.StatusNotifierWatcher — наш")
        self.own_watcher = True
        for s in self.ext_subs:
            self.conn.signal_unsubscribe(s)
        self.ext_subs = []
        self.hosts.add(self.host_name)
        self.emit("StatusNotifierHostRegistered", None)

    def on_lost(self, *_):
        """Watcher держит другая программа (например, встроенный трей Waybar) — работаем Host-ом при нём."""
        if self.own_watcher:
            log("Watcher отобран другой программой")
        self.own_watcher = False
        if self.ext_subs:
            return
        log("Watcher чужой — работаю как Host")
        for sig, cb in (("StatusNotifierItemRegistered", lambda s: self.add(s, None)),
                        ("StatusNotifierItemUnregistered", self.remove_ext)):
            self.ext_subs.append(self.conn.signal_subscribe(
                WATCHER, WATCHER, sig, WATCHER_PATH, None, Gio.DBusSignalFlags.NONE,
                lambda *a, cb=cb: cb(a[5].unpack()[0]), None))
        try:
            self.conn.call_sync(WATCHER, WATCHER_PATH, WATCHER, "RegisterStatusNotifierHost",
                                GLib.Variant("(s)", (self.host_name,)), None, Gio.DBusCallFlags.NONE, 2000, None)
            v = self.conn.call_sync(WATCHER, WATCHER_PATH, "org.freedesktop.DBus.Properties", "Get",
                                    GLib.Variant("(ss)", (WATCHER, "RegisteredStatusNotifierItems")),
                                    None, Gio.DBusCallFlags.NONE, 2000, None).unpack()[0]
            for s in v:
                self.add(s, None)
        except Exception as e:
            log(f"чужой Watcher не ответил: {e}")

    def remove_ext(self, service):
        bus, path = split_service(service, None)
        self.remove(f"{bus}{path}")

    # --- методы Watcher ---
    def on_call(self, conn, sender, path, iface, method, params, inv):
        arg = params.unpack()[0] if params.n_children() else ""
        if method == "RegisterStatusNotifierItem":
            self.add(arg, sender)
            inv.return_value(None)
        elif method == "RegisterStatusNotifierHost":
            self.hosts.add(arg or sender)
            self.emit("StatusNotifierHostRegistered", None)
            inv.return_value(None)
        else:
            inv.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)

    def on_get(self, conn, sender, path, iface, prop):
        if prop == "RegisteredStatusNotifierItems":
            return GLib.Variant("as", [self.items[k]["service"] for k in self.order])
        if prop == "IsStatusNotifierHostRegistered":
            return GLib.Variant("b", True)
        if prop == "ProtocolVersion":
            return GLib.Variant("i", 0)
        return None

    def emit(self, signal, params):
        if not self.own_watcher:
            return
        try:
            self.conn.emit_signal(None, WATCHER_PATH, WATCHER, signal, params)
        except Exception:
            pass

    # --- элементы ---
    def add(self, service, sender):
        bus, path = split_service(service, sender)
        if not bus:
            return
        key = f"{bus}{path}"
        if key in self.items:
            self.refresh(key)
            return
        comm, flat = proc_info(self.conn, bus)
        self.items[key] = {"key": key, "bus": bus, "path": path, "service": f"{bus}{path}",
                           "comm": comm, "flatpak": flat, "props": {}}
        self.order.append(key)
        self.subs[key] = self.conn.signal_subscribe(bus, ITEM_IFACE, None, path, None, Gio.DBusSignalFlags.NONE,
                                                    lambda *_a, k=key: self.refresh(k), None)
        log(f"+ {key} ({comm or '?'} {flat})")
        self.emit("StatusNotifierItemRegistered", GLib.Variant("(s)", (f"{bus}{path}",)))
        self.refresh(key)

    def remove(self, key):
        if key not in self.items:
            return
        it = self.items.pop(key)
        self.order.remove(key)
        sub = self.subs.pop(key, None)
        if sub:
            self.conn.signal_unsubscribe(sub)
        log(f"- {key}")
        self.emit("StatusNotifierItemUnregistered", GLib.Variant("(s)", (it["service"],)))
        self.schedule_write()

    def refresh(self, key):
        it = self.items.get(key)
        if not it:
            return

        def done(conn, res):
            try:
                props = conn.call_finish(res).unpack()[0]
            except Exception as e:
                log(f"  {key}: свойства не прочитаны ({e})")
                if "ServiceUnknown" in str(e) or "UnknownObject" in str(e):
                    self.remove(key)
                return
            if key in self.items:
                self.items[key]["props"] = {k: v for k, v in props.items()
                                            if k in ("Id", "Title", "IconName", "Status", "Menu", "ItemIsMenu",
                                                     "ToolTip", "Category", "AttentionIconName")}
                self.schedule_write()

        self.conn.call(it["bus"], it["path"], "org.freedesktop.DBus.Properties", "GetAll",
                       GLib.Variant("(s)", (ITEM_IFACE,)), GLib.VariantType("(a{sv})"),
                       Gio.DBusCallFlags.NONE, 3000, None, done)

    def on_owner(self, conn, sender, path, iface, sig, params, *_):
        name, old, new = params.unpack()
        if new:
            return
        for key in [k for k, it in self.items.items() if it["bus"] == name]:
            self.remove(key)
        self.hosts.discard(name)

    # --- состояние для пилюли и меню ---
    def schedule_write(self):
        if not self.write_timer:
            self.write_timer = GLib.timeout_add(150, self.write)

    def write(self):
        self.write_timer = 0
        out = []
        for key in self.order:
            it = self.items[key]
            p = it["props"]
            if not p:
                continue
            glyph, name, app_key, finger = describe(p, it["comm"], it["flatpak"])
            out.append({"key": key, "bus": it["bus"], "path": it["path"], "id": p.get("Id", ""),
                        "title": p.get("Title", ""), "icon": p.get("IconName", ""), "status": p.get("Status", ""),
                        "menu": p.get("Menu", ""), "item_is_menu": bool(p.get("ItemIsMenu", False)),
                        "category": p.get("Category", ""), "comm": it["comm"], "flatpak": it["flatpak"],
                        "glyph": glyph, "name": name, "app": app_key, "finger": finger})
        tmp = STATE + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"items": out}, f, ensure_ascii=False, indent=1)
        os.replace(tmp, STATE)
        return False


def split_service(service, sender):
    """RegisterStatusNotifierItem присылает либо имя шины, либо путь объекта (Ayatana/Electron)."""
    if not service:
        return sender, "/StatusNotifierItem"
    if service.startswith("/"):
        return sender, service
    if "/" in service:
        bus, rest = service.split("/", 1)
        return bus, "/" + rest
    return service, "/StatusNotifierItem"


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def run_daemon():
    Daemon()
    GLib.MainLoop().run()


# ---------- чтение состояния ----------
def load_items(all_items=False):
    """Видимые программы: без скрытых, без Passive, одна запись на программу."""
    try:
        with open(STATE) as f:
            items = json.load(f).get("items", [])
    except (OSError, ValueError):
        return []
    if all_items:
        return items
    hidden = hidden_list()
    seen, out = set(), []
    for it in items:
        if it.get("status") == "Passive":
            continue
        if any(h and h in it.get("finger", "") for h in hidden):
            continue
        if it["app"] in seen:
            continue
        seen.add(it["app"])
        out.append(it)
    # сначала программы (мессенджеры, приложения), потом служебные (Hardware, SystemServices)
    rank = {"Communications": 0, "ApplicationStatus": 1}
    out.sort(key=lambda it: rank.get(it.get("category"), 2))
    return out


def bar_json(items):
    if not items:
        return {"text": "", "tooltip": "", "class": "empty"}
    text = " ".join(it["glyph"] for it in items)
    lines = [f"{it['glyph']}  {it['name']}" + ("  · требует внимания" if it["status"] == "NeedsAttention" else "")
             for it in items]
    tip = "Фоновые программы\n" + "\n".join(lines) + "\n\nКлик — список, средний/правый — открыть первую"
    cls = "attention" if any(it["status"] == "NeedsAttention" for it in items) else "active"
    return {"text": text, "tooltip": tip, "class": cls, "alt": str(len(items))}


def run_bar():
    """Бесконечный вывод для custom-модуля Waybar: строка JSON при каждом изменении."""
    if not os.path.exists(STATE):
        os.system("systemctl --user start yumi-tray.service >/dev/null 2>&1")
    last = [None]

    def emit(*_):
        line = json.dumps(bar_json(load_items()), ensure_ascii=False)
        if line != last[0]:
            last[0] = line
            try:
                print(line, flush=True)
            except BrokenPipeError:
                os._exit(0)
        return False

    os.makedirs(RUNTIME, exist_ok=True)
    mons = []
    for d in (RUNTIME, CONFIG):
        os.makedirs(d, exist_ok=True)
        m = Gio.File.new_for_path(d).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
        m.connect("changed", lambda *_: GLib.timeout_add(80, emit))
        mons.append(m)
    emit()
    GLib.timeout_add_seconds(30, lambda: emit() or True)   # подстраховка, если событие файла потерялось
    GLib.MainLoop().run()


# ---------- действия с элементом ----------
def bus_conn():
    return Gio.bus_get_sync(Gio.BusType.SESSION, None)


def activate(item, x=0, y=0, conn=None):
    """Activate (показать окно). Возвращает True, если программа приняла вызов."""
    if DRY:
        log(f"[dry-run] Activate {item['bus']}{item['path']} ({item['name']})")
        return True
    conn = conn or bus_conn()
    try:
        conn.call_sync(item["bus"], item["path"], ITEM_IFACE, "Activate", GLib.Variant("(ii)", (x, y)),
                       None, Gio.DBusCallFlags.NONE, 2000, None)
        return True
    except Exception as e:
        log(f"Activate не принят: {e}")
        return False


def menu_layout(item, parent=0, conn=None):
    """Пункты dbusmenu программы: [(id, свойства, дети)] или None."""
    if not item.get("menu") or item["menu"] == "/":
        return None
    conn = conn or bus_conn()
    try:
        conn.call_sync(item["bus"], item["menu"], MENU_IFACE, "AboutToShow", GLib.Variant("(i)", (parent,)),
                       None, Gio.DBusCallFlags.NONE, 1000, None)
    except Exception:
        pass
    try:
        _rev, layout = conn.call_sync(item["bus"], item["menu"], MENU_IFACE, "GetLayout",
                                      GLib.Variant("(iias)", (parent, -1, [])), None,
                                      Gio.DBusCallFlags.NONE, 2000, None).unpack()
    except Exception as e:
        log(f"GetLayout: {e}")
        return None

    def conv(node):
        nid, props, children = node
        return nid, props, [conv(c) for c in children]

    return conv(layout)[2]


def menu_event(item, nid, conn=None):
    if DRY:
        log(f"[dry-run] dbusmenu Event {item['bus']}{item['menu']} id={nid} clicked ({item['name']})")
        return True
    conn = conn or bus_conn()
    try:
        conn.call_sync(item["bus"], item["menu"], MENU_IFACE, "Event",
                       GLib.Variant("(isvu)", (nid, "clicked", GLib.Variant("i", 0), 0)),
                       None, Gio.DBusCallFlags.NONE, 2000, None)
        return True
    except Exception as e:
        log(f"Event: {e}")
        return False
