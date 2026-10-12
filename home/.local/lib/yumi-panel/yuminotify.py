"""yuminotify — список уведомлений для «Центра управления» yumi-panel (GTK4).

Источник данных — журнал yumi-notify-log (~/.cache/yumi-notify/history.json), который пассивно слушает
сессионную шину. swaync остаётся демоном уведомлений: всплывашки и его собственная история не меняются.

API
  NotificationList(history=None, max_items=30, compact=False, group=False, on_activate=None,
                   show_header=True, close_in_swaync=True)
      Gtk.Box со списком карточек. Следит за файлом истории (Gio.FileMonitor) и перерисовывается вживую.
      Свойства GObject: max-items (int), compact (bool), group (bool) — менять можно на лету.
      Сигнал «count-changed» (int) — сколько уведомлений в истории.
      Методы: reload(), get_count(), clear_all(), dismiss(key).
      on_activate(item) — после щелчка по карточке (приложение уже запущено по desktop-entry, если нашлось);
      центр в нём закрывается.
  DndRow()          — строка «Не беспокоить» с переключателем (swaync-client -dn / -df), живое состояние.
  CountLabel(nlist=None) — счётчик: число в истории nlist, а без nlist — счётчик swaync (swaync-client -s).
  SwayncState.get() — общий наблюдатель `swaync-client -s` (сигнал «changed»: count, dnd, visible).
  set_dnd(on), get_dnd(), swaync_count() — синхронные помощники.

Закрытие одной карточки
  swaync-client не умеет закрыть уведомление по id, но стандартный метод D-Bus
  org.freedesktop.Notifications.CloseNotification(id) умеет — его поддерживает любой сервер, и swaync
  убирает уведомление и со всплывашки, и из своей истории (сигнал NotificationClosed reason 3).
  Вызываем его, только если запись создана текущим экземпляром swaync (имя на шине совпадает):
  после перезапуска swaync id начинаются заново и чужое уведомление закрывать нельзя.
  Из нашей истории запись убирается сразу (атомарная запись файла; журнал подхватит правку).
«Очистить всё» — пустая история + `swaync-client -C` (закрывает ВСЕ уведомления swaync).
YP_DRYRUN=1 или YNL_DRYRUN=1 — команды, меняющие swaync (CloseNotification, -C, DND), только печатаются.

Клик по карточке
  Действие «default» вызывается только сервером уведомлений (ActionInvoked шлёт swaync), снаружи его
  не вызвать. Поэтому щелчок открывает приложение: hint desktop-entry → .desktop, иначе .desktop,
  чьё имя совпало с именем приложения; запуск через gtk-launch без LD_PRELOAD layer-shell.

CSS-классы (стиль ~/.config/yumi-panel/notify.css, цвета @yp-*)
  .ynl-root            корень NotificationList (+ .ynl-compact в компактном режиме)
  .ynl-header          строка заголовка: .ynl-title «Уведомления», .ynl-badge (число), .ynl-clear (кнопка)
  .ynl-scroll          прокрутка списка, .ynl-list — коробка карточек
  .ynl-group           группа приложения: .ynl-group-head, .ynl-group-icon, .ynl-group-name, .ynl-group-count
  .ynl-card            карточка (+ .ynl-critical, .ynl-low по urgency); внутри:
     .ynl-icon         значок (картинка уведомления / значок приложения), .ynl-icon-image — если это картинка
     .ynl-app          название приложения, .ynl-time — относительное время
     .ynl-summary      заголовок (жирный), .ynl-body — текст (2 строки, многоточие)
     .ynl-close        кнопка «закрыть» (видна при наведении на карточку)
  .ynl-empty           пустое состояние: .ynl-empty-icon, .ynl-empty-text «Нет уведомлений»
  .ynl-dnd             строка «Не беспокоить»: .ynl-dnd-icon, .ynl-dnd-label, .ynl-dnd-switch (+ .on)
  .ynl-count           счётчик CountLabel (+ .zero, когда 0)
"""
import html
import json
import os
import re
import subprocess
import sys
import time

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gtk, Gdk, Gio, GLib, GObject, Pango  # noqa: E402

try:
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix
    DesktopAppInfo = GioUnix.DesktopAppInfo
