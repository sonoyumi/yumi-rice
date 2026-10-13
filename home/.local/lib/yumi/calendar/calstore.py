"""calstore — хранилище планов календаря (общий модуль yumi-menu-calendar и yumi-calendar-remind).

Файл: ~/.local/share/yumi-calendar/events.json (или $YP_CAL_FILE для проверок):
{
  "version": 1,
  "events": [
    {
      "id": "20261006-a1b2c3",       уникальный id
      "date": "2026-10-06",          день плана
      "time": "09:30" | null,        null — «весь день» (напоминание считается от 09:00)
      "text": "Позвонить…",          текст, может быть многострочным
      "remind": null | 0 | 10 | 60 | 1440,   за сколько минут напомнить (null — не напоминать)
      "done": false,                 выполнено
      "created": "2026-10-06T06:00", "updated": "…",
      "notified": "2026-10-06T09:20" момент напоминания, о котором уже сообщили (защита от повторов;
                                     после правки времени не совпадёт — напомнит снова)
      "snooze": "2026-10-06T09:30"   «Отложить на 10 мин» — когда напомнить повторно
    }
  ]
}
Запись атомарная (временный файл + fsync + rename) под блокировкой flock; при первой записи
в существующий файл кладётся копия events.json.bak.
"""
import fcntl
import json
import os
import secrets
from contextlib import contextmanager
from datetime import date, datetime, time, timedelta

PATH = os.path.expanduser(os.environ.get("YP_CAL_FILE") or "~/.local/share/yumi-calendar/events.json")
ALLDAY_AT = time(9, 0)          # «весь день»: напоминание считается от 9:00 этого дня
REMINDS = [None, 0, 10, 60, 1440]


def now():
    """Текущее время (YP_CAL_NOW=2026-10-06T09:00 — подменить для проверок)."""
    fake = os.environ.get("YP_CAL_NOW")
    return datetime.fromisoformat(fake) if fake else datetime.now().replace(second=0, microsecond=0)


def load():
    try:
        with open(PATH, encoding="utf-8") as f:
            data = json.load(f)
        evs = data.get("events", []) if isinstance(data, dict) else []
        return [e for e in evs if isinstance(e, dict) and e.get("id") and e.get("date")]
    except (OSError, ValueError):
        return []


@contextmanager
def locked():
    """Блокировка на время «прочитать → изменить → записать» (меню и напоминалка не перетрут друг друга)."""
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    with open(PATH + ".lock", "w") as lk:
        fcntl.flock(lk, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lk, fcntl.LOCK_UN)


def save(events):
    """Атомарная запись (вызывать внутри locked())."""
    d = os.path.dirname(PATH)
    os.makedirs(d, exist_ok=True)
    bak = PATH + ".bak"
    if os.path.exists(PATH) and not os.path.exists(bak):
        with open(PATH, "rb") as src, open(bak, "wb") as dst:
            dst.write(src.read())
    events = sorted(events, key=lambda e: (e["date"], e.get("time") or "", e.get("created", "")))
    tmp = f"{PATH}.tmp{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "events": events}, f, ensure_ascii=False, indent=1)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, PATH)


def modify(fn):
    """fn(events) меняет список на месте; всё под блокировкой, со свежим чтением."""
    with locked():
        evs = load()
        res = fn(evs)
        save(evs)
        return res


def new_id(day):
    return day.replace("-", "") + "-" + secrets.token_hex(3)


def base_dt(ev):
    d = date.fromisoformat(ev["date"])
    t = time.fromisoformat(ev["time"]) if ev.get("time") else ALLDAY_AT
    return datetime.combine(d, t)


def fire_dt(ev):
    """Момент напоминания или None."""
    if ev.get("remind") is None:
        return None
    return base_dt(ev) - timedelta(minutes=int(ev["remind"]))


def key(dt):
    return dt.isoformat(timespec="minutes")


def mark_past_as_sent(ev):
    """Сам план уже прошёл — не присылать «догоняющее» напоминание сразу после сохранения."""
    f = fire_dt(ev)
    if f is not None and base_dt(ev) < now():
        ev["notified"] = key(f)
    elif f is not None and ev.get("notified") != key(f):
        ev.pop("notified", None)
