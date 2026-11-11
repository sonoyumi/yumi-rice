"""yumi_kbkey — погасить отдельные клавиши Logitech PRO Gaming Keyboard (046d:c339) по HID++ (16.10.2026).

Зачем: у клавиши Menu («листок») умер зелёный и синий каналы светодиода — при любом цвете она светила красным.
OpenRGB 1.0 путает номера клавиш этой модели, Solaar не умеет её версию подсветки по клавишам (0x8080), поэтому
напрямую, как OpenRGB (LogitechHIDPP20Controller::SetPerKey8080):
  0x8070 fn 0x80 [1]         — программное управление подсветкой (как «LED Control» в Solaar);
  0x8080 fn 0x30 SetKeyColors — ТОЛЬКО очень длинным отчётом 0x12 (64 байта): [тип u16 BE, число u16 BE,
                                (код USB HID, R, G, B) × число], тип 0x0001 — обычные клавиши; Menu = 0x65;
  0x8080 fn 0x50 FlushLEDs    — применить (длинный отчёт 0x11).
Номера функций у клавиатуры узнаются через ROOT (0x0000 fn 0x00 getFeature) — не зашиты.
dark_keys() → True/False; никогда не бросает исключений (подсветку целиком красит yumi-kb-light через OpenRGB).
"""
import glob, os, select

VID_PID = "0000046D:0000C339"
SWID = 0x0E
MENU = 0x65


def _hidraw():
    """/dev/hidrawN клавиатуры с очень длинным отчётом 0x12 (там же HID++ 0x10/0x11)."""
    for h in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        try:
            if VID_PID not in open(h + "/device/uevent").read().upper():
                continue
            d = open(h + "/device/report_descriptor", "rb").read()
        except OSError:
            continue
        i, ids = 0, set()
        while i < len(d):                       # короткие элементы дескриптора: 0x85 = Report ID
            b = d[i]; s = b & 3; s = 4 if s == 3 else s
            if b & 0xFC == 0x84 and i + 1 < len(d):
                ids.add(d[i + 1])
            i += 1 + s
        if 0x12 in ids and 0x11 in ids:
            return "/dev/" + os.path.basename(h)
    return None


def _rpc(fd, idx, fn, params=b"", long=False):
    """HID++ 2.0 запрос с ответом; None — ошибка или нет ответа за 0,5 с."""
    rid, ln = (0x11, 20) if long else (0x10, 7)
    pkt = bytes([rid, 0xFF, idx, fn | SWID]) + params
    os.write(fd, pkt + bytes(ln - len(pkt)))
    for _ in range(20):
        r, _, _ = select.select([fd], [], [], 0.5)
        if not r:
            return None
        resp = os.read(fd, 64)
        if len(resp) < 4 or resp[1] != 0xFF:
            continue
        if resp[2] == 0xFF and len(resp) > 4 and resp[3] == idx and resp[4] == fn | SWID:
            return None                         # отчёт об ошибке HID++
        if resp[2] == idx and resp[3] == fn | SWID:
            return resp[4:]
    return None


def _feature(fd, fid):
    r = _rpc(fd, 0x00, 0x00, bytes([fid >> 8, fid & 0xFF]))
    return r[0] if r and r[0] else None


def dark_keys(keys=(MENU,)):
    path = _hidraw()
    if not path:
        return False
    try:
        fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    except OSError:
        return False
    try:
        fx, pk = _feature(fd, 0x8070), _feature(fd, 0x8080)
        if not pk:
            return False
        if fx:
            _rpc(fd, fx, 0x80, b"\x01")         # программное управление
        n = len(keys)
        payload = bytes([0x00, 0x01, n >> 8, n & 0xFF]) + b"".join(bytes([k, 0, 0, 0]) for k in keys)
        pkt = bytes([0x12, 0xFF, pk, 0x30 | SWID]) + payload
        os.write(fd, pkt + bytes(64 - len(pkt)))
        return _rpc(fd, pk, 0x50, long=True) is not None
    except OSError:
        return False
    finally:
        os.close(fd)


if __name__ == "__main__":
    import sys
    sys.exit(0 if dark_keys() else 1)
