"""aap — управление AirPods по протоколу Apple AAP (L2CAP PSM 0x1001), только stdlib, без root.

Протокол и разбор пакетов — по мотивам проекта zeffd/airpods:
    https://github.com/zeffd/airpods  (файл airpods)
    MIT License, Copyright (c) 2026 Digvijay Singh
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions: The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.
Константы протокола (рукопожатие, коды пакетов, номера настроек) взяты оттуда; код сессии свой.

Сессия:  connect L2CAP PSM 0x1001 → рукопожатие → «возможности хоста» → подписка на уведомления.
Пакеты:  04 00 04 00 <opcode LE16> <payload>
  0x0004 батарея   <count> + по 5 байт: <kind> <?> <level> <status> <?>
                   kind 01 одиночный, 02 правый, 04 левый, 08 кейс; status 01 заряжается, 02 обычный, 04 нет связи
  0x0006 уши       <primary> <secondary>: 00 в ухе, 01 вне уха, 02 в кейсе
  0x0009 настройка <id> <d1..d4>; 0x0D режим (1 выкл, 2 шумоподавление, 3 прозрачность, 4 адаптивный),
                   0x1A маска разрешённых режимов, 0x28 восприятие разговора (01 вкл, 02 выкл)
  0x001D сведения  строки через \\0: модель A1234, прошивка x.y.z
  0x0019 нажатие   <type> <bud>: 05 одно, 06 двойное, 07 тройное, 08 долгое; bud 01 левый, 02 правый
                   (приходит только для нажатий, включённых настройкой 0x39 — маска 01/02/04/08; по librepods)
Важно (из zeffd): изменение настройки часто НЕ подтверждается в той же сессии — запись прошла, но новое
значение придёт только после переподключения. Поэтому значение показывается сразу, «ждёт подтверждения»,
и не откатывается.  Одновременно возможна только одна AAP-сессия — поэтому, если запущена служба
yumi-airpods (держит канал ради нажатий ножки), Session ходит через её сокет relay_path(mac): служба
пересылает пакеты в обе стороны и сразу отдаёт последние известные (батарея, уши, настройки, сведения).
"""
import errno
import json
import os
import select
import shutil
import socket
import subprocess
import sys
import threading
import time

AAP_UUID = "74ec2172-0bad-4d01-8f77-997b2be0722a"
APPLE_VENDOR = "v004C"
PSM = 0x1001

HDR = bytes.fromhex("04000400")
HANDSHAKE = bytes.fromhex("00000400010002000000000000000000")
SET_SPECIFIC_FEATURES = bytes.fromhex("040004004d00ff00000000000000")
REQ_NOTIFICATIONS = bytes.fromhex("040004000f00ffffffffff")

OP_BATTERY = 0x0004
OP_EAR = 0x0006
OP_CONTROL = 0x0009
OP_DEVINFO = 0x001D
OP_STEM = 0x0019

S_MODE = 0x0D            # режим шумоподавления
S_ALLOWED = 0x1A         # маска разрешённых режимов
S_CONVERSATION = 0x28    # восприятие разговора
S_STEM = 0x39            # какие нажатия ножки слать пакетом 0x19 (вместо AVRCP): 01 одно, 02 двойное, 04 тройное, 08 долгое
ON, OFF = 0x01, 0x02     # кодировка переключателей
STEM_PRESS = {0x05: "single", 0x06: "double", 0x07: "triple", 0x08: "long"}

SOL_BLUETOOTH, BT_SECURITY, BT_SECURITY_MEDIUM = 274, 4, 2   # BlueZ 5.86+ требует явный уровень для PSM 0x1001

# Мультиточка (по librepods, linux/rust aacp.rs): кто «владеет» наушниками — тому идут звук и нажатия.
OP_AUDIO_SOURCE = 0x000E      # <mac LE 6> <type: 0 нет, 1 звонок, 2 медиа>
OP_SMART_ROUTING = 0x0010     # хост → наушники (OPACK-словари), адрес цели — 6 байт задом наперёд
OP_SMART_ROUTING_RESP = 0x0011
OP_CONNECTED = 0x002E         # <count> <2> + по 8 байт: <mac 6> <info1> <info2>
S_OWNS = 0x06                 # настройка «соединением владею я»: 01 / 00


def _mac_rev(mac):
    return bytes(int(x, 16) for x in reversed(mac.split(":")))


