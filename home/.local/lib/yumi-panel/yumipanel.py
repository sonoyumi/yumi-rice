"""yumi-panel — общий каркас всплывающих меню на GTK4 + layer-shell (замена rofi-panel).

Что даёт каждому меню:
  • шапку из текущих обоев (~/.cache/hyde/wall.thmb, как в rofi style_10) с названием поверх;
  • цвета из обоев — тот же wallbash-файл, что у yumi-player (меняются на лету);
  • масштаб под монитор (MSI DP-1 ×0.8), окно под курсором у бара или по центру;
  • одно окно на меню (повторный вызов закрывает), Esc и уход мыши закрывают.

Меню — отдельный скрипт: создаёт PanelApp(id, title, icon, build), где build(panel, body) наполняет body.
Стиль: ~/.config/yumi-panel/style.css. Откат: yumi-panel-uninstall
"""
import os
import sys

LAYER_LIB = "/usr/lib/libgtk4-layer-shell.so"


def bootstrap():
    """layer-shell для GTK4 должен загрузиться раньше libwayland-client; всё — в UTF-8."""
    if LAYER_LIB not in os.environ.get("LD_PRELOAD", "") and os.path.exists(LAYER_LIB):
        env = dict(os.environ, LD_PRELOAD=(LAYER_LIB + " " + os.environ.get("LD_PRELOAD", "")).strip(),
                   LANG="C.UTF-8", LC_ALL="C.UTF-8",
                   YP_ORIG_LANG=os.environ.get("LANG", ""), YP_ORIG_LC_ALL=os.environ.get("LC_ALL", ""))
        os.execve(sys.executable, [sys.executable, os.path.abspath(sys.argv[0])] + sys.argv[1:], env)


bootstrap()

import json  # noqa: E402
import re  # noqa: E402
import subprocess  # noqa: E402

import gi  # noqa: E402
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, Gio, GLib, Pango  # noqa: E402,F401
from gi.repository import Gtk4LayerShell as Layer  # noqa: E402
import cairo  # noqa: E402  (input region окна)

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
COLORS = os.path.join(CONFIG, "yumi-player/colors.css")       # общий с плеером файл wallbash
ACCENT = os.path.join(CONFIG, "yumi-player/accent.css")       # живой акцент из обоев (yumi-accent)
STYLE = os.path.join(CONFIG, "yumi-panel/style.css")
WALL_DIR = os.path.join(HOME, ".cache/hyde")
WALL = os.path.join(WALL_DIR, "wall.thmb")

FALLBACK_COLORS = """
@define-color yp-bg      rgba(20,12,38,0.85);
@define-color yp-border  rgba(120,101,163,1);
@define-color yp-fg      rgba(255,255,255,1);
@define-color yp-fg2     rgba(220,204,255,1);
@define-color yp-accent  rgba(177,154,230,1);
@define-color yp-btn     rgba(73,58,107,0.55);
@define-color yp-hover   rgba(104,87,143,0.8);
@define-color yp-on-acc  rgba(20,12,38,1);
"""

MONITOR_SCALE = {"DP-1": 0.8}     # как у экрана блокировки, плеера и rofi
WIDTH = 380                         # ширина меню на встроенном экране, логические px
HEADER_H = 118                      # высота шапки из обоев
BAR_GAP = 8                         # отступ под баром
FAR = 160                           # меню закрывается, если курсор ушёл дальше этого (логич. px) от окна — как у rofi-panel


# дочерним программам — без нашего LD_PRELOAD (layer-shell роняет GTK3: Solaar, pavucontrol…)
CHILD_ENV = {k: v for k, v in os.environ.items() if k not in ("LD_PRELOAD", "LANG", "LC_ALL")}
for _k in ("LANG", "LC_ALL"):                      # детям — исходная локаль пользователя, не C.UTF-8 каркаса
    if os.environ.get("YP_ORIG_" + _k):
        CHILD_ENV[_k] = os.environ["YP_ORIG_" + _k]

