#!/usr/bin/env python3
"""yumi-tone — перекраска приложений в тон обоев по значениям yumi-accent.

Вызывается хуками ~/.config/yumi-accent/hooks.d/ (yumi-accent передаёт YUMI_* в окружении;
без них значения читаются из ~/.cache/yumi-accent/accent.txt и bg.txt).

  tone.py gtk      GTK3: ~/.config/gtk-3.0/gtk.css → @import перекрытия (только цветовые свойства темы,
                   перекрашенные; окно Waybar не затрагивается); GTK4: ~/.config/gtk-4.0 — своя папка
                   с перекрашенной копией текущей темы (HyDE при смене темы ставит симлинк обратно, хук
                   при следующем запуске снова делает копию)
  tone.py qt       Kvantum (тема wallbash, перекраска на месте из чистой копии), qt5ct/qt6ct
                   (своя схема colors/yumi-tone.conf), kdeglobals (фоны окон)
  tone.py hypr     рамки окон и групп Hyprland: hyprctl eval + файл для hyprland.lua
  tone.py vscode   тема Wallbash VS Code: цвета интерфейса из code.json → в тон обоев (подсветка кода не меняется)

Правило перекраски: тёмные цвета (фоны) получают оттенок обоев и насыщенность фона yumi-accent
(яркость сохраняется, почти чёрный чуть приподнят), цвета акцента темы — оттенок акцента yumi-accent;
белый текст, чёрные тени и цвета состояний (красный/жёлтый/зелёный) не меняются.
Откат: ~/.local/bin/yumi-tone-uninstall"""
import colorsys
import glob
import hashlib
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
CFG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
STATE = os.path.join(HOME, ".cache/yumi-tone")
ACC_CACHE = os.path.join(HOME, ".cache/yumi-accent")
DCOL = os.path.join(HOME, ".cache/hyde/wall.dcol")
MARK = "yumi-tone"


# ---------- цвета ----------
def h2rgb(hx):
    hx = hx.lstrip("#")
    return tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))


def rgb2h(r, g, b):
    return "%02X%02X%02X" % (r, g, b)


def hsv(hx):
    r, g, b = h2rgb(hx)
    return colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)


def from_hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1, max(0, min(1, s)), max(0, min(1, v)))
    return round(r * 255), round(g * 255), round(b * 255)


def hue_dist(a, b):
    d = abs(a - b) % 1
    return min(d, 1 - d) * 360


class Tone:
    """Значения yumi-accent."""

    def __init__(self):
        env = os.environ
        if env.get("YUMI_ACC"):
            self.acc, self.acc5, self.acc2 = env["YUMI_ACC"], env.get("YUMI_ACC5", env["YUMI_ACC"]), env.get("YUMI_ACC2", env["YUMI_ACC"])
            self.deep, self.bg = env.get("YUMI_DEEP", "1C1C1C"), env.get("YUMI_BG", "292929")
            self.btn, self.hover = env.get("YUMI_BTN", "454545"), env.get("YUMI_HOVER", "666666")
            self.xa = env.get("YUMI_XA", "").split()
            self.mono = env.get("YUMI_MONO", "0") == "1"
        else:
            self.xa = open(os.path.join(ACC_CACHE, "accent.txt")).read().split()
            self.deep, self.bg, self.btn, self.hover = open(os.path.join(ACC_CACHE, "bg.txt")).read().split()
            self.acc, self.acc5, self.acc2 = self.xa[6], self.xa[4], self.xa[1]
            self.mono = all(hsv(c)[1] < 0.02 for c in self.xa)
        if len(self.xa) != 9:
            self.xa = [self.acc] * 9
        ah, as_, _ = hsv(self.acc)
        bh, bs, _ = hsv(self.bg)
        self.h_acc, self.s_acc = ah, (0 if self.mono else as_)
        self.h_bg, self.s_bg = (bh if bs > 0.02 else ah), (0 if self.mono else bs)