except (ImportError, ValueError):
    DesktopAppInfo = Gio.DesktopAppInfo

HISTORY = os.environ.get("YNL_HISTORY") or os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "yumi-notify", "history.json")
CSS_PATH = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                        "yumi-panel", "notify.css")
DRY = bool(os.environ.get("YP_DRYRUN") or os.environ.get("YNL_DRYRUN"))
NAME = "org.freedesktop.Notifications"
FALLBACK_ICON = "preferences-system-notifications-symbolic"

# дочерним программам — без LD_PRELOAD layer-shell и с исходной локалью (как в yumipanel.CHILD_ENV)
CHILD_ENV = {k: v for k, v in os.environ.items() if k not in ("LD_PRELOAD", "LANG", "LC_ALL")}
for _k in ("LANG", "LC_ALL"):
    if os.environ.get("YP_ORIG_" + _k):
        CHILD_ENV[_k] = os.environ["YP_ORIG_" + _k]


def _dry(*what):
    print("[dry-run]", *what, file=sys.stderr, flush=True)


def _spawn(*cmd):
    if DRY and cmd[0] == "swaync-client":
        _dry(*cmd)
        return
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True, env=CHILD_ENV)
    except OSError as e:
        print("yuminotify:", e, file=sys.stderr)


def _swaync(*args, timeout=2):
    try:
        r = subprocess.run(("swaync-client", "-sw") + args, capture_output=True, text=True,
                           timeout=timeout, env=CHILD_ENV)
        return r.stdout.strip()
    except Exception:
        return ""


def load_css(display=None):
    """Подключить notify.css (если центр не грузит его сам). Возвращает Gtk.CssProvider."""
    prov = Gtk.CssProvider()
    try:
        prov.load_from_path(CSS_PATH)
    except Exception as e:
        print("yuminotify: notify.css:", e, file=sys.stderr)
    Gtk.StyleContext.add_provider_for_display(display or Gdk.Display.get_default(), prov,
                                              Gtk.STYLE_PROVIDER_PRIORITY_USER)
    return prov


# ---------- история ----------
def read_history(path=HISTORY):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("items"), list):
            return data
    except FileNotFoundError:
        pass
    except Exception as e:
        print("yuminotify: история не читается:", e, file=sys.stderr)
    return {"version": 1, "items": []}


def write_history(data, path=HISTORY):
    """Атомарно (tmp + rename) — журнал yumi-notify-log увидит правку и возьмёт её за основу."""
    tmp = f"{path}.ui{os.getpid()}"
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        os.replace(tmp, path)
    except Exception as e:
        print("yuminotify: история не записывается:", e, file=sys.stderr)


# ---------- оформление текста и времени ----------
_TAG = re.compile(r"<[^>]*>")


def plain_text(s):
    """Тело уведомления может быть с разметкой (<b>, <a>, &amp;) — показываем простым текстом."""
    s = _TAG.sub("", s or "")
    return " ".join(html.unescape(s).split())


def rel_time(ts, now=None):
    now = now or time.time()
    d = now - (ts or now)
    if d < 60:
        return "только что"
    if d < 3600:
        return f"{int(d // 60)} мин"
    t, n = time.localtime(ts), time.localtime(now)
    if t.tm_yday == n.tm_yday and t.tm_year == n.tm_year:
        return time.strftime("%H:%M", t)
    if d < 2 * 86400 and (n.tm_yday - t.tm_yday) % 366 == 1:
        return time.strftime("вчера %H:%M", t)
    return time.strftime("%d.%m %H:%M", t)


# ---------- значки ----------
def _theme():
    return Gtk.IconTheme.get_for_display(Gdk.Display.get_default())


def _desktop_info(item):
    """Gio.DesktopAppInfo по hint desktop-entry, иначе по совпадению имени приложения."""
    cand = item.get("desktop_entry")
    if cand:
        cand = cand if cand.endswith(".desktop") else cand + ".desktop"
        try:
            info = DesktopAppInfo.new(cand)
            if info:
                return info
        except TypeError:
            pass
    app = (item.get("app") or "").strip().lower()
    if not app:
        return None
    try:
        for group in DesktopAppInfo.search(app):
            for did in group:
                info = DesktopAppInfo.new(did)
                if info and ((info.get_name() or "").lower() == app or did.lower() == app + ".desktop"):
                    return info
    except Exception:
        pass
    return None