DRY = bool(os.environ.get("YP_DRYRUN"))   # режим проверки: команды, меняющие систему, не выполняются


def do(*cmd, timeout=15, background=False):
    """Команда, МЕНЯЮЩАЯ систему (подключить, удалить, переключить). В YP_DRYRUN=1 только печатается.
    Возвращает (ok, вывод). background=True — запустить отдельно и не ждать."""
    if DRY:
        print("[dry-run]", " ".join(str(c) for c in cmd), file=sys.stderr, flush=True)
        return True, ""
    if background:
        spawn(*cmd)
        return True, ""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=CHILD_ENV)
        return r.returncode == 0, (r.stdout + r.stderr).strip()
    except Exception as e:
        return False, str(e)


def hypr(cmd):
    """Запрос к Hyprland через его сокет (быстро, без процесса hyprctl). cmd — например «j/cursorpos»."""
    import socket
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "hypr",
                        os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""), ".socket.sock")
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as c:
            c.settimeout(0.3)
            c.connect(path)
            c.sendall(cmd.encode())
            buf = b""
            while True:
                chunk = c.recv(65536)
                if not chunk:
                    break
                buf += chunk
        return json.loads(buf.decode() or "null")
    except Exception:
        return None


def run(*cmd, timeout=2):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=CHILD_ENV).stdout
    except Exception:
        return ""


def spawn(*cmd):
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, env=CHILD_ENV)