class Recolor:
    """Перекраска одного набора цветов (темы) в тон yumi-accent.
    dark_hues — оттенки тёмных фонов темы, acc_hues — оттенки её акцента, acc_ref — цвет акцента темы."""

    def __init__(self, tone, dark_hues, acc_hues, acc_ref=None, acc_tol=12, dark_tol=30, grey_acc=False):
        self.t = tone
        self.dark_hues, self.acc_hues = dark_hues, acc_hues
        self.acc_ref = acc_ref.upper() if acc_ref else None
        self.s_ref = hsv(acc_ref)[1] if acc_ref else 0.3
        self.acc_tol, self.dark_tol = acc_tol, dark_tol
        self.grey_acc = grey_acc          # палитра серая, а акцент цветной: светло-серые «акценты» → акцент
        self.cache = {}

    def rgb(self, r, g, b):
        key = (r, g, b)
        if key in self.cache:
            return self.cache[key]
        out = self._rgb(r, g, b)
        self.cache[key] = out
        return out

    def _rgb(self, r, g, b):
        t = self.t
        if self.acc_ref and rgb2h(r, g, b) == self.acc_ref:
            return h2rgb(t.acc)
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if v < 0.012:                                   # чёрные тени — как есть
            return r, g, b
        if v < 0.45:                                    # тёмное: фоны, рамки, подложки
            if s < 0.05 or any(hue_dist(h, x) <= self.dark_tol for x in self.dark_hues):
                v2 = v + 0.08 * max(0.0, 1 - v / 0.2)   # почти чёрный чуть светлее — чтобы оттенок был виден
                return from_hsv(t.h_bg, t.s_bg * min(1.0, 0.55 + v * 1.5), v2)
            return r, g, b
        if s >= 0.05 and any(hue_dist(h, x) <= self.acc_tol for x in self.acc_hues):
            k = t.s_acc / max(self.s_ref, 0.05)
            return from_hsv(t.h_acc, min(1.0, s * k), v)
        if self.grey_acc and s < 0.05 and 0.5 <= v <= 0.92:
            return from_hsv(t.h_acc, t.s_acc * 0.85, v)
        return r, g, b

    # --- строки ---
    def hex6(self, hx):
        return rgb2h(*self.rgb(*h2rgb(hx)))

    RE = re.compile(r"(?<![\w&-])#([0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})(?![0-9A-Za-z_-])"
                    r"|\brgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(,\s*[\d.]+\s*)?\)")

    def text(self, s, argb=False):
        """Заменить все цвета в строке (#rgb, #rrggbb, #rrggbbaa / #aarrggbb при argb, rgb(), rgba())."""
        def sub(m):
            if m.group(1):
                hx = m.group(1)
                if len(hx) == 3:
                    new = self.hex6("".join(c * 2 for c in hx))
                    return "#" + (new.lower() if hx.islower() else new) if new != "".join(c * 2 for c in hx).upper() else m.group(0)
                if len(hx) == 8:
                    if argb:
                        a, core = hx[:2], hx[2:]
                        new = self.hex6(core)
                        return m.group(0) if new == core.upper() else "#" + a + new
                    core, a = hx[:6], hx[6:]
                    new = self.hex6(core)
                    return m.group(0) if new == core.upper() else "#" + new + a
                new = self.hex6(hx)
                if new == hx.upper():
                    return m.group(0)
                return "#" + (new.lower() if hx.islower() else new)
            r, g, b = int(m.group(2)), int(m.group(3)), int(m.group(4))
            nr, ng, nb = self.rgb(r, g, b)
            if (nr, ng, nb) == (r, g, b):
                return m.group(0)
            return (f"rgba({nr}, {ng}, {nb}{m.group(5)})" if m.group(5) else f"rgb({nr}, {ng}, {nb})")
        return self.RE.sub(sub, s)


def wallbash_hues():
    """Оттенки палитры wallbash (pry1…pry4 и их акценты) — всё, что из неё взято, перекрашивается."""
    hues, acc = [], None
    try:
        for line in open(DCOL):
            m = re.match(r'^dcol_(pry\d|\dxa\d)="([0-9A-Fa-f]{6})"', line)
            if m:
                h, s, v = hsv(m.group(2))
                if s >= 0.06:
                    hues.append(h)
                if m.group(1) == "1xa7":
                    acc = m.group(2)
    except OSError:
        pass
    return hues, acc