def _file_path(s):
    if not s:
        return None
    if s.startswith("file://"):
        try:
            s = GLib.filename_from_uri(s)[0]
        except Exception:
            return None
    return s if s.startswith("/") and os.path.isfile(s) else None


def set_icon(img, item, size):
    """Картинка уведомления (png из кэша / image-path) → app_icon → значок .desktop → имя приложения."""
    img.set_pixel_size(size)
    img.remove_css_class("ynl-icon-image")
    theme = _theme()
    for src, is_image in ((item.get("image"), True), (item.get("app_icon"), False)):
        path = _file_path(src)
        if path:
            try:
                img.set_from_paintable(Gdk.Texture.new_from_filename(path))
                if is_image:
                    img.add_css_class("ynl-icon-image")
                return
            except Exception:
                continue
        if src and not src.startswith(("/", "file:")) and theme.has_icon(src):
            img.set_from_icon_name(src)
            return
    info = _desktop_info(item)
    if info and info.get_icon():
        img.set_from_gicon(info.get_icon())
        return
    guess = (item.get("app") or "").lower().replace(" ", "-")
    img.set_from_icon_name(guess if guess and theme.has_icon(guess) else FALLBACK_ICON)


# ---------- карточка ----------
class _Card(Gtk.Box):
    def __init__(self, owner, item, compact, show_app=True):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=8 if compact else 12,
                         css_classes=["ynl-card"])
        self.item = item
        urg = item.get("urgency", 1)
        if urg == 2:
            self.add_css_class("ynl-critical")
        elif urg == 0:
            self.add_css_class("ynl-low")

        icon = Gtk.Image(css_classes=["ynl-icon"], valign=Gtk.Align.START)
        icon.set_overflow(Gtk.Overflow.HIDDEN)          # скругление картинки
        set_icon(icon, item, 28 if compact else 36)
        self.append(icon)

        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2, hexpand=True)
        top = Gtk.Box(spacing=6)
        # в группе название приложения уже в заголовке группы
        top.append(Gtk.Label(label=(item.get("app") or "Уведомление") if show_app else "", xalign=0,
                             hexpand=True, css_classes=["ynl-app"], ellipsize=Pango.EllipsizeMode.END,
                             max_width_chars=1))
        self.time_l = Gtk.Label(label=rel_time(item.get("time")), css_classes=["ynl-time"])
        top.append(self.time_l)
        close = Gtk.Button(label="󰅖", tooltip_text="Убрать", css_classes=["ynl-close"],
                           valign=Gtk.Align.CENTER)
        close.connect("clicked", lambda *_: owner.dismiss(item["key"]))
        top.append(close)
        col.append(top)

        summary = plain_text(item.get("summary"))
        if summary:
            col.append(Gtk.Label(label=summary, xalign=0, css_classes=["ynl-summary"],
                                 ellipsize=Pango.EllipsizeMode.END, max_width_chars=1))
        body = plain_text(item.get("body"))
        if body:
            b = Gtk.Label(label=body, xalign=0, css_classes=["ynl-body"], wrap=True,
                          wrap_mode=Pango.WrapMode.WORD_CHAR, max_width_chars=1,
                          ellipsize=Pango.EllipsizeMode.END, lines=1 if compact else 2)
            col.append(b)
        self.append(col)
        self.set_tooltip_text(None)

        click = Gtk.GestureClick(button=Gdk.BUTTON_PRIMARY)
        click.connect("released", self._on_click, owner)
        self.add_controller(click)
        self.set_cursor(Gdk.Cursor.new_from_name("pointer"))

    def _on_click(self, gesture, _n, x, y, owner):
        # щелчок по кнопке «закрыть» не открывает приложение
        w = self.pick(x, y, Gtk.PickFlags.DEFAULT)
        while w is not None and w is not self:
            if isinstance(w, Gtk.Button):
                return
            w = w.get_parent()
        gesture.set_state(Gtk.EventSequenceState.CLAIMED)
        owner.activate_item(self.item)

    def refresh_time(self, now):
        self.time_l.set_label(rel_time(self.item.get("time"), now))