class Panel(Gtk.ApplicationWindow):
    def __init__(self, app, mode):
        super().__init__(application=app, title=app.title)
        self.app, self.mode = app, mode
        self.k = 1.0
        self.cursor_x = None
        self.entered = False
        self.close_timer = 0
        self.css_timer = 0
        self.add_css_class("yp-panel")
        # Окно (layer-surface) НЕ меняет размер никогда: по высоте оно растянуто на всю свободную область
        # монитора (якоря сверху и снизу), рамка меню прижата к верху (бар) или по центру, остальное прозрачно,
        # щелчки там проходят насквозь (input region = рамка). Тогда Hyprland анимирует только открытие и
        # закрытие (как у плеера): в Hyprland изменение размера слоя анимируется той же анимацией layersIn
        # и при смене страниц рвалось, оставляя сиреневый прямоугольник.
        self.shape = None
        self.connect("notify::child", self._align_child)
        self.busy = 0                    # >0 — идёт операция (сопряжение, подключение): не закрывать при уходе мыши
        self.extra_css = []              # дополнительный CSS меню (add_css)
        self.setup_layer()
        self.build()
        self.setup_css()
        self.watch_wall()

        keys = Gtk.EventControllerKey(propagation_phase=Gtk.PropagationPhase.CAPTURE)   # Esc раньше полей
        keys.connect("key-pressed", self.on_key)
        self.add_controller(keys)
        motion = Gtk.EventControllerMotion()
        motion.connect("enter", self.on_enter)
        motion.connect("leave", self.on_leave)
        self.add_controller(motion)
        # закрытие, когда курсор ушёл далеко (FAR) от окна — ТОЛЬКО у меню из Waybar (--bar).
        # Меню по бинду (--center) от курсора не закрываются: Esc, повтор бинда или выбор пункта.
        self.armed = (mode == "bar")
        self.rect = None
        self.rect_age = 0
        if mode == "bar" and not os.environ.get("YP_STAY"):
            GLib.timeout_add(250, self._watch_cursor)

    # ---------- окно ----------
    def setup_layer(self):
        Layer.init_for_window(self)
        Layer.set_namespace(self, "yumi-panel")
        Layer.set_layer(self, Layer.Layer.OVERLAY)
        # Как rofi: меню сразу берёт клавиатуру (стрелки, Enter, Esc). YP_KEYBOARD=none — не брать (тесты агентов),
        # YP_KEYBOARD=ondemand — только после клика внутрь
        kbd = {"none": Layer.KeyboardMode.NONE, "ondemand": Layer.KeyboardMode.ON_DEMAND}.get(
            os.environ.get("YP_KEYBOARD", ""), Layer.KeyboardMode.EXCLUSIVE)
        Layer.set_keyboard_mode(self, kbd)
        mon, geo = self.pick_monitor()
        if mon:
            Layer.set_monitor(self, mon)
            self.k = MONITOR_SCALE.get(mon.get_connector(), 1.0)
        Layer.set_anchor(self, Layer.Edge.TOP, True)          # высоту окна задаёт Hyprland — она постоянна
        Layer.set_anchor(self, Layer.Edge.BOTTOM, True)
        Layer.set_margin(self, Layer.Edge.BOTTOM, BAR_GAP)
        if self.mode == "bar":
            Layer.set_margin(self, Layer.Edge.TOP, BAR_GAP)
            if geo and self.cursor_x is not None:      # по горизонтали — под курсором, не вылезая за край
                w = round(WIDTH * self.k)
                left = min(max(self.cursor_x - geo["x"] - w // 2, 12), geo["w"] - w - 12)
                Layer.set_anchor(self, Layer.Edge.LEFT, True)
                Layer.set_margin(self, Layer.Edge.LEFT, int(left))

    def pick_monitor(self):
        """--bar: монитор под курсором; --center: монитор в фокусе."""
        try:
            mons = json.loads(run("hyprctl", "-j", "monitors") or "[]")
            cur = next((m for m in mons if m.get("focused")), None)
            if self.mode == "bar":
                x, y = (int(float(v)) for v in run("hyprctl", "cursorpos").split(","))
                if os.environ.get("YP_CURSOR"):          # для показа/проверки: «курсор» в этой точке
                    x, y = (int(v) for v in os.environ["YP_CURSOR"].split(","))
                self.cursor_x = x
                for m in mons:
                    if m["x"] <= x < m["x"] + m["width"] / m["scale"] and m["y"] <= y < m["y"] + m["height"] / m["scale"]:
                        cur = m
            name = os.environ.get("YP_MONITOR", cur["name"] if cur else None)
            cur = next((m for m in mons if m["name"] == name), cur)
            geo = cur and {"x": cur["x"], "w": round(cur["width"] / cur["scale"])}
            mlist = Gdk.Display.get_default().get_monitors()
            for i in range(mlist.get_n_items()):
                if mlist.get_item(i).get_connector() == name:
                    return mlist.get_item(i), geo
        except Exception:
            pass
        return None, None

    def build(self):
        # без анимаций: у слоя в Hyprland no_anim (иначе при смене размера окна остаётся сиреневый
        # прямоугольник), а анимации GTK внутри layer-surface на этой системе идут рывками
        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["yp-frame"])
        frame.set_overflow(Gtk.Overflow.HIDDEN)
        frame.set_size_request(round(WIDTH * self.k), -1)
        self.set_child(frame)
        self.frame = frame

        # шапка: обои + затемнение снизу + название
        head = Gtk.Overlay(css_classes=["yp-head"])
        head.set_overflow(Gtk.Overflow.HIDDEN)
        # размер шапки задаёт пустая коробка; картинка обоев не измеряется, только заполняет её
        sizer = Gtk.Box()
        sizer.set_size_request(round(WIDTH * self.k), round(HEADER_H * self.k))
        head.set_child(sizer)
        self.wall = Gtk.Picture(content_fit=Gtk.ContentFit.COVER, can_shrink=True, css_classes=["yp-wall"])
        head.add_overlay(self.wall)
        head.set_measure_overlay(self.wall, False)
        head.add_overlay(Gtk.Box(css_classes=["yp-head-shade"]))
        titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.END, css_classes=["yp-head-text"])
        self.title_l = Gtk.Label(label=f"{self.app.icon}  {self.app.title}", xalign=0, css_classes=["yp-head-title"],
                                 ellipsize=Pango.EllipsizeMode.END, max_width_chars=1)
        self.subtitle_l = Gtk.Label(xalign=0, css_classes=["yp-head-sub"], ellipsize=Pango.EllipsizeMode.END,
                                    max_width_chars=1)
        titles.append(self.title_l)
        titles.append(self.subtitle_l)
        head.add_overlay(titles)
        self.back_btn = Gtk.Button(label="󰁍", tooltip_text="Назад", css_classes=["yp-back"],
                                   halign=Gtk.Align.START, valign=Gtk.Align.START, visible=False)
        self.back_btn.connect("clicked", lambda *_: self.pop())
        head.add_overlay(self.back_btn)
        frame.append(head)
        self.load_wall()

        # страницы меню: главная + подстраницы (пароль Wi-Fi, устройство Bluetooth…) с анимацией сдвига
        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.NONE,
                               transition_duration=0, vhomogeneous=False, interpolate_size=False)
        self.pages = []          # [(имя, заголовок, подзаголовок)]
        self.body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, css_classes=["yp-body"])
        self.stack.add_named(self.body, "main")
        frame.append(self.stack)
        self.app.build(self, self.body)

    # ---------- подстраницы ----------
    def push(self, title, widget, subtitle="", on_leave=None):
        """Открыть подстраницу: widget — содержимое; в шапке заголовок и кнопка «назад».
        on_leave() вызывается при уходе со страницы (остановить сканирование и т.п.)."""
        name = f"p{len(self.pages)}"
        self.pages.append((name, self.title_l.get_label(), self.subtitle_l.get_label(), on_leave))
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, css_classes=["yp-body"])
        page.append(widget)
        self.stack.add_named(page, name)
        self.stack.set_visible_child_name(name)
        self.title_l.set_label(title)
        self.set_subtitle(subtitle)
        self.back_btn.set_visible(True)
        self.set_focus(None)       # случайный пробел/Enter не должен нажать кнопку новой страницы

    def pop(self):
        if not self.pages:
            return
        name, title, sub, on_leave = self.pages.pop()
        if on_leave:
            try:
                on_leave()
            except Exception:
                pass
        prev = self.pages[-1][0] if self.pages else "main"
        self.stack.set_visible_child_name(prev)
        self.title_l.set_label(title)
        self.set_subtitle(sub)
        self.back_btn.set_visible(bool(self.pages))
        old = self.stack.get_child_by_name(name)
        GLib.timeout_add(300, lambda: (self.stack.remove(old), False)[1])   # после анимации

    def toast(self, text, error=False, hold=0):
        """Короткая строка состояния в подзаголовке шапки («Подключаюсь…», «Неверный пароль»).
        hold — секунд, в течение которых живые обновления не перетирают её (см. set_subtitle(live=True))."""
        self.set_subtitle(text)
        (self.subtitle_l.add_css_class if error else self.subtitle_l.remove_css_class)("error")
        self.toast_until = GLib.get_monotonic_time() + int(hold * 1_000_000)

    def set_subtitle(self, text, live=False):
        """live=True — обновление по таймеру/событию: не перетирает свежий toast(hold=…)."""
        if live and GLib.get_monotonic_time() < getattr(self, "toast_until", 0):
            return
        self.subtitle_l.remove_css_class("error")
        self.subtitle_l.set_label(text or "")
        self.subtitle_l.set_visible(bool(text))

    def add_css(self, css):
        """Свой CSS меню (цвета @yp-*); px/pt масштабируются под монитор как основной стиль."""
        self.extra_css.append(css)
        if getattr(self, "css", None):     # из build() провайдера ещё нет — подхватится в setup_css()
            self.load_css()

    # ---------- обои и цвета ----------
    def load_wall(self):
        try:
            self.wall.set_filename(os.path.realpath(WALL))
        except Exception:
            pass

    def watch_wall(self):
        self.wall_mon = Gio.File.new_for_path(WALL_DIR).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
        self.wall_mon.connect("changed", lambda _m, f, o, _e: (
            "wall.thmb" in {x.get_basename() for x in (f, o) if x}) and GLib.timeout_add(300, lambda: self.load_wall() or False))

    def setup_css(self):
        self.css = Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), self.css,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)
        self.load_css()
        self.css_mons = []
        for d in {os.path.dirname(COLORS), os.path.dirname(STYLE)}:
            os.makedirs(d, exist_ok=True)
            m = Gio.File.new_for_path(d).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
            m.connect("changed", self.on_conf_changed)
            self.css_mons.append(m)

    def load_css(self):
        parts = []
        for path, fallback in ((COLORS, FALLBACK_COLORS), (ACCENT, ""), (STYLE, "")):
            try:
                with open(path) as f:
                    parts.append(f.read())
            except OSError:
                parts.append(fallback)
        parts += getattr(self, "extra_css", [])
        css = "\n".join(parts)
        if self.k != 1.0:
            css = re.sub(r"(\d+(?:\.\d+)?)(px|pt)\b", lambda m: f"{float(m.group(1)) * self.k:.2f}{m.group(2)}", css)
        self.css.load_from_string(css)

    def on_conf_changed(self, _mon, f, other, _ev):
        if {x.get_basename() for x in (f, other) if x} & {"colors.css", "accent.css", "style.css"}:
            if self.css_timer:
                GLib.source_remove(self.css_timer)
            self.css_timer = GLib.timeout_add(200, self._reload_css)

    def _reload_css(self):
        self.css_timer = 0
        self.load_css()
        return False

    # ---------- закрытие ----------
    def on_key(self, _c, keyval, *_):
        if getattr(self, "on_key_hook", None) and self.on_key_hook(keyval):
            return True              # меню обработало клавишу само (горячие клавиши, отмена отсчёта)
        name = Gdk.keyval_name(keyval) or ""
        if name in ("Up", "Down", "Left", "Right", "Tab", "ISO_Left_Tab") and self.get_focus() is None:
            # при открытии фокуса нет (случайный Enter ничего не нажмёт) — первая стрелка выделяет первый пункт
            page = self.stack.get_visible_child()
            direction = Gtk.DirectionType.TAB_BACKWARD if name in ("Up", "ISO_Left_Tab") else Gtk.DirectionType.TAB_FORWARD
            if page is not None and page.child_focus(direction):
                return True
        if Gdk.keyval_name(keyval) == "Escape":
            if self.pages:
                self.pop()
            else:
                self.app.quit()
            return True
        return False

    def _align_child(self, *_):
        """Рамку (или обёртку меню вокруг неё) — к верху окна у меню из бара, по центру у меню по бинду."""
        child = self.get_child()
        if child is not None:
            child.set_valign(Gtk.Align.START if self.mode == "bar" else Gtk.Align.CENTER)
            child.set_halign(Gtk.Align.CENTER)

    def do_realize(self):
        Gtk.ApplicationWindow.do_realize(self)
        self.get_surface().get_frame_clock().connect("after-paint", self._update_shape)

    def _update_shape(self, *_):
        """Щелчки принимает только рамка: прозрачная часть окна пропускает их к окнам под меню."""
        child = self.get_child()
        ok, b = child.compute_bounds(self) if child is not None else (False, None)
        if not ok:
            return
        shape = (int(b.get_x()), int(b.get_y()), int(b.get_width() + 0.999), int(b.get_height() + 0.999))
        if shape != self.shape:
            self.shape = shape
            self.get_surface().set_input_region(cairo.Region(cairo.RectangleInt(*shape)))

    def on_enter(self, *_):
        self.entered = True
        self.armed = True

    def on_leave(self, *_):
        pass                                # близко от окна не закрываем — см. _watch_cursor

    def _watch_cursor(self):
        dbg = os.environ.get("YP_DEBUG")
        if not self.get_mapped():
            dbg and print("[watch] не отображено", file=sys.stderr, flush=True)
            return True
        self.rect_age -= 1
        if self.rect is None or self.rect_age <= 0:     # положение окна (меняется при смене страниц) — раз в ~1 с
            self.rect_age = 2
            layers = hypr("j/layers") or {}
            for mon in layers.values():
                for lv in mon.get("levels", {}).values():
                    for l in lv:
                        if l.get("pid") == os.getpid() and l.get("namespace") == "yumi-panel":
                            if self.shape:          # окно во всю высоту — считаем по самой рамке
                                sx, sy, sw, sh = self.shape
                                self.rect = (l["x"] + sx, l["y"] + sy, sw, sh)
                            else:
                                self.rect = (l["x"], l["y"], l["w"], l["h"])
        cur = hypr("j/cursorpos")
        if not self.rect or not cur:
            return True
        x, y, w, h = self.rect
        cx, cy = cur.get("x", 0), cur.get("y", 0)
        dbg and print(f"[watch] окно {self.rect} курсор {cx},{cy} armed={self.armed}", file=sys.stderr, flush=True)
        if x <= cx <= x + w and y <= cy <= y + h:
            self.armed = True
            return True
        far = FAR * self.k
        if self.armed and not self.busy and not (x - far <= cx <= x + w + far and y - far <= cy <= y + h + far):
            self.app.quit()
            return False
        return True