def dcol_get(name, default):
    try:
        for line in open(DCOL):
            m = re.match(r'^dcol_%s="([0-9A-Fa-f]{6})"' % name, line)
            if m:
                return m.group(1).upper()
    except OSError:
        pass
    return default


def write(path, text):
    """Атомарная запись; True — если содержимое изменилось."""
    try:
        if open(path).read() == text:
            return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".yumi-tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)
    return True


def sha(text):
    return hashlib.sha1(text.encode()).hexdigest()


def pristine(path, key):
    """Чистая (до нашей перекраски) версия генерируемого HyDE файла.
    Если файл совпадает с нашей последней записью — берём сохранённую копию; иначе это новая
    версия от wallbash — сохраняем её как чистую."""
    os.makedirs(STATE, exist_ok=True)
    cur = open(path).read()
    keep, mine = os.path.join(STATE, key + ".orig"), os.path.join(STATE, key + ".sha")
    try:
        if open(mine).read().strip() == sha(cur) and os.path.exists(keep):
            return open(keep).read()
    except OSError:
        pass
    write(keep, cur)
    return cur


def remember(path, key, text):
    write(os.path.join(STATE, key + ".sha"), sha(text) + "\n")


# ---------- GTK ----------
def gtk_theme_name():
    try:
        out = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                             capture_output=True, text=True, timeout=3).stdout.strip().strip("'")
        if out:
            return out
    except Exception:
        pass
    try:
        for line in open(os.path.join(CFG, "gtk-3.0/settings.ini")):
            if line.startswith("gtk-theme-name="):
                return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return None


def theme_dir(name, sub):
    for base in (os.path.join(HOME, ".local/share/themes"), os.path.join(HOME, ".themes"), "/usr/share/themes"):
        d = os.path.join(base, name, sub)
        if os.path.isfile(os.path.join(d, "gtk.css")):
            return os.path.realpath(d)
    return None


def strip_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


def gtk_recolor_for(css, tone):
    """Recolor для GTK-темы: оттенки фона и акцента берутся из её именованных цветов."""
    def named(n):
        m = re.search(r"@define-color\s+%s\s+(#[0-9A-Fa-f]{6})" % n, css)
        return m.group(1)[1:].upper() if m else None
    bg, sel = named("theme_bg_color"), named("theme_selected_bg_color")
    if not bg or not sel:                          # без имён — самые частые тёмный и «цветной светлый»
        cnt = {}
        for hx in re.findall(r"#([0-9A-Fa-f]{6})\b", css):
            cnt[hx.upper()] = cnt.get(hx.upper(), 0) + 1
        ranked = sorted(cnt, key=cnt.get, reverse=True)
        bg = bg or next((c for c in ranked if hsv(c)[2] < 0.35), "1E1E2E")
        sel = sel or next((c for c in ranked if hsv(c)[2] > 0.5 and hsv(c)[1] > 0.06), None)
    dark = [hsv(bg)[0]] if hsv(bg)[1] >= 0.05 else []
    acc = [hsv(sel)[0]] if sel and hsv(sel)[1] >= 0.05 else []
    return Recolor(tone, dark, acc, acc_ref=sel)


def split_top(s, sep):
    out, depth, cur, q = [], 0, [], None
    for ch in s:
        if q:
            cur.append(ch)
            if ch == q:
                q = None
            continue
        if ch in "\"'":
            q = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == sep and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


def css_blocks(css):
    """[(prelude, body)] верхнего уровня; @-правила без тела — (prelude, None)."""
    out, i, n = [], 0, len(css)
    while i < n:
        j = i
        while j < n and css[j] not in "{;":
            j += 1
        if j >= n:
            break
        prelude = css[i:j].strip()
        if css[j] == ";":
            out.append((prelude, None))
            i = j + 1
            continue
        depth, k = 1, j + 1
        while k < n and depth:
            if css[k] == "{":
                depth += 1
            elif css[k] == "}":
                depth -= 1
            k += 1
        out.append((prelude, css[j + 1:k - 1]))
        i = k
    return out


