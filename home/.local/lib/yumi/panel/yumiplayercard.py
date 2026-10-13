"""yumiplayercard — карточка музыкального плеера (GTK4 + Playerctl) для «Центра управления» и меню.

Карточка сама следит за плеерами MPRIS и обновляется; громкости нет (она у центра).

    import yumiplayercard as ypc
    ypc.install_css(k=panel.k)                 # один раз на дисплей: цвета @yp-* + playercard.css
    card = ypc.PlayerCard(art_size=72, show_source=True, compact=False, autohide=True)
    card.connect("visibility-changed", lambda _c, has: ...)   # или on_visibility=callback
    ...
    card.destroy_card()                        # при закрытии окна (вызывается и само по «destroy»)

Конструктор: PlayerCard(art_size=72, show_source=True, compact=False, autohide=False, on_visibility=None, glow=False)
  art_size     — сторона обложки, логич. px
  show_source  — строка источника (SoundCloud / YouTube Music / YouTube / Zen / mpv…)
  compact      — одна строка: обложка | название, исполнитель, тонкий прогресс | ⏮ ⏯ ⏭ (без времени и источника)
  autohide     — карточка сама скрывается (set_visible(False)), когда плееров нет
  on_visibility(has_player: bool) — колбэк при смене «есть плеер / нет»
  glow         — «дыхание» фона карточки акцентными тонами на басах (только если у карточки есть свой фон)
«Живой» индикатор у названия (5 скруглённых столбиков, оттенки @yp-fg2 → @yp-accent → @yp-border) — всегда;
уровни звука — $XDG_RUNTIME_DIR/yumi-eq.levels (пишет модуль yumi-eq в Waybar), 60 кадров/с, пока играет
и карточка на экране; цвета пересчитываются при смене обоев (вместе с CSS). Откат: yumi-uninstall cc-eq
Свойства и сигналы:
  has-player (bool, только чтение)           — есть ли что показать
  сигнал "visibility-changed" (bool)          — то же событием
  сигнал "player-changed" (str)               — сменился активный плеер (instance или "")
Методы: destroy_card() — отключить всё (вызывается и само, когда окно карточки закрыто/уничтожено), refresh(), players() — список показываемых плееров (без playerctld и дублей),
  player — текущий Playerctl.Player или None.

CSS-классы (все с префиксом ypc-):
  .ypc-card          корневой Gtk.Box; плюс .ypc-compact в компактном виде, .ypc-playing / .ypc-paused
  .ypc-top           строка «обложка + текст»
  .ypc-art           рамка обложки (скругление, overflow hidden)
  .ypc-art-img       сама картинка (Gtk.Image)
  .ypc-art-ph        значок-заглушка, когда обложки нет
  .ypc-info          колонка текста
  .ypc-source        строка источника (значок + имя), внутри .ypc-source-icon и .ypc-source-name
  .ypc-switch        переключатель плееров (коробка точек), .ypc-dot — точка, .ypc-dot.active — текущий
  .ypc-title         название (одна строка, многоточие)
  .ypc-artist        исполнитель
  .ypc-progress      Gtk.Scale прогресса (trough / highlight / slider внутри)
  .ypc-bottom        строка «время + кнопки»
  .ypc-time          время «1:23 / 6:24»
  .ypc-controls      коробка кнопок
  .ypc-btn           кнопки ⏮ ⏭ (и ⏯), .ypc-prev / .ypc-next
  .ypc-play          крупная кнопка ⏯ в кружке
Стиль по умолчанию: ~/.config/yumi/panel/playercard.css
"""
import hashlib
import math
import os
import threading
import time
import urllib.request
from urllib.parse import urlparse

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Playerctl", "2.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("Graphene", "1.0")
gi.require_version("Gsk", "4.0")
from gi.repository import Gtk, Gdk, Gio, GLib, GObject, GdkPixbuf, Graphene, Gsk, Pango, Playerctl  # noqa: E402

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
COLORS = os.path.join(CONFIG, "yumi/player/colors.css")
ACCENT = os.path.join(CONFIG, "yumi/player/accent.css")
STYLE = os.path.join(CONFIG, "yumi/panel/playercard.css")
ART_CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "yumi-playercard")

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

PLAYING = Playerctl.PlaybackStatus.PLAYING
IGNORED = {"playerctld"}                  # прокси-дубль настоящего плеера

# источник по адресу трека: (часть хоста, значок, название)
URL_SOURCES = (("music.youtube.com", "󰗃", "YouTube Music"), ("soundcloud.com", "\uf1be", "SoundCloud"),
               ("youtube.com", "󰗃", "YouTube"), ("youtu.be", "󰗃", "YouTube"),
               ("open.spotify.com", "󰓇", "Spotify"), ("twitch.tv", "󰕃", "Twitch"),
               ("bandcamp.com", "󰝚", "Bandcamp"), ("vk.com", "󰝚", "VK"))