# ---------- готовые элементы меню ----------
def section(text):
    return Gtk.Label(label=text, xalign=0, css_classes=["yp-section"])


def icon_button(icon, tooltip, cb, classes=()):
    b = Gtk.Button(label=icon, tooltip_text=tooltip, css_classes=["yp-icon-btn", *classes])
    b.connect("clicked", cb)
    return b


def row_button(icon, text, cb, active=False, meta=""):
    """Строка-«таблетка»: значок + текст (+ подпись справа: сигнал, батарея), активная подсвечена акцентом."""
    box = Gtk.Box(spacing=12)
    box.append(Gtk.Label(label=icon, css_classes=["yp-row-icon"]))
    lbl = Gtk.Label(label=text, xalign=0, hexpand=True, ellipsize=Pango.EllipsizeMode.END)
    box.append(lbl)
    if meta:
        box.append(Gtk.Label(label=meta, css_classes=["yp-row-meta"]))
    if active:
        box.append(Gtk.Label(label="󰄬", css_classes=["yp-row-check"]))
    b = Gtk.Button(child=box, css_classes=["yp-row"] + (["active"] if active else []))
    b.connect("clicked", cb)
    return b


def slider_row(icon_btn, on_change):
    """Значок-кнопка + ползунок 0–100 + процент. Возвращает (box, scale, label)."""
    box = Gtk.Box(spacing=10, css_classes=["yp-slider-row"])
    scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, draw_value=False, hexpand=True,
                      valign=Gtk.Align.CENTER, css_classes=["yp-slider"], focusable=False)
    scale.set_range(0, 100)
    scale.set_increments(5, 10)
    scale.connect("change-value", lambda _s, _t, v: on_change(min(max(v, 0), 100)) or False)
    lbl = Gtk.Label(width_chars=4, xalign=1, css_classes=["yp-pct"])
    for w in (icon_btn, scale, lbl):
        box.append(w)
    return box, scale, lbl