WAYBAR = "window:not(#waybar)"


def scope_selector(sel):
    """Селектор без окна Waybar (GTK3-приложения и Waybar читают один и тот же gtk.css)."""
    s = sel.strip()
    if not s or "tooltip" in s or s.startswith("*"):
        return []
    out = [WAYBAR + " " + s]
    m = re.match(r"window(?=$|[.:#\s>~+\[])", s)
    if m:
        out.append(WAYBAR + s[m.end():])
    elif s[0] in ".:":
        out.append(WAYBAR + s)  # тот же селектор на самом окне верхнего уровня
    return out


def gtk3_delta(css, rc, assets_dir):
    css = strip_comments(css)
    parts = ["/* yumi-tone: цвета GTK3-темы в тоне обоев (генерируется, не править) */\n"]
    for prelude, body in css_blocks(css):
        if body is None:
            if prelude.startswith("@define-color"):
                new = rc.text(prelude)
                if new != prelude:
                    parts.append(new + ";\n")
            continue
        if prelude.startswith("@"):
            continue                                  # @keyframes, @media — не трогаем
        decls = []
        for d in split_top(body, ";"):
            d = d.strip()
            if ":" not in d:
                continue
            new = rc.text(d)
            if new != d:
                decls.append(re.sub(r'url\("?(?!data:|file:|/)([^")]+)"?\)',
                                    lambda m: 'url("file://%s/%s")' % (assets_dir, m.group(1)), new))
        if not decls:
            continue
        sels = []
        for s in split_top(prelude, ","):
            sels += scope_selector(s)
        if sels:
            parts.append(",\n".join(sels) + " {\n  " + ";\n  ".join(decls) + ";\n}\n")
    return "".join(parts)


def gtk3_validate(css):
    """Убрать правила, которые GTK3 не принимает (иначе каждое приложение пишет предупреждения)."""
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        from gi.repository import Gtk
    except Exception:
        return css
    for _ in range(5):
        bad = []
        prov = Gtk.CssProvider()
        prov.connect("parsing-error", lambda p, sec, err: bad.append(sec.get_start_line()))
        try:
            prov.load_from_data(css.encode())
        except Exception:
            pass
        if not bad:
            return css
        lines = css.split("\n")
        for ln in sorted(set(bad), reverse=True):     # выбросить правило, содержащее строку с ошибкой
            a = ln
            while a > 0 and not lines[a - 1].endswith("}") and lines[a - 1].strip():
                a -= 1
            b = ln
            while b < len(lines) and not lines[b].startswith("}"):
                b += 1
            del lines[a:b + 1]
        css = "\n".join(lines)
    return css


