import QtQuick
import qs

// Клавиатура для любого меню (16.10): собирает видимые кликабельные MouseArea и поля TextInput внутри root,
// стрелки ходят между ними по рядам (↑↓ — ряд выше/ниже, ←→ — сосед в ряду), Enter «нажимает» (сигнал clicked),
// поле ввода — получает фокус (Esc — назад к стрелкам). Рамка фокуса — тихая (1px акцент 0.5, заливка 0.12),
// рисуется поверх, сама ничего не перехватывает. Цели не регистрируются заранее — меню и общие страницы
// (SavedPage, ProfilePage, DeviceRow…) работают как есть. Не цель: kwSkip: true у MouseArea, слишком мелкие,
// скрытые (opacity/visible/свёрнутый Reveal) и «фоновые» (больше 85% площади root).
// Ставить поверх содержимого: KeyWalker { anchors.fill: <контейнер>; root: <что обходить>; flick: <Flickable> }.
Item {
    id: kw
    property Item root: null
    property Item flick: null              // прокрутить к цели, если она за краем
    property var current: null
    property bool active: false            // рамка видна с первой стрелки (мышью — без рамки)
    property real pad: 2
    signal edge(string dir)                // стрелка, по которой некуда идти (меню может обработать само)
    z: 1000

    function isMa(it) { return it.pressAndHoldInterval !== undefined && it.containsMouse !== undefined }
    function isTi(it) { return it.echoMode !== undefined && it.cursorPosition !== undefined }
    function rectOf(it) { const p = it.mapToItem(kw, 0, 0); return Qt.rect(p.x, p.y, it.width, it.height) }
    // видна ли цель сквозь все обрезающие предки (свёрнутый Reveal, Flickable)
    function shown(it) {
        let p = it.parent
        const r0 = it.mapToItem(null, it.width / 2, it.height / 2)
        while (p && p !== kw.parent) {
            if (p.clip) {
                const q = p.mapFromItem(null, r0.x, r0.y)
                if (q.x < 0 || q.y < 0 || q.x > p.width || q.y > p.height) {
                    if (p !== flick) return false          // вне видимой части Flickable — можно докрутить
                }
            }
            p = p.parent
        }
        return true
    }
    function targets() {
        const out = []
        if (!root) return out
        const area = root.width * root.height
        function walk(it, op) {
            if (!it || !it.visible) return
            const o = op * (it.opacity === undefined ? 1 : it.opacity)
            if (o < 0.08) return
            if (it !== kw && it.width >= 6 && it.height >= 6 && it.enabled && !it.kwSkip) {
                if ((isMa(it) && it.width * it.height < area * 0.85) || (isTi(it) && !it.readOnly)) {
                    if (shown(it)) out.push(it)
                }
            }
            const ch = it.children
            for (let i = 0; i < ch.length; i++) walk(ch[i], o)
        }
        walk(root, 1)
        return out
    }
    // цель ещё видна? (страница ушла, Reveal свернулся, строка исчезла)
    function alive(it) {
        if (!it || !it.visible || !it.enabled || !root) return false
        let o = 1, p = it
        while (p && p !== root.parent) { o *= (p.opacity === undefined ? 1 : p.opacity); if (!p.visible || o < 0.08) return false; p = p.parent }
        return !!p && shown(it)
    }
    function centerOf(it) { const r = rectOf(it); return { x: r.x + r.width / 2, y: r.y + r.height / 2, r: r } }

    function first() {
        const t = targets()
        if (!t.length) return null
        t.sort((a, b) => { const A = centerOf(a), B = centerOf(b); return Math.abs(A.y - B.y) > 6 ? A.y - B.y : A.x - B.x })
        return t[0]
    }
    // dir: up/down/left/right → true, если сдвинулись
    function move(dir) {
        const t = targets()
        if (!t.length) return false
        if (!current || t.indexOf(current) < 0 || !active) {
            const keep = current && t.indexOf(current) >= 0 && !active
            if (!keep) current = first()
            active = true; follow(); return true
        }
        const c = centerOf(current)
        let best = null, score = 1e9
        for (const it of t) {
            if (it === current) continue
            const p = centerOf(it), dx = p.x - c.x, dy = p.y - c.y
            const sameRow = Math.abs(dy) < Math.max(10, Math.min(c.r.height, p.r.height) / 2)
            let s = -1
            if (dir === "down" && dy > 6 && !sameRow) s = dy * 4 + Math.abs(dx)
            else if (dir === "up" && dy < -6 && !sameRow) s = -dy * 4 + Math.abs(dx)
            else if (dir === "right" && sameRow && dx > 4) s = dx
            else if (dir === "left" && sameRow && dx < -4) s = -dx
            if (s >= 0 && s < score) { score = s; best = it }
        }
        if (!best) { edge(dir); return false }
        current = best; follow(); return true
    }
    // Enter: поле — фокус; кнопка — нажать
    function press() {
        if (!current || !active) { move("down"); return true }
        if (isTi(current)) { current.forceActiveFocus(); return true }
        current.clicked(null)
        Qt.callLater(kw.recheck)
        return true
    }
    // после нажатия список целей мог измениться — остаться на той же, иначе ближайшая
    function recheck() {
        if (!active) return
        const t = targets()
        if (current && t.indexOf(current) >= 0) { follow(); return }
        current = t.length ? first() : null
        follow()
    }
    function reset() { active = false; current = null }
    // ближайший Flickable над целью (в меню их может быть несколько — список и детали)
    function flickOf(it) {
        let p = it ? it.parent : null
        while (p && p !== kw.parent) { if (p.contentY !== undefined && p.contentItem !== undefined && p.contentHeight !== undefined) return p; p = p.parent }
        return flick
    }
    function follow() {
        if (!current) return
        const flick = flickOf(current)
        if (flick && flick.contentItem) {
            const p = current.mapToItem(flick.contentItem, 0, 0)
            const top = flick.contentY, bot = flick.contentY + flick.height
            if (p.y < top + 4) flick.contentY = Math.max(0, p.y - 8)
            else if (p.y + current.height > bot - 4) flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), p.y + current.height - flick.height + 8)
        }
        place()
    }
    function place() {
        if (!current || !active) return
        const r = rectOf(current)
        ring.x = r.x - pad; ring.y = r.y - pad; ring.width = r.width + pad * 2; ring.height = r.height + pad * 2
    }
    // анимации раскрытия двигают цели — рамка догоняет
    Timer { interval: 60; repeat: true; running: kw.active && kw.visible
            onTriggered: { if (kw.alive(kw.current)) kw.place(); else { kw.current = null; const f = kw.first(); kw.current = f; kw.place() } } }

    Rectangle {
        id: ring
        visible: kw.active && kw.current !== null
        radius: Math.min(Theme.radius, height / 2)      // «Остров»: скругление как у строк
        color: Colors.alpha(Colors.acc, 0.10)
        border.width: 1.5; border.color: Colors.alpha(Colors.acc, 0.8)
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSoft } }
        Behavior on y { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSoft } }
        Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSoft } }
        Behavior on height { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSoft } }
    }
}