def toggle_row(icon, text, active, on_toggle):
    """Строка с переключателем (Wi-Fi вкл/выкл, Bluetooth…). on_toggle(state). Возвращает (box, switch)."""
    box = Gtk.Box(spacing=12, css_classes=["yp-row", "yp-toggle-row"])
    box.append(Gtk.Label(label=icon, css_classes=["yp-row-icon"]))
    box.append(Gtk.Label(label=text, xalign=0, hexpand=True))
    sw = Gtk.Switch(active=active, valign=Gtk.Align.CENTER, css_classes=["yp-switch"])
    sw.connect("state-set", lambda _w, st: on_toggle(st) or False)
    box.append(sw)
    return box, sw


def password_entry(placeholder="Пароль", text=""):
    """Поле пароля с «глазиком» (показать/скрыть)."""
    e = Gtk.PasswordEntry(show_peek_icon=True, placeholder_text=placeholder, hexpand=True, css_classes=["yp-entry"])
    if text:
        e.set_text(text)
    return e


def info_row(key, value, copy=False):
    """Строка «параметр — значение» для страниц статуса; copy=True — клик копирует значение."""
    box = Gtk.Box(spacing=12, css_classes=["yp-info"])
    box.append(Gtk.Label(label=key, xalign=0, css_classes=["yp-info-key"]))
    val = Gtk.Label(label=value or "—", xalign=1, hexpand=True, selectable=True,
                    ellipsize=Pango.EllipsizeMode.MIDDLE, css_classes=["yp-info-val"])
    box.append(val)
    if copy and value:
        b = Gtk.Button(label="󰆏", tooltip_text="Скопировать", css_classes=["yp-icon-btn", "yp-small"])
        b.connect("clicked", lambda *_: Gdk.Display.get_default().get_clipboard().set(value))
        box.append(b)
    box.value = val            # обновлять так: row.value.set_label("…")
    return box