def connected_devices(data):
    """MAC устройств из пакета 0x2E (смещения как в librepods: payload = data[4:], с кода операции)."""
    body = data[4:]
    if len(body) < 3:
        return []
    count = body[2]
    out = []
    for i in range(count):
        base = 5 + i * 8
        if base + 6 > len(body):
            break
        out.append(":".join(f"{b:02X}" for b in body[base:base + 6]))
    return out


def audio_source(data):
    """(mac, type) из пакета 0x0E или None (payload = data[4:])."""
    body = data[4:]
    if len(body) < 9:
        return None
    return ":".join(f"{b:02X}" for b in reversed(body[2:8])), body[8]


def media_info_packet(self_mac, target_mac, streaming=True):
    """«Хост играет» (send_media_information из librepods, байт в байт)."""
    b = bytearray(_mac_rev(target_mac)) + bytes([0x82, 0x00, 0x01, 0xE5, 0x4A]) + b"PlayingApp" + b"\x56" \
        + b"com.google.ios.youtube" + b"\x52" + b"HostStreamingState" + b"\x42" + (b"YES" if streaming else b"NO") \
        + b"\x49" + b"btAddress" + b"\x51" + self_mac.upper().encode() + b"btName" + b"\x43" + b"Mac" + b"\x58" \
        + b"otherDevice" + b"AudioCategory" + bytes([0x31, 0x2D, 0x01])
    b += bytes(max(0, 138 - len(b)))
    return HDR + bytes([OP_SMART_ROUTING, 0x00]) + bytes(b)


def hijack_packet(target_mac):
    """«Забрать наушники у target» (send_hijack_request из librepods, байт в байт)."""
    b = bytearray(_mac_rev(target_mac)) + bytes([0x62, 0x00, 0x01, 0xE5, 0x4A]) + b"localscore" + bytes([0x30, 0x64]) \
        + b"\x46" + b"reason" + b"\x48" + b"Hijackv2" + b"\x51" + b"audioRoutingScore" + bytes([0x31, 0x2D, 0x01, 0x5F]) \
        + b"audioRoutingSetOwnershipToFalse" + b"\x01" + b"\x4B" + b"remotescore" + b"\xA5"
    b += bytes(max(0, 106 - len(b)))
    return HDR + bytes([OP_SMART_ROUTING, 0x00]) + bytes(b)

COMPONENT = {0x01: "single", 0x02: "right", 0x04: "left", 0x08: "case"}
BATT_STATUS = {0x00: "unknown", 0x01: "charging", 0x02: "normal", 0x04: "disconnected"}
EAR_STATE = {0x00: "in-ear", 0x01: "out", 0x02: "in-case"}
MODES = (1, 2, 3, 4)
CONFIRM_S = 12.0         # столько ждём эха настройки, потом помечаем «не подтверждено» (но не откатываем)

# модель по Modalias (bluetooth:v004Cp<product>) — только для подписи
MODELS = {0x2002: "AirPods", 0x200F: "AirPods 2", 0x2013: "AirPods 3", 0x200E: "AirPods Pro",
          0x2014: "AirPods Pro 2", 0x2024: "AirPods Pro 2 (USB-C)", 0x200A: "AirPods Max",
          0x201F: "AirPods Max (USB-C)", 0x2019: "AirPods 4", 0x201B: "AirPods 4 ANC"}


class AAPError(Exception):
    pass


def is_airpods(modalias="", uuids=()):
    """Apple-наушники, говорящие на AAP: по UUID сервиса или по производителю Apple в Modalias."""
    return AAP_UUID in {u.lower() for u in uuids} or APPLE_VENDOR.lower() in (modalias or "").lower()


def model_name(modalias):
    try:
        prod = int(modalias.lower().split("p", 2)[-1][:4], 16) if "v004c" in modalias.lower() else None
    except ValueError:
        prod = None
    return MODELS.get(prod)


def explain(err):
    """Понятная причина, почему не удалось открыть/держать канал управления."""
    code = getattr(err, "errno", None)
    text = str(err)
    if code in (errno.EBUSY, errno.EALREADY, errno.EISCONN, errno.EADDRINUSE) or "busy" in text.lower():
        return "busy", "Канал управления AirPods занят другой программой (LibrePods, airpods…). Закройте её."
    if code == errno.ECONNREFUSED:
        return "busy", "AirPods не открыли канал управления — возможно, его держит другая программа."
    if code in (errno.EHOSTDOWN, errno.EHOSTUNREACH, errno.ETIMEDOUT, errno.ENOTCONN) or isinstance(err, TimeoutError) \
            or "timed out" in text:
        return "down", "AirPods не отвечают — они подключены и рядом?"
    if code in (errno.EACCES, errno.EPERM):
        return "perm", "Нет прав на Bluetooth-сокет."
    if code == errno.ECONNRESET or "closed" in text:
        return "lost", "Связь с AirPods потеряна."
    if isinstance(err, AttributeError):
        return "nosupport", "Python собран без поддержки Bluetooth-сокетов."
    return "error", f"Нет связи с AirPods: {text}"


