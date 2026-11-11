import QtQuick
import Quickshell.Io

// Загрузка по ядрам из /proc/stat (раз в 2 с, только пока active): cores — доли 0..1 по каждому ядру.
// Бэкенд top отдаёт только общий процент, а столбики ядер «Острова» нужны поштучно — читаем сами, без процессов.
Item {
    id: root
    property bool active: false
    property var cores: []
    property var prev: []
    FileView { id: stat; path: "/proc/stat"; printErrors: false }
    function sample() {
        stat.reload()
        const lines = String(stat.text() || "").split("\n").filter(l => /^cpu\d+ /.test(l))
        const now = lines.map(l => { const v = l.trim().split(/\s+/).slice(1).map(Number); const idle = v[3] + (v[4] || 0); return [v.reduce((a, b) => a + b, 0), idle] })
        if (prev.length === now.length) cores = now.map((c, i) => { const dt = c[0] - prev[i][0], di = c[1] - prev[i][1]; return dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0 })
        else cores = now.map(() => 0)
        prev = now
    }
    Timer { interval: 2000; repeat: true; running: root.active; triggeredOnStart: true; onTriggered: root.sample() }
    onActiveChanged: if (!active) prev = []
}