def action_button(text, cb, kind="primary"):
    """Кнопка действия: kind = primary (цвет обоев) | danger (красная) | plain."""
    b = Gtk.Button(label=text, css_classes=["yp-action", kind])
    b.connect("clicked", cb)
    return b


def spinner_row(text):
    box = Gtk.Box(spacing=10, halign=Gtk.Align.CENTER, css_classes=["yp-spin-row"])
    sp = Gtk.Spinner(spinning=True)
    box.append(sp)
    box.append(Gtk.Label(label=text, css_classes=["yp-pct"]))
    return box


def revealer(child, shown=False):
    """Плавное появление/скрытие блока (строки списка, поле пароля)."""
    r = Gtk.Revealer(transition_type=Gtk.RevealerTransitionType.SLIDE_DOWN, transition_duration=0,   # NONE оставляет место под скрытый блок
                     reveal_child=shown)
    r.set_child(child)
    return r


def hint(text):
    """Приглушённая подсказка с переносом строк."""
    return Gtk.Label(label=text, xalign=0, wrap=True, max_width_chars=1, hexpand=True, css_classes=["yp-hint"])


def confirm_box(question, on_yes, yes_text="Удалить", on_no=None):
    """Подтверждение опасного действия на той же странице: вопрос + [Отмена] [Удалить]."""
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, css_classes=["yp-confirm"])
    box.append(Gtk.Label(label=question, wrap=True, max_width_chars=1, xalign=0, css_classes=["yp-confirm-q"]))
    btns = Gtk.Box(spacing=8, homogeneous=True)
    btns.append(action_button("Отмена", lambda *_: on_no and on_no(), "plain"))
    btns.append(action_button(yes_text, lambda *_: on_yes(), "danger-solid"))
    box.append(btns)
    return box


