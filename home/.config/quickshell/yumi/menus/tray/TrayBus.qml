pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Общие данные трея для пилюли (bar/modules/Tray.qml) и меню (TrayMenu.qml): элементы штатного SystemTray,
// скрытые (~/.config/yumi/tray/hidden), описания yumi-tray (глиф/имя из $XDG_RUNTIME_DIR/yumi-tray/items.json, если демон жив),
// свои значки ~/.config/yumi/tray/icons/<ключ>.svg|.png, стиль ~/.config/yumi/tray/style: color (по умолчанию) | mono | dots (кружок цвета программы).
// requestMenu(item, x) — пилюля просит открыть меню этой программы под точкой x.
Singleton {
    id: root
    readonly property string cfg: Quickshell.env("HOME") + "/.config/yumi/tray/"
    signal requestMenu(var item, int x)

    // ---- описания yumi-tray ----
    property var descs: []
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1001") + "/yumi-tray/items.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.descs = JSON.parse(text()).items || [] } catch (e) { root.descs = [] } }
    }
    // ---- скрытые ----
    property var hiddenList: ["nm-applet", "blueman"]
    FileView {
        path: root.cfg + "hidden"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { const l = text().split("\n").map(s => s.trim().toLowerCase()).filter(s => s && s[0] !== "#"); if (l.length) root.hiddenList = l }
    }
    // ---- стиль ----
    property string style: "color"
    // цвета кружков стиля dots: адрес значка → цвет (общие для бара и меню, AppDot)
    property var dotColors: ({})
    property int dotRev: 0
    function setDot(k, c) { dotColors[k] = c; dotRev++ }
    FileView {
        path: root.cfg + "style"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { const v = text().trim().toLowerCase(); root.style = (v === "mono" || v === "dots") ? v : "color" }   // dots — кружки цвета программ (16.10)
        onLoadFailed: root.style = "color"
    }
    // ---- свои значки: имя файла без расширения (в нижнем регистре) → url ----
    property var custom: ({})
    FolderListModel {
        id: icons
        folder: "file://" + root.cfg + "icons"
        nameFilters: ["*.svg", "*.png"]
        showDirs: false
        onStatusChanged: root.rescan()
        onCountChanged: root.rescan()
    }
    function rescan() {
        const m = {}
        for (let i = 0; i < icons.count; i++) {
            const n = String(icons.get(i, "fileName"))
            m[n.replace(/\.(svg|png)$/i, "").toLowerCase()] = String(icons.get(i, "fileUrl"))
        }
        custom = m
    }
    // ключи сопоставления по порядку: Id элемента, ключ программы yumi-tray (app), имя значка, Title, отображаемое имя
    function keys(it, d) { return [it.id, d.app, d.iconName, it.title, d.name].filter(k => k).map(k => String(k).toLowerCase()) }
    function customIcon(it, d) { for (const k of keys(it, d)) if (custom[k]) return custom[k]; return "" }

    function describe(it) {
        let hit = null
        for (const x of descs) if (x.id === it.id && x.title === it.title) { hit = x; break }
        if (!hit) for (const x of descs) if (x.id === it.id) { hit = x; break }
        const iconName = String(it.icon || "").replace(/^image:\/\/icon\//, "").replace(/\?.*$/, "")
        if (hit) return { glyph: hit.glyph, name: hit.name, app: hit.app, finger: hit.finger, iconName: iconName }
        const name = it.tooltipTitle || it.title || it.id || "Программа"
        return { glyph: "󰀻", name: name, app: String(it.id || name).toLowerCase(), iconName: iconName,
                 finger: (it.id + " " + it.title + " " + iconName + " " + it.tooltipTitle).toLowerCase() }
    }
    function catRank(c) { return c === Category.Communications ? 0 : c === Category.ApplicationStatus ? 1 : 2 }
    // видимые программы: без скрытых, без Passive, одна на программу; сначала мессенджеры и приложения (как load_items)
    readonly property var list: {
        const vals = SystemTray.items.values, seen = {}, out = []
        for (const it of vals) {
            if (it.status === Status.Passive) continue
            const d = describe(it)
            if (hiddenList.some(h => h && d.finger.indexOf(h) >= 0)) continue
            if (seen[d.app]) continue
            seen[d.app] = true
            out.push({ item: it, d: d })
        }
        out.sort((a, b) => catRank(a.item.category) - catRank(b.item.category))
        return out
    }
}
