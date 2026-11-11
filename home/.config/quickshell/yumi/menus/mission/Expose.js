.pragma library
// Раскладка «Exposé» для Mission Control: окна сохраняют пропорции и общий масштаб (большое окно остаётся больше малого),
// ряды выбираются перебором 1…n — берётся вариант с наибольшим масштабом. Окна раскладываются по рядам сверху вниз
// по центру настоящего окна, в ряду — слева направо: миниатюра остаётся «рядом» со своим окном.
// items: [{ key, w, h, cx, cy }] (настоящие размеры, лог. px); area: { x, y, w, h }
// gap — зазор между миниатюрами, label — место под подписью у каждого ряда, maxScale — не крупнее этой доли.
// Возврат: { key: { x, y, w, h } } и порядок клавиатуры (по рядам) в поле order.

function layout(items, area, gap, label, maxScale) {
    const out = { order: [] }
    const n = items.length
    if (!n || area.w <= 0 || area.h <= 0) return out
    const byY = items.slice().sort((a, b) => (a.cy - b.cy) || (a.cx - b.cx))
    let best = null
    for (let r = 1; r <= n; r++) {
        const rows = []
        let i = 0
        for (let k = 0; k < r; k++) {
            const cnt = Math.floor(n / r) + (k < n % r ? 1 : 0)
            rows.push(byY.slice(i, i + cnt).sort((a, b) => a.cx - b.cx))
            i += cnt
        }
        let s = maxScale, hsum = 0
        for (const row of rows) {
            const wsum = row.reduce((t, o) => t + o.w, 0)
            s = Math.min(s, (area.w - gap * (row.length - 1)) / wsum)
            hsum += Math.max.apply(null, row.map(o => o.h))
        }
        s = Math.min(s, (area.h - gap * (r - 1) - label * r) / hsum)
        // при равном масштабе — меньше рядов (шире, спокойнее)
        if (!best || s > best.s * 1.02) best = { s: s, rows: rows }
    }
    const s = Math.max(0.05, best.s)
    const rowH = best.rows.map(row => Math.max.apply(null, row.map(o => o.h)) * s)
    const total = rowH.reduce((t, h) => t + h + label, 0) + gap * (best.rows.length - 1)
    let y = area.y + (area.h - total) / 2
    best.rows.forEach((row, ri) => {
        const rw = row.reduce((t, o) => t + o.w * s, 0) + gap * (row.length - 1)
        let x = area.x + (area.w - rw) / 2
        for (const o of row) {
            const w = o.w * s, h = o.h * s
            out[o.key] = { x: Math.round(x), y: Math.round(y + (rowH[ri] - h) / 2), w: Math.round(w), h: Math.round(h) }
            out.order.push(o.key)
            x += w + gap
        }
        y += rowH[ri] + label + gap
    })
    return out
}