# ---------- список ----------
class NotificationList(Gtk.Box):
    __gtype_name__ = "YumiNotificationList"
    __gsignals__ = {"count-changed": (GObject.SignalFlags.RUN_FIRST, None, (int,))}

    def __init__(self, history=None, max_items=30, compact=False, group=False, on_activate=None,
                 show_header=True, close_in_swaync=True):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=8, css_classes=["ynl-root"])
        self.path = history or HISTORY
        self._max, self._compact, self._group = max_items, compact, group
        self.on_activate = on_activate
        self.close_in_swaync = close_in_swaync
        self.items = []
        self.cards = []
        self._reload_id = 0
        self._sig = None

        self.header = Gtk.Box(spacing=8, css_classes=["ynl-header"], visible=show_header)
        self.header.append(Gtk.Label(label="Уведомления", xalign=0, css_classes=["ynl-title"]))
        self.badge = Gtk.Label(css_classes=["ynl-badge"], valign=Gtk.Align.CENTER)
        self.header.append(self.badge)
        self.header.append(Gtk.Box(hexpand=True))
        self.clear_btn = Gtk.Button(label="Очистить всё", css_classes=["ynl-clear"])
        self.clear_btn.connect("clicked", lambda *_: self.clear_all())
        self.header.append(self.clear_btn)
        self.append(self.header)

        self.list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, css_classes=["ynl-list"])
        self.scroll = Gtk.ScrolledWindow(child=self.list, css_classes=["ynl-scroll"], vexpand=True,
                                         hscrollbar_policy=Gtk.PolicyType.NEVER,
                                         propagate_natural_height=True)
        self.append(self.scroll)

        self.empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, css_classes=["ynl-empty"],
                             halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER, vexpand=True)
        self.empty.append(Gtk.Label(label="󰂛", css_classes=["ynl-empty-icon"]))
        self.empty.append(Gtk.Label(label="Нет уведомлений", css_classes=["ynl-empty-text"]))
        self.append(self.empty)

        if compact:
            self.add_css_class("ynl-compact")
        self._watch()
        self.reload()
        self._tick = GLib.timeout_add_seconds(30, self._refresh_times)
        self.connect("destroy", self._cleanup)

    # ----- свойства -----
    @GObject.Property(type=int, default=30)
    def max_items(self):
        return self._max

    @max_items.setter
    def max_items(self, v):
        self._max = int(v)
        self._render()

    @GObject.Property(type=bool, default=False)
    def compact(self):
        return self._compact

    @compact.setter
    def compact(self, v):
        self._compact = bool(v)
        (self.add_css_class if v else self.remove_css_class)("ynl-compact")
        self._render()

    @GObject.Property(type=bool, default=False)
    def group(self):
        return self._group

    @group.setter
    def group(self, v):
        self._group = bool(v)
        self._render()

    # ----- файл -----
    def _watch(self):
        # следим за каталогом: история заменяется переименованием, а монитор файла это может упустить
        d = Gio.File.new_for_path(os.path.dirname(self.path))
        try:
            os.makedirs(d.get_path(), exist_ok=True)
            self.monitor = d.monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
            self.monitor.connect("changed", self._on_changed)
        except Exception as e:
            self.monitor = None
            print("yuminotify: нет слежения за историей:", e, file=sys.stderr)

    def _on_changed(self, _m, f, other, _ev):
        base = os.path.basename(self.path)
        if base in {x.get_basename() for x in (f, other) if x is not None} and not self._reload_id:
            self._reload_id = GLib.timeout_add(120, self._delayed_reload)

    def _delayed_reload(self):
        self._reload_id = 0
        self.reload()
        return False

    def _cleanup(self, *_):
        if getattr(self, "_tick", 0):
            GLib.source_remove(self._tick)
            self._tick = 0
        if getattr(self, "monitor", None):
            self.monitor.cancel()
            self.monitor = None

    def reload(self):
        try:
            st = os.stat(self.path)
            sig = (st.st_mtime_ns, st.st_size)
        except OSError:
            sig = None
        if sig == self._sig and self.cards:
            return
        self._sig = sig
        self.data = read_history(self.path)
        self.items = self.data["items"]
        self._render()

    # ----- отрисовка -----
    def _render(self):
        while (c := self.list.get_first_child()) is not None:
            self.list.remove(c)
        self.cards = []
        shown = self.items[:self._max]
        if self._group:
            order, groups = [], {}
            for it in shown:
                k = (it.get("app") or "").strip().lower() or it.get("desktop_entry") or "?"
                if k not in groups:
                    groups[k] = []
                    order.append(k)
                groups[k].append(it)
            for k in order:
                self.list.append(self._group_box(groups[k]))
        else:
            for it in shown:
                card = _Card(self, it, self._compact)
                self.cards.append(card)
                self.list.append(card)
        n = len(self.items)
        self.badge.set_label(str(n))
        self.badge.set_visible(n > 0)
        self.clear_btn.set_sensitive(n > 0)
        self.scroll.set_visible(n > 0)
        self.empty.set_visible(n == 0)
        self.emit("count-changed", n)

    def _group_box(self, items):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, css_classes=["ynl-group"])
        head = Gtk.Box(spacing=8, css_classes=["ynl-group-head"])
        ic = Gtk.Image(css_classes=["ynl-group-icon"])
        set_icon(ic, dict(items[0], image=None), 16)
        head.append(ic)
        head.append(Gtk.Label(label=items[0].get("app") or "Уведомления", xalign=0, hexpand=True,
                              css_classes=["ynl-group-name"], ellipsize=Pango.EllipsizeMode.END,
                              max_width_chars=1))
        head.append(Gtk.Label(label=str(len(items)), css_classes=["ynl-group-count"]))
        box.append(head)
        for it in items:
            card = _Card(self, it, self._compact, show_app=False)
            self.cards.append(card)
            box.append(card)
        return box

    def _refresh_times(self):
        now = time.time()
        for c in self.cards:
            c.refresh_time(now)
        return True

    # ----- действия -----
    def get_count(self):
        return len(self.items)

    def dismiss(self, key):
        """Убрать одно уведомление: из нашей истории и (если оно ещё живо в swaync) — из swaync."""
        item = next((i for i in self.items if i.get("key") == key), None)
        if item is None:
            return
        data = read_history(self.path)
        data["items"] = [i for i in data["items"] if i.get("key") != key]
        write_history(data, self.path)
        self.items = data["items"]
        self._sig = None
        self._render()
        if self.close_in_swaync:
            _close_in_swaync(item)

    def clear_all(self):
        data = read_history(self.path)
        data["items"] = []
        write_history(data, self.path)
        self.items = []
        self._sig = None
        self._render()
        _spawn("swaync-client", "-sw", "-C")

    def activate_item(self, item):
        info = _desktop_info(item)
        if info is not None:
            did = info.get_id() or ""
            did = did[:-8] if did.endswith(".desktop") else did
            if DRY:
                _dry("gtk-launch", did)
            else:
                _spawn("gtk-launch", did)
        if self.on_activate:
            self.on_activate(item)