class State:
    """Состояние наушников, собранное из пакетов. Чистый разбор — без сокета (удобно тестировать)."""

    def __init__(self):
        self.battery = {}      # left/right/single/case → {level, status, available}
        self.ear = {}          # primary/secondary → 0/1/2
        self.settings = {}     # id → [d1, d2, d3, d4]
        self.model = None
        self.firmware = None

    def handle(self, data):
        """Разобрать один пакет. True — состояние изменилось."""
        if not data.startswith(HDR) or len(data) < 6:
            return False
        op = int.from_bytes(data[4:6], "little")
        body = data[6:]
        if op == OP_BATTERY and body:
            for i in range(body[0]):
                off = 1 + i * 5
                if off + 5 > len(body):
                    break
                kind, _, level, status, _ = body[off:off + 5]
                self.battery[COMPONENT.get(kind, f"0x{kind:02x}")] = {
                    "level": level, "status": BATT_STATUS.get(status, "unknown"), "available": status != 0x04}
            return True
        if op == OP_CONTROL and len(body) >= 5:
            self.settings[body[0]] = list(body[1:5])
            return True
        if op == OP_EAR and len(body) >= 2:
            self.ear = {"primary": body[0], "secondary": body[1]}
            return True
        if op == OP_DEVINFO:
            for chunk in body.split(b"\x00"):
                try:
                    t = chunk.decode("ascii")
                except UnicodeDecodeError:
                    continue
                if not (t.isprintable() and len(t) >= 3):
                    continue
                if len(t) == 5 and t[0] == "A" and t[1:].isdigit() and not self.model:
                    self.model = t
                elif t.count(".") == 2 and t[0].isdigit() and not self.firmware:
                    self.firmware = t
            return True
        return False

    @property
    def mode(self):
        return self.settings.get(S_MODE, [None])[0]

    @property
    def allowed_modes(self):
        mask = self.settings.get(S_ALLOWED, [0x0F])[0] or 0x0F
        return [m for m in MODES if mask & (1 << (m - 1))]


def set_packet(ident, *values):
    """Пакет записи настройки (opcode 0x09): 11 байт."""
    payload = list(values)[:4] + [0] * (4 - min(len(values), 4))
    return HDR + bytes([OP_CONTROL, 0x00, ident]) + bytes(payload)


def settings_packet(ident, *values):
    """Как наушники сообщают настройку — для имитации эха и тестов (тот же формат)."""
    return set_packet(ident, *values)


def relay_path(mac):
    """Сокет службы yumi-airpods для этих наушников (есть, только пока служба держит канал)."""
    run = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return os.path.join(run, f"yumi-airpods-{mac.replace(':', '').upper()}.sock")


def open_l2cap(mac, timeout=6.0, extra=()):
    """Открыть канал AAP: L2CAP PSM 0x1001 → рукопожатие → возможности хоста → уведомления (+ extra-пакеты)."""
    s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
    s.settimeout(timeout)
    try:
        try:
            s.setsockopt(SOL_BLUETOOTH, BT_SECURITY, bytes([BT_SECURITY_MEDIUM, 0]))
        except OSError:
            pass
        s.connect((mac, PSM))
        for pkt in (HANDSHAKE, SET_SPECIFIC_FEATURES, REQ_NOTIFICATIONS, *extra):
            s.send(pkt)
            time.sleep(0.15)
    except OSError:
        s.close()
        raise
    return s


def open_relay(mac):
    """Подключиться к сокету службы yumi-airpods; None — службы нет (или сокет мёртвый)."""
    path = relay_path(mac)
    if not os.path.exists(path):
        return None
    s = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
    try:
        s.connect(path)
    except OSError:
        s.close()
        return None
    return s