def do_gtk(tone):
    name = gtk_theme_name()
    if not name:
        return
    # GTK3: перекрытие ~/.config/gtk-3.0/gtk.css → @import нашего файла
    d3 = theme_dir(name, "gtk-3.0")
    out3 = os.path.join(STATE, "gtk-3.0.css")
    if d3:
        src = open(os.path.join(d3, "gtk.css")).read()
        rc = gtk_recolor_for(src, tone)
        key = sha(src + repr(vars(tone)) + "v1")
        stamp = os.path.join(STATE, "gtk-3.0.key")
        try:
            same = open(stamp).read() == key and os.path.exists(out3)
        except OSError:
            same = False
        if not same:
            write(out3, gtk3_validate(gtk3_delta(src, rc, os.path.join(d3, "assets"))))
            write(stamp, key)
        user = os.path.join(CFG, "gtk-3.0/gtk.css")
        line = '@import url("file://%s"); /* %s: цвета в тоне обоев, откат — yumi-tone-uninstall */\n' % (out3, MARK)
        try:
            cur = open(user).read()
        except OSError:
            cur = ""
        if MARK not in cur:
            write(user, cur + ("\n" if cur and not cur.endswith("\n") else "") + line)
    # GTK4: ~/.config/gtk-4.0 — симлинк HyDE на тему → своя папка с перекрашенной копией
    g4 = os.path.join(CFG, "gtk-4.0")
    marker = os.path.join(g4, ".yumi-tone-source")
    src4 = None
    if os.path.islink(g4):
        src4 = os.path.realpath(g4)
    elif os.path.isfile(marker):
        src4 = open(marker).read().strip()
    else:
        src4 = None                                   # своя папка пользователя — не трогаем
    if not src4 or not os.path.isfile(os.path.join(src4, "gtk.css")):
        return
    css4 = open(os.path.join(src4, "gtk.css")).read()
    rc4 = gtk_recolor_for(css4, tone)
    new4 = recolor_css_full(css4, rc4)
    if os.path.islink(g4):
        tmpd = g4 + ".yumi-new"
        shutil.rmtree(tmpd, ignore_errors=True)
        os.makedirs(tmpd)
        for e in os.listdir(src4):
            if e not in ("gtk.css", "gtk-dark.css"):
                os.symlink(os.path.join(src4, e), os.path.join(tmpd, e))
        with open(os.path.join(tmpd, ".yumi-tone-source"), "w") as f:
            f.write(src4 + "\n")
        for fn in ("gtk.css", "gtk-dark.css"):
            with open(os.path.join(tmpd, fn), "w") as f:
                f.write(new4)
        os.unlink(g4)
        os.rename(tmpd, g4)
    else:
        for fn in ("gtk.css", "gtk-dark.css"):
            write(os.path.join(g4, fn), new4)


def recolor_css_full(css, rc):
    """Перекрасить цвета только в телах правил и @define-color (не в селекторах вроде #add)."""
    out, depth, i, n = [], 0, 0, len(css)
    seg_start = 0
    pieces = []
    for m in re.finditer(r"[{}]|/\*.*?\*/|@define-color[^;]*;", css, flags=re.S):
        tok = m.group(0)
        chunk = css[seg_start:m.start()]
        pieces.append(rc.text(chunk) if depth > 0 else chunk)
        if tok == "{":
            depth += 1
        elif tok == "}":
            depth = max(0, depth - 1)
        elif tok.startswith("@define-color"):
            tok = rc.text(tok)
        pieces.append(tok)
        seg_start = m.end()
    pieces.append(css[seg_start:])
    return "".join(pieces)


# ---------- Qt ----------
def wallbash_rc(tone):
    hues, acc = wallbash_hues()
    return Recolor(tone, hues, hues, acc_ref=None, acc_tol=15, dark_tol=30, grey_acc=not hues and not tone.mono)


def do_qt(tone):
    rc = wallbash_rc(tone)
    # Kvantum: тема wallbash перекрашивается на месте (wallbash пишет её заново при смене обоев)
    kv = os.path.join(CFG, "Kvantum/wallbash")
    for fn in ("wallbash.kvconfig", "wallbash.svg"):
        p = os.path.join(kv, fn)
        if os.path.isfile(p):
            src = pristine(p, "kvantum-" + fn)
            new = rc.text(src)
            write(p, new)
            remember(p, "kvantum-" + fn, new)
    # qt5ct/qt6ct: своя схема из вывода wallbash
    src = os.path.join(HOME, ".cache/hyde/wallbash/qtct.conf")
    if os.path.isfile(src):
        text = rc.text(open(src).read(), argb=True)
        for ct in ("qt5ct", "qt6ct"):
            conf = os.path.join(CFG, ct, ct + ".conf")
            if not os.path.isfile(conf):
                continue
            mine = os.path.join(CFG, ct, "colors/yumi-tone.conf")
            write(mine, text)
            cur = open(conf).read()
            new = re.sub(r"(?m)^color_scheme_path=.*$", "color_scheme_path=" + mine, cur)
            if new != cur:
                write(conf, new)
    # kdeglobals: фоны (HyDE ставит pry1/pry2 палитры wallbash) — те же цвета, перекрашенные
    kg = os.path.join(CFG, "kdeglobals")
    if os.path.isfile(kg):
        p1 = ",".join(map(str, rc.rgb(*h2rgb(dcol_get("pry1", "060606")))))
        p2 = ",".join(map(str, rc.rgb(*h2rgb(dcol_get("pry2", "303030")))))
        want = {"Colors:Button": p1, "Colors:Window": p1, "Colors:View": p1, "Colors:Tooltip": p1, "Colors:Selection": p2}
        lines, sec, out = open(kg).read().split("\n"), None, []
        for ln in lines:
            m = re.match(r"^\[(.+)\]$", ln)
            if m:
                sec = m.group(1)
            elif sec in want and ln.startswith("BackgroundNormal="):
                ln = "BackgroundNormal=" + want[sec]
            out.append(ln)
        write(kg, "\n".join(out))