def code_display(code):
    """Крупный код (сопряжение Bluetooth, PIN)."""
    return Gtk.Label(label=code, css_classes=["yp-code"], selectable=True)


class Step(Gtk.Box):
    """Шаг процесса: ожидание → спиннер → готово / ошибка (set_state('wait'|'run'|'ok'|'err'))."""
    ICON = {"wait": "󰄱", "ok": "󰄬", "err": "󰅖"}

    def __init__(self, text):
        super().__init__(spacing=10, css_classes=["yp-step"])
        self.stack = Gtk.Stack()
        self.icon = Gtk.Label(label=self.ICON["wait"])
        self.spin = Gtk.Spinner(spinning=True)
        self.stack.add_named(self.icon, "icon")
        self.stack.add_named(self.spin, "spin")
        self.append(self.stack)
        self.append(Gtk.Label(label=text, xalign=0, hexpand=True))
        self.set_state("wait")

    def set_state(self, st):
        for c in ("wait", "run", "ok", "err"):
            self.remove_css_class(c)
        self.add_css_class(st)
        if st == "run":
            self.stack.set_visible_child_name("spin")
        else:
            self.icon.set_label(self.ICON.get(st, "󰄱"))
            self.stack.set_visible_child_name("icon")


class Segmented(Gtk.Box):
    """2–4 плитки в ряд с одной активной (профиль питания, режим…). on_select(key).
    items = [(key, icon, text, enabled)]"""

    def __init__(self, items, active, on_select):
        super().__init__(spacing=8, homogeneous=True, css_classes=["yp-seg"])
        self.btns = {}
        for key, icon, text, enabled in items:
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            box.append(Gtk.Label(label=icon, css_classes=["yp-seg-icon"]))
            box.append(Gtk.Label(label=text, css_classes=["yp-seg-text"], ellipsize=Pango.EllipsizeMode.END))
            b = Gtk.Button(child=box, sensitive=enabled, css_classes=["yp-seg-btn"])
            b.connect("clicked", lambda *_, k=key: (self.set_active(k), on_select(k)))
            self.append(b)
            self.btns[key] = b
        self.set_active(active)

    def set_active(self, key):
        for k, b in self.btns.items():
            (b.add_css_class if k == key else b.remove_css_class)("active")


