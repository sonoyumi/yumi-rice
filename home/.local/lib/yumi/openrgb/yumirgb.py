"""yumirgb — быстрый клиент сервера OpenRGB (SDK, TCP 127.0.0.1:6742) без запуска самой программы openrgb.

`openrgb --client …` каждый раз поднимает Qt и тратит ~2,5 с; здесь тот же запрос уходит за десятки мс.
Умеет ровно то, что нужно подсветке: найти устройство по имени и поставить режиму (по умолчанию «Static») цвет.

  python3 yumirgb.py list                       устройства и их режимы
  python3 yumirgb.py static "PRO Gaming Keyboard" B8B8B8
Из кода: import yumirgb; yumirgb.set_mode_color("PRO Gaming Keyboard", "B8B8B8")  → True/False
Протокол: https://gitlab.com/CalcProgrammer1/OpenRGB/-/wikis/OpenRGB-SDK-Documentation (версия 4)
"""
import socket
import struct
import sys

HOST, PORT, PROTO = "127.0.0.1", 6742, 4
REQUEST_CONTROLLER_COUNT, REQUEST_CONTROLLER_DATA = 0, 1
REQUEST_PROTOCOL_VERSION, SET_CLIENT_NAME = 40, 50
UPDATEMODE = 1101


class Conn:
    def __init__(self, timeout=2.0):
        self.s = socket.create_connection((HOST, PORT), timeout=timeout)
        self.send(0, SET_CLIENT_NAME, b"yumirgb\0")
        self.send(0, REQUEST_PROTOCOL_VERSION, struct.pack("<I", PROTO))
        _, _, data = self.recv()
        self.proto = min(PROTO, struct.unpack("<I", data[:4])[0])

    def send(self, dev, pkt, data=b""):
        self.s.sendall(b"ORGB" + struct.pack("<III", dev, pkt, len(data)) + data)

    def recv(self):
        head = self._read(16)
        if head[:4] != b"ORGB":
            raise IOError("не OpenRGB")
        dev, pkt, size = struct.unpack("<III", head[4:])
        return dev, pkt, self._read(size)

    def _read(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.s.recv(n - len(buf))
            if not chunk:
                raise IOError("соединение закрыто")
            buf += chunk
        return buf

    def count(self):
        self.send(0, REQUEST_CONTROLLER_COUNT)
        return struct.unpack("<I", self.recv()[2][:4])[0]

    def controller(self, idx):
        self.send(idx, REQUEST_CONTROLLER_DATA, struct.pack("<I", self.proto))
        return parse_controller(self.recv()[2], self.proto)


class Reader:
    def __init__(self, data):
        self.d, self.p = data, 0

    def u16(self):
        v = struct.unpack_from("<H", self.d, self.p)[0]; self.p += 2; return v

    def u32(self):
        v = struct.unpack_from("<I", self.d, self.p)[0]; self.p += 4; return v

    def i32(self):
        v = struct.unpack_from("<i", self.d, self.p)[0]; self.p += 4; return v

    def string(self):
        n = self.u16(); s = self.d[self.p:self.p + n]; self.p += n
        return s.rstrip(b"\0").decode("utf-8", "replace")


def parse_controller(data, proto):
    """Имя, режимы (все поля — чтобы отправить режим обратно) и номер активного режима."""
    r = Reader(data)
    r.u32()                                    # размер
    r.i32()                                    # тип устройства
    name = r.string()
    if proto >= 1:
        r.string()                             # производитель
    for _ in range(4):                         # описание, версия, серийный, расположение
        r.string()
    modes = []
    n = r.u16()
    active = r.i32()
    for _ in range(n):
        m = {"name": r.string(), "value": r.i32(), "flags": r.u32(), "speed_min": r.u32(), "speed_max": r.u32()}
        if proto >= 3:
            m["brightness_min"], m["brightness_max"] = r.u32(), r.u32()
        m["colors_min"], m["colors_max"], m["speed"] = r.u32(), r.u32(), r.u32()
        if proto >= 3:
            m["brightness"] = r.u32()
        m["direction"], m["color_mode"] = r.u32(), r.u32()
        m["colors"] = [r.u32() for _ in range(r.u16())]
        modes.append(m)
    return {"name": name, "modes": modes, "active": active}


def pack_mode(m, proto):
    name = m["name"].encode() + b"\0"
    b = struct.pack("<H", len(name)) + name
    b += struct.pack("<iIII", m["value"], m["flags"], m["speed_min"], m["speed_max"])
    if proto >= 3:
        b += struct.pack("<II", m["brightness_min"], m["brightness_max"])
    b += struct.pack("<III", m["colors_min"], m["colors_max"], m["speed"])
    if proto >= 3:
        b += struct.pack("<I", m["brightness"])
    b += struct.pack("<II", m["direction"], m["color_mode"])
    b += struct.pack("<H", len(m["colors"])) + b"".join(struct.pack("<I", c) for c in m["colors"])
    return b


def rgb_word(hexcolor):
    r, g, b = (int(hexcolor[i:i + 2], 16) for i in (0, 2, 4))
    return r | (g << 8) | (b << 16)            # байты R, G, B, 0


def set_mode_color(device, hexcolor, mode="Static"):
    try:
        c = Conn()
        for i in range(c.count()):
            ctl = c.controller(i)
            if ctl["name"] != device:
                continue
            for mi, m in enumerate(ctl["modes"]):
                if m["name"].lower() != mode.lower():
                    continue
                m["colors"] = [rgb_word(hexcolor)] * max(1, len(m["colors"]) or m["colors_min"] or 1)
                body = struct.pack("<i", mi) + pack_mode(m, c.proto)
                c.send(i, UPDATEMODE, struct.pack("<I", len(body) + 4) + body)
                c.s.close()
                return True
        c.s.close()
    except (OSError, struct.error):
        pass
    return False


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        c = Conn()
        print("протокол", c.proto)
        for i in range(c.count()):
            ctl = c.controller(i)
            print(i, ctl["name"], "| активный:", ctl["modes"][ctl["active"]]["name"] if ctl["modes"] else "-",
                  "| режимы:", ", ".join("%s(%d цв.)" % (m["name"], len(m["colors"])) for m in ctl["modes"]))
    elif len(a) == 3 and a[0] == "static":
        sys.exit(0 if set_mode_color(a[1], a[2]) else 1)
    else:
        print(__doc__)
        sys.exit(2)