def _close_in_swaync(item):
    """CloseNotification(id) — только если запись от текущего экземпляра swaync."""
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    except Exception:
        return

    def got_owner(b, res):
        try:
            owner = b.call_finish(res).unpack()[0]
        except Exception:
            return
        if owner != item.get("srv"):
            return                      # swaync перезапускался — этот id уже чужой
        if DRY:
            _dry("CloseNotification", item.get("id"))
            return
        b.call(NAME, "/org/freedesktop/Notifications", NAME, "CloseNotification",
               GLib.Variant("(u)", (int(item["id"]),)), None, Gio.DBusCallFlags.NONE, 2000, None,
               lambda bb, r: _finish_quiet(bb, r))

    bus.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner",
             GLib.Variant("(s)", (NAME,)), GLib.VariantType("(s)"), Gio.DBusCallFlags.NONE, 1000, None,
             got_owner)


def _finish_quiet(bus, res):
    try:
        bus.call_finish(res)
    except Exception as e:
        print("yuminotify: CloseNotification:", e, file=sys.stderr)


# ---------- swaync: DND и счётчик ----------
def get_dnd():
    return _swaync("-D") == "true"


def set_dnd(on):
    """Включить/выключить «Не беспокоить» явно (а не -d «переключить»: без рассинхрона)."""
    if DRY:
        _dry("swaync-client", "-dn" if on else "-df")
        return bool(on)
    return _swaync("-dn" if on else "-df") == "true"