def countdown(seconds, text, on_done, on_cancel):
    """Обратный отсчёт перед опасным действием: «<text> через N…» + [Отмена] [Сейчас]. Возвращает (box, cancel)."""
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, css_classes=["yp-confirm"])
    lbl = Gtk.Label(css_classes=["yp-confirm-q"])
    bar = Gtk.ProgressBar(fraction=1.0, css_classes=["yp-countdown"])
    btns = Gtk.Box(spacing=8, homogeneous=True)
    state = {"left": seconds, "timer": 0}

    def stop():
        if state["timer"]:
            GLib.source_remove(state["timer"])
            state["timer"] = 0

    def tick():
        state["left"] -= 0.1
        bar.set_fraction(max(state["left"], 0) / seconds)
        lbl.set_label(f"{text} через {max(int(state['left'] + 0.99), 0)}…")
        if state["left"] <= 0:
            state["timer"] = 0
            on_done()
            return False
        return True

    btns.append(action_button("Отмена", lambda *_: (stop(), on_cancel()), "plain"))
    btns.append(action_button("Сейчас", lambda *_: (stop(), on_done()), "danger-solid"))
    for w in (lbl, bar, btns):
        box.append(w)
    lbl.set_label(f"{text} через {seconds}…")
    state["timer"] = GLib.timeout_add(100, tick)
    return box, stop


def hotkey_char(keyval):
    """Буква нажатой клавиши в латинской раскладке (Д→l, Ы→s …), чтобы горячие клавиши работали в RU/UA."""
    ch = chr(Gdk.keyval_to_unicode(keyval) or 0).lower()
    ru = "йцукенгшщзхъфывапролджэячсмитьбю"
    en = "qwertyuiop[]asdfghjkl;'zxcvbnm,."
    return en[ru.index(ch)] if ch and ch in ru else ch


class PanelApp(Gtk.Application):
    def __init__(self, app_id, title, icon, build):
        super().__init__(application_id=app_id, flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        self.title, self.icon, self.build = title, icon, build
        self.win = None

    def do_shutdown(self):
        # меню закрыто — пилюли Waybar сразу показывают новое состояние (☕ 15, Wi-Fi 16, Bluetooth 17)
        if not DRY:
            for sig in (15, 16, 17):
                subprocess.run(["pkill", f"-RTMIN+{sig}", "-x", "waybar"], env=CHILD_ENV,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        Gtk.Application.do_shutdown(self)

    def do_command_line(self, cmdline):
        args = cmdline.get_arguments()[1:]
        if self.win is not None or "--close" in args:
            self.quit()        # повторный вызов (клик по пилюле, бинд) закрывает открытое меню
            return 0
        self.win = Panel(self, "center" if "--center" in args else "bar")
        self.win.present()
        GLib.idle_add(lambda: self.win.set_focus(None) or False)   # без фокуса на первой кнопке
        return 0