class Session(threading.Thread):
    """Фоновая AAP-сессия: подключается, читает уведомления, пишет настройки. Окно не ждёт её никогда.
    on_update(snapshot) вызывается из потока сессии — меню само переносит его в главный поток.
    dry=True — запись настроек только печатается в stderr; demo=True — без наушников, имитация пакетов."""

    def __init__(self, mac, on_update, dry=False, demo=False, retry=4.0):
        super().__init__(daemon=True)
        self.mac, self.on_update, self.dry, self.demo, self.retry = mac, on_update, dry, demo, retry
        self.state = State()
        self.lock = threading.Lock()
        self.pending = {}            # id → {values, sent, confirm_by, stale}
        self.status, self.message = "connecting", ""
        self.sock = None
        self.stopped = False
        self.wake_r, self.wake_w = os.pipe()

    # ----- из главного потока -----
    def change(self, ident, *values):
        with self.lock:
            self.pending[ident] = {"values": list(values), "sent": False, "confirm_by": None, "stale": False}
        self._wake()
        self._emit()

    def stop(self):
        self.stopped = True
        self._wake()

    def snapshot(self):
        with self.lock:
            st = self.state
            settings = {k: list(v) for k, v in st.settings.items()}
            for ident, p in self.pending.items():     # показываем выбранное, пока наушники не подтвердят
                settings[ident] = p["values"] + settings.get(ident, [0, 0, 0, 0])[len(p["values"]):]
            return {"status": self.status, "message": self.message, "battery": dict(st.battery),
                    "ear": dict(st.ear), "settings": settings, "model": st.model, "firmware": st.firmware,
                    "allowed": st.allowed_modes if S_ALLOWED in st.settings else list(MODES),
                    "pending": {k for k, p in self.pending.items() if not p["stale"]},
                    "stale": {k for k, p in self.pending.items() if p["stale"]}}

    # ----- поток -----
    def _wake(self):
        try:
            os.write(self.wake_w, b"x")
        except OSError:
            pass

    def _emit(self):
        if not self.stopped:
            try:
                self.on_update(self.snapshot())
            except Exception:       # noqa: BLE001 — окно закрывается, ничего страшного
                pass

    def _set_status(self, status, message=""):
        self.status, self.message = status, message
        self._emit()

    def run(self):
        try:
            while not self.stopped:
                self._set_status("connecting")
                try:
                    self._open()
                except (AAPError, OSError, AttributeError) as e:
                    kind, msg = explain(e.__cause__ or e)
                    self._set_status(kind, msg)
                    self._sleep(self.retry if kind != "nosupport" else 1e9)
                    continue
                self._set_status("ok")
                try:
                    self._loop()
                except (AAPError, OSError) as e:
                    kind, msg = explain(e.__cause__ or e)
                    self._set_status("lost" if kind == "error" else kind, msg)
                finally:
                    self._close()
                if not self.stopped:
                    self._sleep(self.retry)
        finally:
            self._close()
            for fd in (self.wake_r, self.wake_w):
                try:
                    os.close(fd)
                except OSError:
                    pass

    def _sleep(self, sec):
        end = time.monotonic() + sec
        while not self.stopped and time.monotonic() < end:
            select.select([self.wake_r], [], [], min(0.5, end - time.monotonic()))
            self._drain_wake()

    def _drain_wake(self):
        try:
            while select.select([self.wake_r], [], [], 0)[0]:
                os.read(self.wake_r, 64)
        except OSError:
            pass

    def _open(self):
        if self.demo == "busy":            # имитация: канал держит другая программа
            time.sleep(0.6)
            raise AAPError("busy") from OSError(errno.EBUSY, "Device or resource busy")
        if self.demo:
            time.sleep(0.6)
            for pkt in demo_packets():
                with self.lock:
                    self.state.handle(pkt)
            return
        s = open_relay(self.mac)           # служба yumi-airpods держит канал — работаем через неё
        if s is None:
            try:
                s = open_l2cap(self.mac)
            except OSError as e:
                raise AAPError(str(e)) from e
        s.setblocking(False)
        self.sock = s

    def _close(self):
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None

    def _loop(self):
        while not self.stopped:
            fds = [self.wake_r] + ([self.sock] if self.sock else [])
            ready, _, _ = select.select(fds, [], [], 0.5)
            if self.wake_r in ready:
                self._drain_wake()
            changed = False
            if self.sock and self.sock in ready:
                changed |= self._pump()
            changed |= self._flush()
            if changed:
                self._emit()

    def _pump(self):
        changed = False
        while True:
            try:
                data = self.sock.recv(8192)
            except BlockingIOError:
                return changed
            except OSError as e:
                raise AAPError(str(e)) from e
            if not data:
                raise AAPError("connection closed by device")
            changed |= self._feed(data)

    def _feed(self, data):
        with self.lock:
            changed = self.state.handle(data)
            for ident, p in list(self.pending.items()):     # эхо пришло — подтверждено
                cur = self.state.settings.get(ident)
                if p["sent"] and cur and all(cur[i] == v for i, v in enumerate(p["values"])):
                    del self.pending[ident]
                    changed = True
        return changed

    def _flush(self):
        """Отправить новые изменения; просроченные — пометить «не подтверждено»."""
        changed = False
        now = time.monotonic()
        with self.lock:
            todo = [(i, p) for i, p in self.pending.items() if not p["sent"]]
            for ident, p in self.pending.items():
                if p["sent"] and not p["stale"] and now >= p["confirm_by"]:
                    p["stale"] = changed = True
        for ident, p in todo:
            pkt = set_packet(ident, *p["values"])
            if self.dry or self.demo:
                print(f"[dry-run] aap {self.mac} set 0x{ident:02X} {p['values']} → {pkt.hex(' ')}",
                      file=sys.stderr, flush=True)
                if self.demo:              # имитация: наушники подтвердили
                    threading.Timer(0.7, lambda pk=settings_packet(ident, *p["values"]): (
                        self._feed(pk), self._emit())).start()
            else:
                try:
                    self.sock.send(pkt)
                except OSError as e:
                    raise AAPError(str(e)) from e
            with self.lock:
                p["sent"], p["confirm_by"] = True, now + CONFIRM_S
            changed = True
        return changed


