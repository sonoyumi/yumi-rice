.pragma library
// Навигация по сетке приборной панели (вариант 10): плитки {r, c, w}. ←→ — соседняя в ряду (на краю — в соседний ряд),
// ↑↓ — ближайшая по центру в соседнем ряду. Возвращает новый индекс (или прежний, если идти некуда).
function nav(tiles, sel, d) {
    const t = tiles[sel]
    if (!t) return 0
    const rows = Math.max.apply(null, tiles.map(x => x.r)) + 1
    const rowOf = (r) => tiles.map((x, i) => i).filter(i => tiles[i].r === r).sort((a, b) => tiles[a].c - tiles[b].c)
    if (d === "left" || d === "right") {
        const row = rowOf(t.r)
        const k = row.indexOf(sel) + (d === "right" ? 1 : -1)
        if (k >= 0 && k < row.length) return row[k]
        if (d === "right" && t.r < rows - 1) return rowOf(t.r + 1)[0]
        if (d === "left" && t.r > 0) { const p = rowOf(t.r - 1); return p[p.length - 1] }
        return sel
    }
    const r = t.r + (d === "down" ? 1 : -1)
    if (r < 0 || r >= rows) return sel
    const c = t.c + (t.w - 1) / 2
    let best = sel, dist = 99
    tiles.forEach((x, i) => { if (x.r !== r) return; const dd = Math.abs(x.c + (x.w - 1) / 2 - c); if (dd < dist) { dist = dd; best = i } })
    return best
}

// окно истории для графиков: последние n точек
function push(arr, v, n) {
    const a = (arr || []).slice()
    a.push(v)
    while (a.length > (n || 44)) a.shift()
    return a
}

function plural(n, one, few, many) {
    n = Math.abs(n)
    if (n % 10 === 1 && n % 100 !== 11) return one
    if (n % 10 >= 2 && n % 10 <= 4 && !(n % 100 >= 12 && n % 100 <= 14)) return few
    return many
}