def swaync_count():
    try:
        return int(_swaync("-c") or 0)
    except ValueError:
        return 0


class SwayncState(GObject.Object):
    """Один на процесс `swaync-client -s`: живые count/dnd/visible. Перезапускается, если swaync упал."""
    __gsignals__ = {"changed": (GObject.SignalFlags.RUN_FIRST, None, ())}
    _inst = None

    @classmethod
    def get(cls):
        if cls._inst is None:
            cls._inst = cls()
        return cls._inst

    def __init__(self):
        super().__init__()
        self.count, self.dnd, self.visible = 0, False, False
        self.proc = None
        self._start()

    def _start(self):
        try:
            launcher = Gio.SubprocessLauncher.new(Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE)
            launcher.set_environ([f"{k}={v}" for k, v in CHILD_ENV.items()])
            self.proc = launcher.spawnv(["swaync-client", "-s"])
            self.stream = Gio.DataInputStream.new(self.proc.get_stdout_pipe())
            self.stream.read_line_async(GLib.PRIORITY_DEFAULT, None, self._on_line)
        except Exception as e:
            print("yuminotify: swaync-client -s:", e, file=sys.stderr)
            GLib.timeout_add_seconds(5, self._restart)

    def _restart(self):
        self._start()
        return False

    def _on_line(self, stream, res):
        try:
            line, _ = stream.read_line_finish_utf8(res)
        except Exception:
            line = None
        if line is None:                         # процесс завершился (swaync перезапускают)
            GLib.timeout_add_seconds(2, self._restart)
            return
        try:
            d = json.loads(line)
            self.count, self.dnd, self.visible = int(d.get("count", 0)), bool(d.get("dnd")), bool(d.get("visible"))
            self.emit("changed")
        except ValueError:
            pass
        stream.read_line_async(GLib.PRIORITY_DEFAULT, None, self._on_line)

    def stop(self):
        if self.proc:
            self.proc.force_exit()
            self.proc = None


class DndRow(Gtk.Box):
    """Строка «Не беспокоить» с переключателем; состояние живое (меняется и из swaync/Waybar)."""

    def __init__(self, text="Не беспокоить"):
        super().__init__(spacing=10, css_classes=["ynl-dnd"])
        self.icon = Gtk.Label(css_classes=["ynl-dnd-icon"])
        self.append(self.icon)
        self.append(Gtk.Label(label=text, xalign=0, hexpand=True, css_classes=["ynl-dnd-label"]))
        self.switch = Gtk.Switch(css_classes=["ynl-dnd-switch"], valign=Gtk.Align.CENTER)
        self._lock = False
        self._show(get_dnd())
        self.switch.connect("notify::active", self._on_toggle)
        self.append(self.switch)
        self.state = SwayncState.get()
        self._hid = self.state.connect("changed", lambda s: self._show(s.dnd))
        self.connect("destroy", lambda *_: self.state.disconnect(self._hid))

    def _show(self, on):
        self._lock = True
        self.switch.set_active(on)
        self._lock = False
        self.icon.set_label("󰂛" if on else "󰂚")
        (self.add_css_class if on else self.remove_css_class)("on")

    def _on_toggle(self, sw, _p):
        if not self._lock:
            self._show(set_dnd(sw.get_active()))


class CountLabel(Gtk.Label):
    """Счётчик уведомлений: по нашей истории (nlist) или по swaync (без nlist)."""

    def __init__(self, nlist=None):
        super().__init__(css_classes=["ynl-count"])
        if nlist is not None:
            nlist.connect("count-changed", lambda _l, n: self._set(n))
            self._set(nlist.get_count())
        else:
            st = SwayncState.get()
            st.connect("changed", lambda s: self._set(s.count))
            self._set(swaync_count())

    def _set(self, n):
        self.set_label(str(n))
        (self.add_css_class if n == 0 else self.remove_css_class)("zero")