# ---------- Hyprland ----------
HYPR_FILE = os.path.join(STATE, "hypr-borders.lua")


def do_hypr(tone, apply_only=False):
    if not apply_only:
        xa = tone.xa

        def c(hx, a="ff"):
            return '"rgba(%s%s)"' % (hx.lower(), a)
        g = lambda *cols: "{colors = {%s}, angle = 45}" % ", ".join(cols)
        lua = ("-- yumi-tone: рамки окон в тоне обоев (генерируется хуком 40-hypr-borders, не править)\n"
               "hl.config({\n"
               "  general = { col = {\n"
               f"    active_border = {g(c(tone.acc, 'f2'), c(tone.acc5, 'f2'))},\n"
               f"    inactive_border = {g(c(tone.btn, 'cc'), c(tone.deep, 'cc'))},\n"
               "  } },\n"
               "  group = {\n"
               "    col = {\n"
               f"      border_active = {g(c(tone.acc, 'f2'), c(tone.acc2, 'f2'))},\n"
               f"      border_inactive = {g(c(tone.deep, 'cc'), c(tone.btn, 'cc'))},\n"
               f"      border_locked_active = {g(c(xa[8], 'f2'), c(xa[2], 'f2'))},\n"
               f"      border_locked_inactive = {g(c(tone.acc5, 'cc'), c(tone.acc2, 'cc'))},\n"
               "    },\n"
               "    groupbar = { col = {\n"
               f"      active = {g(c(xa[3], 'f2'))},\n"
               f"      inactive = {g(c(tone.deep, 'f2'))},\n"
               f"      locked_active = {g(c(tone.btn, 'f2'))},\n"
               f"      locked_inactive = {g(c(xa[2], 'f2'))},\n"
               "    } },\n"
               "  },\n"
               "})\n")
        write(HYPR_FILE, lua)
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or not shutil.which("hyprctl") or not os.path.isfile(HYPR_FILE):
        return
    # одной строкой и без комментариев: hyprctl принимает аргумент на «-» за флаг
    code = " ".join(l.strip() for l in open(HYPR_FILE) if l.strip() and not l.lstrip().startswith("--"))
    subprocess.run(["hyprctl", "-q", "eval", code], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    if not apply_only:
        # color.set.sh после шаблонов делает `hyprctl reload` → HyDE ставит свои рамки; повторить чуть позже
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "hypr", "--later"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


# ---------- VS Code ----------
def do_vscode(tone):
    import json
    src = os.path.join(HOME, ".cache/hyde/wallbash/code.json")
    themes = glob.glob(os.path.join(HOME, ".vscode*/extensions/thehydeproject.wallbash-*/themes/wallbash.json"))
    if not themes or not os.path.isfile(src):
        return
    text = open(src).read()
    if "#@" in text:                                  # code-colors.py ещё не отработал — он вызовет хук сам
        return
    data = json.loads(text)
    rc = wallbash_rc(tone)
    cols = data.get("colors", {})
    for k, v in list(cols.items()):
        if isinstance(v, str):
            cols[k] = rc.text(v)
    out = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    for t in themes:
        write(t, out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    what = sys.argv[1]
    if what == "hypr" and "--later" in sys.argv:
        import time
        time.sleep(2.5)
        do_hypr(None, apply_only=True)
        return
    tone = Tone()
    {"gtk": do_gtk, "qt": do_qt, "hypr": do_hypr, "vscode": do_vscode}[what](tone)


if __name__ == "__main__":
    main()