def demo_packets():
    """Пакеты для имитации без наушников (YP_BT_AAP_DEMO=1) — того же формата, что шлют AirPods."""
    return [
        HDR + bytes([OP_BATTERY, 0]) + bytes([3, 0x04, 0x01, 85, 0x02, 0x01, 0x02, 0x01, 80, 0x02, 0x01,
                                              0x08, 0x01, 45, 0x01, 0x01]),
        HDR + bytes([OP_EAR, 0, 0x00, 0x00]),
        settings_packet(S_ALLOWED, 0x0F),
        settings_packet(S_MODE, 2),
        settings_packet(S_CONVERSATION, ON),
        HDR + bytes([OP_DEVINFO, 0]) + b"\x00AirPods Pro\x00A3047\x00" + b"7E101\x00" + b"\x007.8.1\x00",
    ]


# ---------- «Пауза при снятии наушника» (подготовлено, по умолчанию ВЫКЛЮЧЕНО) ----------
PREFS = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "yumi/panel", "airpods.json")


def load_prefs():
    """pause_on_removal — пауза при снятии наушника; handoff_on_lock — при блокировке экрана отдать AirPods
    айфону (пауза + отключение). Оба по умолчанию выключены. iphone_mac — Bluetooth-адрес айфона: при подключении
    AirPods к ноутбуку служба сразу забирает их у него (иначе нажатия уходят айфону)."""
    keys = ("pause_on_removal", "handoff_on_lock")
    try:
        with open(PREFS) as f:
            data = json.load(f)
        prefs = {k: bool(data.get(k, False)) for k in keys}
        mac = str(data.get("iphone_mac", "")).strip().upper()     # айфон, у которого забирать AirPods
        prefs["iphone_mac"] = mac if len(mac) == 17 and mac.count(":") == 5 else None
        return prefs
    except (OSError, ValueError, AttributeError):
        return {**{k: False for k in keys}, "iphone_mac": None}


class EarPause:
    """Пауза плеера, когда наушник вынули, и продолжение, когда оба снова в ушах (как в zeffd).
    Работает только пока жива AAP-сессия — значит, для постоянной работы нужна фоновая служба
    (сейчас нигде не запускается). update(ear) вызывать при каждом пакете ушей."""

    def __init__(self, dry=False):
        self.dry = dry
        self.removed = None
        self.paused = None

    def _ctl(self, *args):
        if self.dry:
            print("[dry-run] playerctl", *args, file=sys.stderr, flush=True)
            return True, ""
        r = subprocess.run(["playerctl", *args], capture_output=True, text=True, timeout=2)
        return r.returncode == 0, r.stdout.strip()

    def update(self, ear):
        if not ear or not shutil.which("playerctl"):
            return
        removed = any(v != 0x00 for v in ear.values())
        prev, self.removed = self.removed, removed
        if prev is False and removed:
            ok, players = self._ctl("--list-all")
            for p in players.splitlines() if ok else []:
                if self._ctl("--player", p, "status")[1] == "Playing":
                    if self._ctl("--player", p, "pause")[0]:
                        self.paused = p
                    break
        elif prev and not removed and self.paused:
            time.sleep(1.5)          # дать наушникам вернуть шумоподавление
            self._ctl("--player", self.paused, "play")
            self.paused = None