# источник по имени плеера / Identity из MPRIS
PLAYER_SOURCES = (("zen", "󰖟", "Zen"), ("firefox", "󰈹", "Firefox"), ("chromium", "\uf268", "Chromium"),
                  ("chrome", "\uf268", "Chrome"), ("brave", "󰖟", "Brave"), ("spotify", "󰓇", "Spotify"),
                  ("mpv", "󰐹", "mpv"), ("vlc", "󰕼", "VLC"), ("pear", "󰗃", "YouTube Music"),
                  ("youtube-music", "󰗃", "YouTube Music"))


def fmt_time(us):
    s = max(0, int(us // 1_000_000))
    h, m, s = s // 3600, s % 3600 // 60, s % 60
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def source_of(url, player_name, identity=""):
    """(значок, название) источника: сначала по xesam:url, потом по Identity / имени плеера."""
    host = (urlparse(url).hostname or "").lower() if url and "://" in url else ""
    for part, icon, name in URL_SOURCES:
        if host == part or host.endswith("." + part):
            return icon, name
    for key in (identity.lower(), player_name.lower()):
        for part, icon, name in PLAYER_SOURCES:
            if key and part in key:
                return icon, name
    return "󰝚", identity or player_name or "Плеер"


# ---------- стиль ----------
_css = {}          # дисплей → (провайдер, монитор файлов, k)
_css_listeners = []   # колбэки «стиль перечитан» (карточки пересчитывают цвета индикатора)


def css_text(k=1.0):
    """Цвета @yp-* (wallbash + акцент) и playercard.css одной строкой; px/pt × k (масштаб монитора)."""
    import re
    parts = []
    for path, fallback in ((COLORS, FALLBACK_COLORS), (ACCENT, ""), (STYLE, "")):
        try:
            with open(path) as f:
                parts.append(f.read())
        except OSError:
            parts.append(fallback)
    css = "\n".join(parts)
    if k != 1.0:
        css = re.sub(r"(\d+(?:\.\d+)?)(px|pt)\b", lambda m: f"{float(m.group(1)) * k:.2f}{m.group(2)}", css)
    return css


def install_css(display=None, k=1.0, priority=Gtk.STYLE_PROVIDER_PRIORITY_USER):
    """Базовый стиль карточки на дисплей (один раз), перечитывается при смене обоев/файла.
    Приоритет USER — ниже, чем у yumi-panel (USER+1): стиль центра перекрывает базовый."""
    display = display or Gdk.Display.get_default()
    if display in _css:
        return _css[display][0]
    prov = Gtk.CssProvider()
    prov.load_from_string(css_text(k))
    Gtk.StyleContext.add_provider_for_display(display, prov, priority)
    mons, timer = [], [0]

    def reload():
        timer[0] = 0
        prov.load_from_string(css_text(k))
        for cb in list(_css_listeners):
            cb()
        return False

    def changed(_m, f, o, _e):
        if {x.get_basename() for x in (f, o) if x} & {"colors.css", "accent.css", "playercard.css"}:
            if timer[0]:
                GLib.source_remove(timer[0])
            timer[0] = GLib.timeout_add(200, reload)

    for d in {os.path.dirname(COLORS), os.path.dirname(STYLE)}:
        if os.path.isdir(d):
            m = Gio.File.new_for_path(d).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
            m.connect("changed", changed)
            mons.append(m)
    _css[display] = (prov, mons, k)
    return prov


# ---------- «живой» индикатор: те же уровни, что у пилюли Waybar и yumi-player ----------
LEVELS = os.path.join(GLib.get_user_runtime_dir(), "yumi-eq.levels")


class LevelsReader:
    """Файл уровней держим открытым и читаем pread'ом (без open/close на кадр); свежесть по mtime —
    раз в ~0.25 с. Файл пропал (cava остановлена) — переоткрываем не чаще раза в секунду."""
    def __init__(self, path=None):
        self.path = path or LEVELS
        self.fd, self.fresh, self.checked, self.retry = -1, False, 0.0, 0.0

    def read(self, now):
        if self.fd < 0:
            if now < self.retry:
                return None
            try:
                self.fd = os.open(self.path, os.O_RDONLY | os.O_CLOEXEC)
            except OSError:
                self.retry = now + 1.0
                return None
        try:
            if now - self.checked > 0.25:
                self.checked = now
                st = os.fstat(self.fd)
                self.fresh = st.st_nlink > 0 and time.time() - st.st_mtime < 1.0
                if not self.fresh:
                    os.close(self.fd)
                    self.fd, self.retry = -1, now + 1.0
                    return None
            return os.pread(self.fd, 32, 0) if self.fresh else None
        except OSError:
            self.fd = -1
            return None


def rgba_mix(a, b, t):
    c = Gdk.RGBA()
    c.red, c.green, c.blue = (a.red + (b.red - a.red) * t, a.green + (b.green - a.green) * t,
                              a.blue + (b.blue - a.blue) * t)
    c.alpha = a.alpha + (b.alpha - a.alpha) * t
    return c


class EqIsland(Gtk.Widget):
    """Пять мягких скруглённых столбиков у названия (как музыка в Dynamic Island)."""
    def __init__(self, card, k):
        super().__init__(valign=Gtk.Align.CENTER, halign=Gtk.Align.END)
        self.card = card
        self.set_size_request(round(24 * k), round(14 * k))

    def do_snapshot(self, snap):
        w, h = self.get_width(), self.get_height()
        c = self.card
        n, fade = 5, c.eq_fade
        bw = max(2.0, w / (n * 1.75))
        gap = (w - n * bw) / (n - 1)
        for i in range(n):
            bh = max(bw, (h - 1) * (0.2 + 0.8 * c.eq_bars[i]) * fade + bw * (1 - fade))
            rect = Graphene.Rect().init(i * (bw + gap), (h - bh) / 2, bw, bh)
            rr = Gsk.RoundedRect()
            rr.init_from_rect(rect, bw / 2)
            snap.push_rounded_clip(rr)
            col = c.eq_cols[i].copy()
            col.alpha = 0.45 + 0.55 * fade
            snap.append_color(col, rect)
            snap.pop()


# ---------- обложка: всё тяжёлое — в фоновом потоке ----------
def _art_file(url):
    return os.path.join(ART_CACHE, hashlib.sha1(url.encode()).hexdigest()[:20])


def _fetch_art(url, px):
    """Байты обложки → квадратный GdkPixbuf px×px (или None). Выполняется в потоке."""
    try:
        if url.startswith("file://"):
            with open(GLib.filename_from_uri(url)[0], "rb") as f:
                data = f.read()
        elif url.startswith("http"):
            path = _art_file(url)
            if os.path.exists(path):
                with open(path, "rb") as f:
                    data = f.read()
            else:
                data = urllib.request.urlopen(url, timeout=6).read()
                os.makedirs(ART_CACHE, exist_ok=True)
                tmp = f"{path}.{os.getpid()}.tmp"
                with open(tmp, "wb") as f:
                    f.write(data)
                os.replace(tmp, path)
        else:
            return None
        loader = GdkPixbuf.PixbufLoader()
        loader.write(data)
        loader.close()
        pb = loader.get_pixbuf()
        w, h = pb.get_width(), pb.get_height()
        side = min(w, h)
        sub = pb.new_subpixbuf((w - side) // 2, (h - side) // 2, side, side)
        return sub.scale_simple(px, px, GdkPixbuf.InterpType.BILINEAR)
    except Exception:
        return None


def _texture(pb):
    fmt = Gdk.MemoryFormat.R8G8B8A8 if pb.get_has_alpha() else Gdk.MemoryFormat.R8G8B8
    return Gdk.MemoryTexture.new(pb.get_width(), pb.get_height(), fmt, pb.read_pixel_bytes(), pb.get_rowstride())


class PlayerCard(Gtk.Box):
    __gtype_name__ = "YumiPlayerCard"
    __gsignals__ = {
        "visibility-changed": (GObject.SignalFlags.RUN_LAST, None, (bool,)),
        "player-changed": (GObject.SignalFlags.RUN_LAST, None, (str,)),
    }

    def __init__(self, art_size=72, show_source=True, compact=False, autohide=False, on_visibility=None,
                 glow=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0 if compact else 10,
                         css_classes=["ypc-card"] + (["ypc-compact"] if compact else []))
        self.art_size, self.show_source, self.compact = art_size, show_source, compact
        self.autohide, self.on_visibility = autohide, on_visibility
        self._has_player = False
        self.player = None
        self.pinned = None               # instance, выбранный переключателем
        self.last_active = {}            # instance → время последнего события
        self.identity = {}               # instance → Identity из MPRIS (Zen / Mozilla Firefox …)
        self.handlers = {}               # instance → (player, [id сигналов])
        self.art_key = None
        self.art_cache = {}
        self.length = 0
        self.seek_pending = None
        self.seek_block_until = 0
        self.dragging = False
        self.drag_since = 0
        self.scroll_acc = 0.0
        self.tick_timer = self.update_timer = self.seek_timer = 0
        self.tick_n = 0
        self.dead = False
        self.bus = None
        # индикатор и дыхание фона
        disp = Gdk.Display.get_default()
        self.eq_k = _css[disp][2] if disp in _css else 1.0
        self.eq_glow_on = glow
        self.eq_playing = False
        self.eq_fade = 0.0
        self.eq_bars = [0.0] * 5
        self.eq_targets = [0.0] * 5
        self.eq_bass = self.eq_bass_t = 0.0
        self.eq_time = 0.0
        self.eq_last = self.eq_read_at = 0
        self.eq_tick_id = 0
        self.eq_levels = LevelsReader()
        white = Gdk.RGBA()
        white.parse("#ffffff")
        self.eq_cols = [white] * 5
        self.eq_glow_a = self.eq_glow_b = white
        if glow:
            self.set_overflow(Gtk.Overflow.HIDDEN)      # дыхание обрезается по скруглению карточки

        self._build()
        self.connect("map", self._on_map)
        self.connect("unmap", self._on_unmap)
        self.connect("destroy", lambda *_: self.destroy_card())
        # «destroy» в PyGObject при закрытии окна не приходит (обёртка держит ссылку) — после unrealize
        # проверяем, живо ли ещё окно; спрятанное окно остаётся в списке и карточку не трогаем
        self.connect("unrealize", lambda *_: GLib.idle_add(self._check_gone))
        _css_listeners.append(self._eq_colors_later)      # новые обои — новые оттенки
        self.connect("realize", lambda *_: self._eq_colors())

        self.manager = Playerctl.PlayerManager()
        self.mgr_ids = [self.manager.connect("name-appeared", lambda _m, n: self._manage(n)),
                        self.manager.connect("player-vanished", self._on_vanished)]
        for n in self.manager.props.player_names:
            self._manage(n, initial=True)
        self.refresh()

    # ---------- свойство has-player ----------
    @GObject.Property(type=bool, default=False, flags=GObject.ParamFlags.READABLE)
    def has_player(self):
        return self._has_player

    # ---------- виджеты ----------
    def _build(self):
        c = self.compact
        top = Gtk.Box(spacing=10 if c else 14, css_classes=["ypc-top"])
        self.append(top)

        art = Gtk.Box(css_classes=["ypc-art"], valign=Gtk.Align.CENTER, halign=Gtk.Align.START)
        art.set_overflow(Gtk.Overflow.HIDDEN)
        self.art_stack = Gtk.Stack()
        self.art_img = Gtk.Image(pixel_size=self.art_size, css_classes=["ypc-art-img"])
        self.art_ph = Gtk.Label(label="󰝚", css_classes=["ypc-art-ph"])
        self.art_ph.set_size_request(self.art_size, self.art_size)
        self.art_stack.add_named(self.art_img, "art")
        self.art_stack.add_named(self.art_ph, "ph")
        self.art_stack.set_visible_child_name("ph")
        art.append(self.art_stack)
        top.append(art)

        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1, hexpand=True, valign=Gtk.Align.CENTER,
                       css_classes=["ypc-info"])
        top.append(info)
        src = Gtk.Box(spacing=6, css_classes=["ypc-source"], visible=self.show_source and not c)
        self.src_icon = Gtk.Label(css_classes=["ypc-source-icon"])
        self.src_name = Gtk.Label(xalign=0, hexpand=True, css_classes=["ypc-source-name"],
                                  ellipsize=Pango.EllipsizeMode.END, max_width_chars=1)
        self.switch = Gtk.Box(spacing=4, css_classes=["ypc-switch"], valign=Gtk.Align.CENTER, visible=False)
        for w in (self.src_icon, self.src_name, self.switch):
            src.append(w)
        info.append(src)
        self.src_box = src
        # max_width_chars=1 + hexpand: длинное название не растягивает карточку, а режется многоточием
        self.title_l = Gtk.Label(xalign=0, css_classes=["ypc-title"], ellipsize=Pango.EllipsizeMode.END,
                                 max_width_chars=1, hexpand=True, single_line_mode=True)
        self.artist_l = Gtk.Label(xalign=0, css_classes=["ypc-artist"], ellipsize=Pango.EllipsizeMode.END,
                                  max_width_chars=1, hexpand=True, single_line_mode=True)
        self.eq_island = EqIsland(self, getattr(self, "eq_k", 1.0))
        title_row = Gtk.Box(spacing=8)
        title_row.append(self.title_l)
        title_row.append(self.eq_island)
        info.append(title_row)
        info.append(self.artist_l)

        self.progress = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, draw_value=False, hexpand=True,
                                  css_classes=["ypc-progress"], focusable=False)
        self.progress.set_range(0, 1)
        self.progress.connect("change-value", self._on_seek)
        # пока кнопка зажата — двигается только ползунок, команда уходит одна, после паузы/отпускания
        # нажатие/отпускание — «сырыми» событиями: жест GtkScale забирает себе последовательность,
        # и GestureClick отпускания не видит, а Legacy-контроллер в фазе CAPTURE видит всегда
        raw = Gtk.EventControllerLegacy(propagation_phase=Gtk.PropagationPhase.CAPTURE)
        raw.connect("event", self._on_raw)
        self.progress.add_controller(raw)
        # колесо над полосой: ±5 с за щелчок
        wheel = Gtk.EventControllerScroll(flags=Gtk.EventControllerScrollFlags.VERTICAL,
                                          propagation_phase=Gtk.PropagationPhase.CAPTURE)
        wheel.connect("scroll", self._on_scroll)
        self.progress.add_controller(wheel)

        self.time_l = Gtk.Label(xalign=0, hexpand=True, css_classes=["ypc-time"])
        ctl = Gtk.Box(spacing=6, css_classes=["ypc-controls"], valign=Gtk.Align.CENTER)
        self.b_prev = self._button("󰒮", "Назад", "previous", ["ypc-prev"])
        self.b_play = self._button("󰐊", "Играть", "play_pause", ["ypc-play"])
        self.b_next = self._button("󰒭", "Вперёд", "next", ["ypc-next"])
        for b in (self.b_prev, self.b_play, self.b_next):
            ctl.append(b)

        if c:      # компакт: прогресс под исполнителем, кнопки справа в той же строке
            info.append(self.progress)
            top.append(ctl)
        else:
            self.append(self.progress)
            bottom = Gtk.Box(spacing=8, css_classes=["ypc-bottom"])
            bottom.append(self.time_l)
            bottom.append(ctl)
            self.append(bottom)

    def _button(self, icon, tip, action, extra):
        b = Gtk.Button(label=icon, tooltip_text=tip, css_classes=["ypc-btn", *extra], focusable=False,
                       valign=Gtk.Align.CENTER)
        b.connect("clicked", lambda *_: self._cmd(action))
        return b

    # ---------- плееры ----------
    def _manage(self, name, initial=False):
        if self.dead or name.name in IGNORED:
            return
        try:
            p = Playerctl.Player.new_from_name(name)
        except GLib.Error:
            return
        inst = p.props.player_instance
        ids = [p.connect("playback-status", self._on_status),
               p.connect("metadata", lambda *_: self._schedule()),
               p.connect("seeked", lambda *_: self._tick()),
               p.connect("exit", lambda *_: self._schedule())]
        self.handlers[inst] = (p, ids)
        self.manager.manage_player(p)
        self.last_active[inst] = time.monotonic()
        self._ask_identity(inst)
        if not initial:
            self._schedule()

    def _on_vanished(self, _m, p):
        inst = p.props.player_instance
        old = self.handlers.pop(inst, None)
        if old:
            for i in old[1]:
                old[0].disconnect(i)
        self.last_active.pop(inst, None)
        self._schedule()

    def _ask_identity(self, inst):
        """Identity (Zen / Mozilla Firefox / Chromium) — асинхронно, у браузеров имя плеера одинаковое."""
        try:
            self.bus = self.bus or Gio.bus_get_sync(Gio.BusType.SESSION, None)
        except GLib.Error:
            return

        def done(bus, res):
            try:
                ident = bus.call_finish(res).unpack()[0]
            except Exception:
                return
            if not self.dead:
                self.identity[inst] = str(ident)
                if self.player and self.player.props.player_instance == inst:
                    self._schedule(50)

        self.bus.call("org.mpris.MediaPlayer2." + inst, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties",
                      "Get", GLib.Variant("(ss)", ("org.mpris.MediaPlayer2", "Identity")), GLib.VariantType("(v)"),
                      Gio.DBusCallFlags.NONE, 1000, None, done)

    @staticmethod
    def _meta(p):
        try:
            return p.props.metadata.unpack() or {}
        except Exception:
            return {}

    def players(self):
        """Плееры для показа: без playerctld и без дублей одного трека (остаётся играющий/свежий)."""
        best = {}
        for p in self.manager.props.players:
            if p.props.player_name in IGNORED:
                continue
            md = self._meta(p)
            artist = md.get("xesam:artist") or ""
            if isinstance(artist, list):
                artist = ", ".join(artist)
            title = (md.get("xesam:title") or "").strip().lower()
            # один трек в двух плеерах (mpv + браузер, плеер + его прокси): url есть не у всех — ключ по тексту
            key = (f"{title}\0{artist.strip().lower()}" if title else
                   md.get("xesam:url") or p.props.player_instance)
            rank = (p.props.playback_status == PLAYING, self.last_active.get(p.props.player_instance, 0))
            if key not in best or rank > best[key][0]:
                best[key] = (rank, p)
        # порядок для переключателя — стабильный, по instance
        return sorted((v[1] for v in best.values()), key=lambda p: p.props.player_instance)

    def _choose(self, ps):
        if not ps:
            return None
        for p in ps:
            if p.props.player_instance == self.pinned:
                return p
        playing = [p for p in ps if p.props.playback_status == PLAYING]
        if self.player in playing:
            return self.player
        if playing:
            return max(playing, key=lambda p: self.last_active.get(p.props.player_instance, 0))
        if self.player in ps:
            return self.player
        return max(ps, key=lambda p: self.last_active.get(p.props.player_instance, 0))

    def _on_status(self, p, _st):
        self.last_active[p.props.player_instance] = time.monotonic()
        # при смене трека браузер на мгновение шлёт «Paused» — склеиваем серию событий
        self._schedule(300)

    def _schedule(self, delay=120):
        if self.dead:
            return
        if self.update_timer:
            GLib.source_remove(self.update_timer)
        self.update_timer = GLib.timeout_add(delay, self._do_update)

    def _do_update(self):
        self.update_timer = 0
        self.refresh()
        return False

    # ---------- отрисовка ----------
    def refresh(self):
        if self.dead:
            return
        ps = self.players()
        p = self._choose(ps)
        if p is None:
            self.pinned = None
        changed = p is not self.player
        self.player = p
        self._set_has_player(p is not None)
        self._update_switch(ps)
        if changed:
            self.emit("player-changed", p.props.player_instance if p else "")
        if not p:
            self.title_l.set_label("Ничего не играет")
            self.title_l.set_tooltip_text(None)
            self.artist_l.set_label("")
            self.artist_l.set_visible(False)
            self.src_icon.set_label("󰝛")
            self.src_name.set_label("Тишина")
            self.length = 0
            self.progress.set_value(0)
            self.progress.set_sensitive(False)
            self.time_l.set_label("-:-- / -:--")
            for b in (self.b_prev, self.b_play, self.b_next):
                b.set_sensitive(False)
            self.b_play.set_label("󰐊")
            self._set_art(None)
            self._set_state(False)
            self._update_timer()
            return
        md = self._meta(p)
        title = md.get("xesam:title") or "Без названия"
        artist = md.get("xesam:artist") or ""
        if isinstance(artist, list):
            artist = ", ".join(a for a in artist if a)
        try:                     # трек yumi-music: настоящие имена из meta.tsv, а не ник SoundCloud / канал
            import yumimeta
            clean = yumimeta.lookup(md.get("xesam:url") or "")
        except Exception:
            clean = None
        if clean and clean["title"]:
            title, artist = clean["title"], clean["artist"]
        playing = p.props.playback_status == PLAYING
        self.title_l.set_label(title)
        self.title_l.set_tooltip_text(f"{title}\n{artist}" if artist else title)
        self.artist_l.set_label(artist)
        self.artist_l.set_visible(bool(artist))
        icon, name = source_of(md.get("xesam:url") or "", p.props.player_name,
                               self.identity.get(p.props.player_instance, ""))
        self.src_icon.set_label(icon)
        self.src_name.set_label(name)
        self.b_play.set_label("󰏤" if playing else "󰐊")
        self.b_play.set_tooltip_text("Пауза" if playing else "Играть")
        self.b_play.set_sensitive(True)
        self.b_prev.set_sensitive(p.props.can_go_previous)
        self.b_next.set_sensitive(p.props.can_go_next)
        self.length = int(md.get("mpris:length") or 0)
        self.progress.set_sensitive(bool(self.length) and p.props.can_seek)
        self._set_art(md.get("mpris:artUrl") or None)
        self._set_state(playing)
        self._tick(force=True)
        self._update_timer()

    def _set_state(self, playing):
        (self.add_css_class if playing else self.remove_css_class)("ypc-playing")
        (self.remove_css_class if playing else self.add_css_class)("ypc-paused")
        self.eq_playing = playing
        self._eq_wake()

    # ---------- индикатор у названия и дыхание фона ----------
    def _eq_colors(self):
        """Оттенки из @yp-* (wallbash + yumi-accent): светлый → акцент → рамка."""
        ctx = self.get_style_context()

        def col(name, fallback):
            ok, c = ctx.lookup_color(name)
            if not ok:
                c = Gdk.RGBA()
                c.parse(fallback)
            return c
        fg2, acc, border = col("yp-fg2", "#cce9ff"), col("yp-accent", "#9ad8e6"), col("yp-border", "#6598a3")
        self.eq_cols = [fg2, rgba_mix(fg2, acc, 0.5), acc, rgba_mix(acc, border, 0.45), rgba_mix(acc, border, 0.8)]
        self.eq_glow_a, self.eq_glow_b = acc, rgba_mix(acc, fg2, 0.35)
        self.eq_island.queue_draw()
        self.queue_draw()

    def _eq_colors_later(self):
        # стиль центра (yumi-panel) перечитывается своим монитором чуть позже — пересчитать и после него
        if not self.dead:
            self._eq_colors()
            GLib.timeout_add(600, lambda: (not self.dead and self._eq_colors()) and False)

    def _eq_wake(self):
        if not self.eq_tick_id and not self.dead and self.get_mapped() and (self.eq_playing or self.eq_fade > 0.01):
            self.eq_last = 0
            self.eq_tick_id = self.add_tick_callback(self._eq_tick)

    def _eq_stop(self):
        if self.eq_tick_id:
            self.remove_tick_callback(self.eq_tick_id)
            self.eq_tick_id = 0

    def _eq_tick(self, _w, clock):
        now = clock.get_frame_time()
        dt = min(0.05, (now - self.eq_last) / 1e6) if self.eq_last else 0.016
        self.eq_last = now
        self.eq_time += dt
        playing = self.eq_playing
        self.eq_fade += ((1.0 if playing else 0.0) - self.eq_fade) * (1 - math.exp(-dt * 4))
        # уровни от cava ~30 раз/с — читаем с той же частотой; сглаживание ниже идёт на каждом кадре (60/с)
        if now - self.eq_read_at >= 15000:      # cava шлёт 60 кадров/с — читаем так же часто
            self.eq_read_at = now
            lv = self.eq_levels.read(now / 1e6) if playing else None
            if lv:
                n = len(lv)
                segs = [lv[i * n // 5:(i + 1) * n // 5] or lv[:1] for i in range(5)]
                self.eq_targets = [(sum(g) / len(g) / 255) ** 0.7 for g in segs]
                self.eq_bass_t = ((lv[0] + lv[1] + lv[2]) / 765) ** 0.8
            elif playing:      # уровней нет (Waybar без yumi-eq) — тихое дыхание
                self.eq_targets = [0.25 + 0.2 * math.sin(self.eq_time * (2.1 + i * 0.7) + i) ** 2 for i in range(5)]
                self.eq_bass_t = 0.0
            else:
                self.eq_targets, self.eq_bass_t = [0.0] * 5, 0.0
        for i, tg in enumerate(self.eq_targets):
            rate = 34.0 if tg > self.eq_bars[i] else 16.0
            self.eq_bars[i] += (tg - self.eq_bars[i]) * (1 - math.exp(-dt * rate))
        b = self.eq_bass_t
        self.eq_bass += (b - self.eq_bass) * (1 - math.exp(-dt * (26.0 if b > self.eq_bass else 8.0)))
        self.eq_island.queue_draw()
        if self.eq_glow_on:
            self.queue_draw()
        if not playing and self.eq_fade < 0.01:
            self.eq_tick_id = 0
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE

    def do_snapshot(self, snap):
        """Дыхание фона: поверх CSS-фона карточки, под её содержимым; обрезается по скруглению (overflow)."""
        if self.eq_glow_on and self.eq_fade > 0.005:
            w, h = self.get_width(), self.get_height()
            if w > 0 and h > 0:
                k, t = self.eq_bass * self.eq_fade, self.eq_time
                for i, base in enumerate((self.eq_glow_a, self.eq_glow_b)):
                    cx = w * (0.3 + 0.4 * (0.5 + 0.5 * math.sin(t * (0.19 + i * 0.07) + i * 2.4)))
                    cy = h * (0.3 + 0.35 * (0.5 + 0.5 * math.cos(t * (0.15 + i * 0.05) + i)))
                    r = max(w, h) * (0.42 + 0.10 * k)
                    inner, outer = base.copy(), base.copy()
                    inner.alpha = (0.07 + 0.16 * k) * self.eq_fade
                    outer.alpha = 0.0
                    s0, s1 = Gsk.ColorStop(), Gsk.ColorStop()
                    s0.offset, s0.color = 0.0, inner
                    s1.offset, s1.color = 1.0, outer
                    snap.append_radial_gradient(Graphene.Rect().init(0, 0, w, h), Graphene.Point().init(cx, cy),
                                                r, r * 0.8, 0.0, 1.0, [s0, s1])
        Gtk.Box.do_snapshot(self, snap)

    def _set_has_player(self, has):
        if has == self._has_player:
            if self.autohide and self.get_visible() != has:
                self.set_visible(has)
            return
        self._has_player = has
        if self.autohide:
            self.set_visible(has)
        self.notify("has-player")
        self.emit("visibility-changed", has)
        if self.on_visibility:
            self.on_visibility(has)

    def _update_switch(self, ps):
        child = self.switch.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            self.switch.remove(child)
            child = nxt
        self.switch.set_visible(len(ps) > 1)
        if len(ps) < 2:
            return
        for p in ps:
            md = self._meta(p)
            _i, name = source_of(md.get("xesam:url") or "", p.props.player_name,
                                 self.identity.get(p.props.player_instance, ""))
            d = Gtk.Button(css_classes=["ypc-dot"] + (["active"] if p is self.player else []), focusable=False,
                           tooltip_text=f"{name}: {md.get('xesam:title') or '—'}", valign=Gtk.Align.CENTER)
            d.connect("clicked", self._on_dot, p.props.player_instance)
            self.switch.append(d)

    def _on_dot(self, _b, inst):
        self.pinned = inst
        self.refresh()

    # ---------- прогресс: опрос только пока карточка на экране ----------
    def _on_map(self, *_):
        self._update_timer()
        self._tick(force=True)
        self._eq_wake()

    def _on_unmap(self, *_):
        self._stop_tick()
        self._eq_stop()          # окно центра спрятано — не рисуем

    def _update_timer(self):
        need = not self.dead and self.player is not None and self.get_mapped()
        if need and not self.tick_timer:
            # position у mpv/Firefox сигналом не приходит — опрашиваем (≈0.3 мс на запрос)
            self.tick_timer = GLib.timeout_add(500, self._tick_cb)
        elif not need:
            self._stop_tick()

    def _stop_tick(self):
        if self.tick_timer:
            GLib.source_remove(self.tick_timer)
            self.tick_timer = 0

    def _tick_cb(self):
        if self.dead or self.player is None:
            self.tick_timer = 0
            return False
        self.tick_n += 1
        # на паузе позиция стоит — опрос раз в 2 с (перемотку из другого места тоже поймаем)
        if self.player.props.playback_status == PLAYING or self.tick_n % 4 == 0:
            self._tick()
        return True

    def _tick(self, force=False):
        p = self.player
        if self.dead or p is None:
            return False
        if self.dragging and time.monotonic() - self.drag_since > 20:
            self.dragging = False            # отпускание потерялось — не замораживаем прогресс навсегда
        if force or (not self.dragging and time.monotonic() > self.seek_block_until):
            try:
                pos = p.get_position()
            except GLib.Error:
                pos = 0
            self._show_pos(pos)
        return True

    def _show_pos(self, pos):
        if self.length:
            self.progress.set_value(min(pos / self.length, 1))
            self.time_l.set_label(f"{fmt_time(pos)} / {fmt_time(self.length)}")
        else:
            self.progress.set_value(0)
            self.time_l.set_label(f"{fmt_time(pos)} / -:--" if pos else "-:-- / -:--")

    # ---------- перемотка ----------
    def _on_seek(self, _scale, _scroll, value):
        if self.player and self.length:
            self.seek_pending = int(min(max(value, 0), 1) * self.length)
            self.seek_block_until = time.monotonic() + 1.5     # опрос не дёргает ползунок назад
            self.time_l.set_label(f"{fmt_time(self.seek_pending)} / {fmt_time(self.length)}")
            # released до нас доходит не всегда (GtkScale забирает нажатие) — страхуемся таймером
            if self.seek_timer:
                GLib.source_remove(self.seek_timer)
            self.seek_timer = GLib.timeout_add(250 if self.dragging else 150, self._seek_timeout)
        return False

    def _on_raw(self, _ctl, ev):
        t = ev.get_event_type()
        if t == Gdk.EventType.BUTTON_PRESS:
            self.dragging = True
            self.drag_since = time.monotonic()
        elif t == Gdk.EventType.BUTTON_RELEASE and self.dragging:
            self.dragging = False
            if self.seek_pending is not None:
                self._commit_seek()
        return False

    def _seek_timeout(self):
        self.seek_timer = 0
        if self.dragging:          # кнопка ещё зажата — команду отправит отпускание
            return False
        return self._commit_seek()

    def _commit_seek(self):
        self.dragging = False
        if self.seek_timer:
            GLib.source_remove(self.seek_timer)
            self.seek_timer = 0
        if self.player and self.seek_pending is not None:
            try:
                self.player.set_position(self.seek_pending)
            except GLib.Error:
                pass
            self.seek_block_until = time.monotonic() + 0.8
        self.seek_pending = None
        return False

    def _on_scroll(self, _ctl, _dx, dy):
        self.scroll_acc += dy
        steps = int(self.scroll_acc)              # тачпад шлёт дробные dy — копим до целого щелчка
        if steps and self.player and self.length:
            self.scroll_acc -= steps
            base = self.seek_pending
            if base is None:
                try:
                    base = self.player.get_position()
                except GLib.Error:
                    return True
            self.seek_pending = min(max(base - steps * 5_000_000, 0), self.length - 1_000_000)
            self.seek_block_until = time.monotonic() + 1.5
            self.progress.set_value(self.seek_pending / self.length)
            self.time_l.set_label(f"{fmt_time(self.seek_pending)} / {fmt_time(self.length)}")
            if self.seek_timer:
                GLib.source_remove(self.seek_timer)
            self.seek_timer = GLib.timeout_add(250, self._seek_timeout)
        return True

    def _cmd(self, what):
        if self.player:
            try:
                getattr(self.player, what)()
            except GLib.Error:
                pass
            self._schedule(300)

    # ---------- обложка ----------
    def _set_art(self, url):
        if url == self.art_key:
            return
        self.art_key = url
        if not url:
            self._show_art(None)
            return
        if url in self.art_cache:
            self._show_art(self.art_cache[url])
            return
        px = self.art_size * max(2, self.get_scale_factor())   # запас под HiDPI
        # файл Firefox удаляет при смене трека — поток стартует сразу и читает его первым делом
        threading.Thread(target=self._art_worker, args=(url, px), daemon=True).start()

    def _art_worker(self, url, px):
        pb = _fetch_art(url, px)
        GLib.idle_add(self._art_ready, url, pb)

    def _art_ready(self, url, pb):
        if self.dead:
            return False
        tex = _texture(pb) if pb else None
        if len(self.art_cache) > 20:
            self.art_cache.clear()
        self.art_cache[url] = tex
        if url == self.art_key:
            self._show_art(tex)
        return False

    def _show_art(self, tex):
        if tex:
            self.art_img.set_from_paintable(tex)
            self.art_stack.set_visible_child_name("art")
        else:
            self.art_img.set_from_paintable(None)
            self.art_stack.set_visible_child_name("ph")

    # ---------- уничтожение ----------
    def destroy_card(self):
        """Отключить все сигналы и таймеры (повторный вызов безопасен)."""
        if self.dead:
            return
        self.dead = True
        self._eq_stop()
        if self._eq_colors_later in _css_listeners:
            _css_listeners.remove(self._eq_colors_later)
        if self.eq_levels.fd >= 0:
            os.close(self.eq_levels.fd)
            self.eq_levels.fd = -1
        for t in ("tick_timer", "update_timer", "seek_timer"):
            if getattr(self, t):
                GLib.source_remove(getattr(self, t))
                setattr(self, t, 0)
        for p, ids in self.handlers.values():
            for i in ids:
                p.disconnect(i)
        self.handlers.clear()
        for i in self.mgr_ids:
            self.manager.disconnect(i)
        self.mgr_ids = []
        self.player = None
        self.art_cache.clear()

    def _check_gone(self):
        if not self.dead:
            root = self.get_root()
            tops = Gtk.Window.get_toplevels()
            alive = root is not None and any(tops.get_item(i) is root for i in range(tops.get_n_items()))
            if not alive:
                self.destroy_card()
        return False

    def pending_sources(self):
        """Для проверки: сколько таймеров карточки ещё живо (после destroy_card должно быть 0)."""
        return sum(1 for t in (self.tick_timer, self.update_timer, self.seek_timer) if t)
