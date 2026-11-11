import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components
import "Highlight.js" as HL

// «Быстрый просмотр» (Quick Look, «Остров», 30.10): карточка-остров по центру экрана с предпросмотром файла.
// Картинки (размер, точки), PDF (первые страницы через pdftoppm, ↑↓ — страница), видео (кадр + длительность; Пробел/Enter —
// открыть), аудио (обложка, теги, длительность), текст/код (первые 400 строк, моноширинный, подсветка), архивы (список
// bsdtar), папки (число и первые элементы), остальное — значок, размер, тип, даты. Данные — бэкенд ~/.local/lib/yumi/qs/quicklook.
// Клавиши: Esc / Пробел — закрыть, ←→ — соседний файл в папке, ↑↓ — страница PDF / прокрутка, Enter — открыть в программе.
//   qs -c yumi ipc call quicklook open <путь> | close | state       (кнопка: ~/.local/bin/yumi-quicklook — выделенное в Dolphin)
// YUMI_QS_SCREEN=eDP-1 — всегда этот монитор; YUMI_QS_NOKB=1 — без захвата клавиатуры.
Scope {
    id: ql
    property bool open: false
    property bool shown: false
    property string path: ""
    property var d: null                 // ответ бэкенда
    property bool loading: false
    property int page: 0                 // страница PDF
    property var screen: Quickshell.screens.length ? Quickshell.screens[0] : null
    readonly property string kind: d && d.ok ? d.kind : "error"
    readonly property string backend: Quickshell.env("HOME") + "/.local/lib/yumi/qs/quicklook"

    function show(p) {
        if (!p) return
        if (!open) {
            const want = Quickshell.env("YUMI_QS_SCREEN") || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            let s = null
            for (const sc of Quickshell.screens) if (sc.name === want) s = sc
            screen = s || (Quickshell.screens.length ? Quickshell.screens[0] : null)
            d = null
        }
        load(p)
        closer.stop(); shown = true; open = true
    }
    // один запрос за раз: пока бэкенд считает, следующий путь ждёт (быстрые ←→ — показывается последний)
    property string pending: ""
    function load(p) {
        path = p; loading = true
        if (proc.running) { pending = p; return }
        proc.command = [backend, p]
        proc.running = true
    }
    function close() { if (!open) return; open = false; closer.restart() }
    Timer { id: closer; interval: 260; onTriggered: { ql.shown = false; ql.d = null; ql.path = "" } }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null
                try { j = JSON.parse(text) } catch (e) { j = { ok: false, error: "Бэкенд не ответил", name: ql.path.split("/").pop(), path: ql.path } }
                if (ql.pending) { const p = ql.pending; ql.pending = ""; Qt.callLater(() => { proc.command = [ql.backend, p]; proc.running = true }); return }
                if (!ql.open) return
                ql.page = 0; ql.d = j; ql.loading = false
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.log("quicklook:", text.trim()) }
    }

    function sibling(dir) {
        if (!d || !d.siblings || d.siblings.length < 2) return
        const n = d.siblings.length
        load(d.siblings[(d.index + dir + n) % n])
    }
    function openApp() { if (d && d.path) { Quickshell.execDetached(["xdg-open", d.path]); close() } }
    function reveal() {
        if (!d || !d.path) return
        Quickshell.execDetached(["sh", "-c", 'command -v dolphin >/dev/null 2>&1 && exec dolphin --select "$1" || exec xdg-open "$(dirname "$1")"', "sh", d.path])
        close()
    }
    function pageStep(k) {
        if (kind !== "pdf" || !d.pageImgs) return false
        const n = d.pageImgs.length
        const p = Math.max(0, Math.min(n - 1, page + k))
        if (p === page) return false
        page = p; return true
    }

    IpcHandler {
        target: "quicklook"
        function open(path: string): void { ql.show(path) }
        function close(): void { ql.close() }
        function toggle(path: string): void { if (ql.open && ql.path === path) ql.close(); else ql.show(path) }
        function key(name: string): void { ql.key(name) }
        function state(): string {
            return JSON.stringify({ open: ql.open, path: ql.path, kind: ql.kind, loading: ql.loading, page: ql.page,
                                    index: ql.d ? ql.d.index : -1, count: ql.d && ql.d.siblings ? ql.d.siblings.length : 0,
                                    card: [Math.round(card.x), Math.round(card.y), Math.round(card.width), Math.round(card.height)] })
        }
    }
    function key(k) {
        if (k === "escape") close()
        else if (k === "space") { if (kind === "video") openApp(); else close() }
        else if (k === "enter") openApp()
        else if (k === "left") sibling(-1)
        else if (k === "right") sibling(1)
        else if (k === "up") { if (!pageStep(-1)) scrollBy(-120) }
        else if (k === "down") { if (!pageStep(1)) scrollBy(120) }
    }
    signal scrollBy(real dy)

    // ---- размеры карточки по виду ----
    readonly property real maxW: Math.min(1180, win.width - 120)
    readonly property real maxH: win.height - 140
    readonly property real headH: 64
    function fit(w, h, mw, mh) { const s = Math.min(1, mw / Math.max(1, w), mh / Math.max(1, h)); return { w: Math.round(w * s), h: Math.round(h * s) } }
    readonly property var bodySize: {
        const k = kind, bw = maxW - 32, bh = maxH - headH - 52
        if (!d) return { w: 520, h: 260 }
        if (k === "image") return fit(d.w || 800, d.h || 600, bw, bh)
        if (k === "pdf") { const r = fit(595, 842, bw, bh); return { w: Math.max(420, r.w), h: r.h } }
        if (k === "video") return fit(d.w || 1280, d.h || 720, Math.min(bw, 960), bh)
        if (k === "audio") return { w: 640, h: 240 }
        if (k === "text") return { w: Math.min(bw, 900), h: Math.min(bh, Math.max(140, (d.shown || 1) * 19 + 24)) }
        if (k === "archive") return { w: 620, h: Math.min(bh, 520, Math.max(140, (d.entries ? d.entries.length : 0) * 32 + 16)) }
        if (k === "folder") return { w: 620, h: Math.min(bh, 520, Math.max(140, (d.items ? d.items.length : 0) * 32 + 70)) }
        return { w: 560, h: 220 }
    }

    PanelWindow {
        id: win
        screen: ql.screen
        visible: ql.shown
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-quicklook"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: ql.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        Rectangle {   // лёгкое затемнение
            anchors.fill: parent
            color: Colors.deep
            opacity: ql.open ? 0.28 : 0
            Behavior on opacity { NumberAnimation { duration: ql.open ? 220 : 180 } }
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: ql.close() }

        FocusScope {
            anchors.fill: parent
            focus: ql.open
            Keys.onPressed: (e) => {
                const k = e.key
                if (k === Qt.Key_Escape) ql.key("escape")
                else if (k === Qt.Key_Space) ql.key("space")
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) ql.key("enter")
                else if (k === Qt.Key_Left) ql.key("left")
                else if (k === Qt.Key_Right) ql.key("right")
                else if (k === Qt.Key_Up) ql.key("up")
                else if (k === Qt.Key_Down) ql.key("down")
                else if (k === Qt.Key_PageUp) ql.key("up")
                else if (k === Qt.Key_PageDown) ql.key("down")
                else return
                e.accepted = true
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.max(660, ql.bodySize.w + 32)
                height: ql.bodySize.h + ql.headH + 44
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                property real grow: ql.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: ql.open ? Theme.menuOpen + 60 : Theme.fast; easing.type: ql.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.3 } }
                transform: Scale { origin.x: card.width / 2; origin.y: card.height / 2; xScale: 0.85 + 0.15 * card.grow; yScale: 0.85 + 0.15 * card.grow }
                opacity: Math.min(1, card.grow * 2.5)
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

                // ---- шапка ----
                RowLayout {
                    id: head
                    x: 18; y: 14; width: parent.width - 32
                    height: ql.headH - 14
                    spacing: 12
                    Item {
                        implicitWidth: 38; implicitHeight: 38
                        Rectangle { anchors.fill: parent; radius: 12; color: Colors.isl2 }
                        IconImage {
                            id: hicon
                            anchors.centerIn: parent
                            implicitSize: 24
                            source: ql.d ? (Quickshell.iconPath(ql.d.mimeIcon || "", true) || Quickshell.iconPath(ql.d.icon || "unknown", true)) : ""
                            visible: source != ""
                        }
                        Glyph { anchors.centerIn: parent; visible: !hicon.visible; text: "󰈔"; font.pixelSize: 20; color: Colors.acc }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: ql.d ? ql.d.name : ql.path.split("/").pop()
                            elide: Text.ElideMiddle
                            font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            text: ql.loading && !ql.d ? "Читаю…" : ql.subtitle()
                            elide: Text.ElideRight
                            font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                        }
                    }
                    IButton { implicitHeight: 34; text: "Открыть"; primary: true; visible: !!(ql.d && ql.d.ok); onClicked: ql.openApp() }
                    IButton { implicitHeight: 34; icon: "󰉋"; text: "Показать в папке"; visible: !!(ql.d && ql.d.ok); onClicked: ql.reveal() }
                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: 17
                        color: xma.containsMouse ? Colors.hover : Colors.isl2
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Text { anchors.centerIn: parent; text: "✕"; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.DemiBold; color: Colors.fg }
                        MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ql.close() }
                    }
                }

                // ---- содержимое ----
                Item {
                    id: body
                    x: 16; y: ql.headH + 4
                    width: parent.width - 32
                    height: parent.height - ql.headH - 44
                    clip: true
                    Loader {
                        anchors.fill: parent
                        active: ql.d !== null
                        opacity: ql.loading ? 0.5 : 1
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        sourceComponent: ({ image: imageView, pdf: pdfView, video: videoView, audio: audioView, text: textView,
                                            archive: listView, folder: listView })[ql.kind] || infoView
                    }
                }

                // ---- подвал: соседние файлы ----
                Item {
                    x: 16; width: parent.width - 32
                    y: parent.height - 34; height: 24
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!(ql.d && ql.d.siblings && ql.d.siblings.length > 1)
                        text: ql.d && ql.d.siblings ? (ql.d.index + 1) + " из " + ql.d.siblings.length + " в папке" : ""
                        font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                    }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Repeater {
                            model: ql.kind === "pdf" ? [["←→", "файл"], ["↑↓", "страница"], ["Enter", "открыть"], ["Esc", "закрыть"]]
                                 : ql.kind === "video" ? [["←→", "файл"], ["Пробел", "смотреть"], ["Esc", "закрыть"]]
                                 : [["←→", "файл"], ["Enter", "открыть"], ["Пробел", "закрыть"]]
                            Row {
                                required property var modelData
                                spacing: 5
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: kt.implicitWidth + 12; height: 18; radius: 7
                                    color: Colors.isl2; border.width: 1; border.color: Colors.edge
                                    Text { id: kt; anchors.centerIn: parent; text: modelData[0]; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.fg }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                            }
                        }
                    }
                }
            }
        }
    }

    function plural(n, a, b, c) { const m10 = n % 10, m100 = n % 100; return n + " " + (m10 === 1 && m100 !== 11 ? a : m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20) ? b : c) }
    function subtitle() {
        const x = d
        if (!x) return ""
        if (!x.ok) return x.error || "Не удалось прочитать"
        const p = []
        if (x.kind === "image") { if (x.w) p.push(x.w + " × " + x.h); p.push(x.sizeText) }
        else if (x.kind === "pdf") { p.push("PDF · " + plural(x.pages || 0, "страница", "страницы", "страниц")); if (x.pageImgs && x.pageImgs.length > 1) p.push("стр. " + (page + 1)); p.push(x.sizeText) }
        else if (x.kind === "video") { if (x.durationText) p.push(x.durationText); if (x.w) p.push(x.w + " × " + x.h); if (x.codec) p.push(x.codec); p.push(x.sizeText) }
        else if (x.kind === "audio") { if (x.durationText) p.push(x.durationText); if (x.codec) p.push(x.codec); if (x.bitrate) p.push(x.bitrate); p.push(x.sizeText) }
        else if (x.kind === "text") { p.push(plural(x.lines || 0, "строка", "строки", "строк")); p.push(x.sizeText) }
        else if (x.kind === "archive") { p.push("Архив · " + plural(x.files || x.count || 0, "файл", "файла", "файлов")); p.push(x.sizeText) }
        else if (x.kind === "folder") { p.push("Папка · " + plural(x.count || 0, "объект", "объекта", "объектов")) }
        else { p.push(x.mime); p.push(x.sizeText) }
        p.push(x.mtimeText)
        return p.filter(s => s).join(" · ")
    }

    // ================= виды =================
    Component {
        id: imageView
        Item {
            ClippingRectangle {
                anchors.centerIn: parent
                width: ql.bodySize.w; height: ql.bodySize.h
                radius: Theme.radius; color: Colors.isl2
                Image {
                    anchors.fill: parent
                    source: ql.d && ql.d.src ? "file://" + ql.d.src : ""
                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true; mipmap: true
                    sourceSize.width: Math.ceil(width * 2)
                }
            }
        }
    }
    Component {
        id: pdfView
        Item {
            ClippingRectangle {
                id: pg
                anchors.centerIn: parent
                width: Math.min(parent.width, ql.bodySize.h * 595 / 842 + 1); height: ql.bodySize.h
                radius: 10; color: "white"
                Image {
                    id: pimg
                    anchors.fill: parent
                    // страницы 2…12 бэкенд дорисовывает в фоне — пока файла нет, пробуем снова
                    readonly property string want: ql.d && ql.d.pageImgs && ql.d.pageImgs.length ? "file://" + ql.d.pageImgs[Math.min(ql.page, ql.d.pageImgs.length - 1)] : ""
                    property int tries: 0
                    source: want
                    onWantChanged: tries = 0
                    cache: false
                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true; mipmap: true
                    onStatusChanged: if (status === Image.Error && tries < 40) retry.restart()
                    Timer { id: retry; interval: 250; onTriggered: { pimg.tries++; pimg.source = ""; pimg.source = Qt.binding(() => pimg.want) } }
                }
                Text { anchors.centerIn: parent; visible: pimg.status !== Image.Ready; text: "Рисую страницу…"; font.family: Theme.fontUi; font.pixelSize: 12; color: "#777" }
            }
            // переключатель страниц
            Rectangle {
                visible: !!(ql.d && ql.d.pageImgs && ql.d.pageImgs.length > 1)
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                width: prow.implicitWidth + 16; height: 34; radius: 17
                color: Colors.alpha(Colors.isl, 0.94); border.width: 1; border.color: Colors.edge
                Row {
                    id: prow
                    anchors.centerIn: parent; spacing: 6
                    Pg { text: "󰅁"; onClicked: ql.pageStep(-1); dim: ql.page === 0 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: (ql.page + 1) + " / " + (ql.d ? ql.d.pages : 0)
                           font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fg }
                    Pg { text: "󰅂"; onClicked: ql.pageStep(1); dim: !ql.d || ql.page >= ql.d.pageImgs.length - 1 }
                }
            }
            Text {
                visible: !!(ql.d && ql.d.pages > (ql.d.pageImgs ? ql.d.pageImgs.length : 0) && ql.page === ql.d.pageImgs.length - 1)
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                text: "Показаны первые " + (ql.d && ql.d.pageImgs ? ql.d.pageImgs.length : 0) + " стр. — Enter откроет весь документ"
                font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
            }
        }
    }
    component Pg: Rectangle {
        property alias text: g.text
        property bool dim: false
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26; radius: 13
        color: pma.containsMouse && !dim ? Colors.hover : "transparent"
        opacity: dim ? 0.35 : 1
        Glyph { id: g; anchors.centerIn: parent; font.pixelSize: 16; color: Colors.fg }
        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    Component {
        id: videoView
        Item {
            ClippingRectangle {
                anchors.centerIn: parent
                width: ql.bodySize.w; height: ql.bodySize.h
                radius: Theme.radius; color: "black"
                Image {
                    anchors.fill: parent
                    source: ql.d && ql.d.thumb ? "file://" + ql.d.thumb : ""
                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                }
                Rectangle {   // кнопка «смотреть»
                    anchors.centerIn: parent
                    width: 76; height: 76; radius: 38
                    color: vma.containsMouse ? Colors.acc : Colors.alpha(Colors.isl, 0.82)
                    border.width: 1; border.color: Colors.edge
                    scale: vma.pressed ? 0.94 : vma.containsMouse ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Glyph { anchors.centerIn: parent; anchors.horizontalCenterOffset: 3; text: "󰐊"; font.pixelSize: 38; color: vma.containsMouse ? Colors.onAcc : Colors.fg }
                    MouseArea { id: vma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ql.openApp() }
                }
                Rectangle {
                    visible: !!(ql.d && ql.d.durationText)
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12
                    width: dt.implicitWidth + 16; height: 24; radius: 12
                    color: Colors.alpha(Colors.deep, 0.8)
                    Text { id: dt; anchors.centerIn: parent; text: ql.d ? ql.d.durationText || "" : ""; font.family: Theme.fontUi; font.pixelSize: 12
                           font.weight: Font.Medium; font.features: ({ "tnum": 1 }); color: Colors.fg }
                }
            }
        }
    }
    Component {
        id: audioView
        RowLayout {
            spacing: 22
            ClippingRectangle {
                Layout.preferredWidth: 220; Layout.preferredHeight: 220; Layout.alignment: Qt.AlignVCenter
                radius: Theme.radiusTile; color: Colors.isl2
                Image {
                    id: cov
                    anchors.fill: parent
                    source: ql.d && ql.d.cover ? "file://" + ql.d.cover : ""
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                    sourceSize.width: 440
                }
                Glyph { anchors.centerIn: parent; visible: cov.status !== Image.Ready; text: "󰎈"; font.pixelSize: 64; color: Colors.acc }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                spacing: 6
                Text { Layout.fillWidth: true; text: ql.d ? (ql.d.title || ql.d.name) : ""; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                       font.family: Theme.fontUi; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.fg }
                Text { Layout.fillWidth: true; visible: text.length > 0; text: ql.d ? (ql.d.artist || "") : ""; elide: Text.ElideRight
                       font.family: Theme.fontUi; font.pixelSize: 15; color: Colors.acc }
                Text { Layout.fillWidth: true; visible: text.length > 0; text: ql.d ? (ql.d.album || "") : ""; elide: Text.ElideRight
                       font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                Item { implicitHeight: 8 }
                Row {
                    spacing: 8
                    Repeater {
                        model: ql.d ? [ql.d.durationText, ql.d.codec, ql.d.bitrate, ql.d.rate].filter(s => s) : []
                        Rectangle {
                            required property var modelData
                            width: ct.implicitWidth + 18; height: 26; radius: 13; color: Colors.isl2
                            Text { id: ct; anchors.centerIn: parent; text: modelData; font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fg }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: textView
        Rectangle {
            radius: Theme.radius; color: Colors.alpha(Colors.deep, 0.6)
            border.width: 1; border.color: Colors.edge
            readonly property var lines: ql.d && ql.d.text !== undefined ? ql.d.text.split("\n") : []
            readonly property var pal: ({ kw: String(Colors.acc), str: "#a6da95", num: "#f5a97f", com: String(Colors.alpha(Colors.fg, 0.45)), fn: "#8aadf4" })
            readonly property int gutter: String(lines.length).length * 8 + 18
            ListView {
                id: tv
                anchors.fill: parent; anchors.margins: 10
                clip: true
                model: parent.lines
                boundsBehavior: Flickable.StopAtBounds
                Connections { target: ql; function onScrollBy(dy) { tv.contentY = Math.max(0, Math.min(tv.contentHeight - tv.height, tv.contentY + dy)) } }
                footer: Text {
                    visible: !!(ql.d && ql.d.truncated); height: visible ? 26 : 0; verticalAlignment: Text.AlignBottom
                    text: "…показаны первые " + (ql.d ? ql.d.shown : 0) + " из " + (ql.d ? ql.d.lines : 0) + " строк"
                    font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                }
                delegate: Row {
                    required property string modelData
                    required property int index
                    height: 19
                    Text { width: tv.parent.gutter; text: String(index + 1); horizontalAlignment: Text.AlignRight; rightPadding: 12
                           font.family: Theme.fontMono; font.pixelSize: 12; color: Colors.alpha(Colors.fg, 0.28) }
                    Text {
                        text: HL.line(modelData, ql.d ? ql.d.lang : "", tv.parent.pal)
                        textFormat: Text.StyledText
                        font.family: Theme.fontMono; font.pixelSize: 12; color: Colors.fg
                        width: tv.width - tv.parent.gutter; elide: Text.ElideRight
                    }
                }
            }
        }
    }
    Component {
        id: listView
        ColumnLayout {
            spacing: 8
            readonly property bool isFolder: ql.kind === "folder"
            readonly property var rows: !ql.d ? [] : isFolder ? (ql.d.items || []) : (ql.d.entries || [])
            Row {
                visible: isFolder
                spacing: 8
                Repeater {
                    model: ql.d && isFolder ? [plural(ql.d.dirs || 0, "папка", "папки", "папок"), plural(ql.d.files || 0, "файл", "файла", "файлов")] : []
                    Rectangle {
                        required property var modelData
                        width: ft.implicitWidth + 18; height: 26; radius: 13; color: Colors.isl2
                        Text { id: ft; anchors.centerIn: parent; text: modelData; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fg }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: Theme.radius; color: Colors.alpha(Colors.deep, 0.5)
                border.width: 1; border.color: Colors.edge
                ListView {
                    id: lv
                    anchors.fill: parent; anchors.margins: 6
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    model: rows
                    Connections { target: ql; function onScrollBy(dy) { lv.contentY = Math.max(0, Math.min(lv.contentHeight - lv.height, lv.contentY + dy)) } }
                    footer: Text {
                        readonly property int more: ql.d ? (isFolder ? (ql.d.count || 0) - rows.length : (ql.d.truncated ? (ql.d.count || 0) - rows.length : 0)) : 0
                        visible: more > 0; height: visible ? 28 : 0; leftPadding: 10; verticalAlignment: Text.AlignVCenter
                        text: "…и ещё " + more; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                    }
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: lv.width; height: 32; radius: 10
                        color: index % 2 ? "transparent" : Colors.alpha(Colors.fg, 0.03)
                        Glyph { id: rg; x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.dir ? "󰉋" : "󰈔"; font.pixelSize: 15
                                color: modelData.dir ? Colors.acc : Colors.fgDim }
                        Text {
                            anchors { left: rg.right; leftMargin: 10; right: rs.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: modelData.name; elide: Text.ElideMiddle
                            font.family: isFolder ? Theme.fontUi : Theme.fontMono; font.pixelSize: isFolder ? 13 : 12; color: Colors.fg
                        }
                        Text { id: rs; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                               text: modelData.sizeText || ""; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                    }
                }
            }
        }
    }
    Component {
        id: infoView
        RowLayout {
            spacing: 22
            Item {
                Layout.preferredWidth: 120; Layout.preferredHeight: 120; Layout.alignment: Qt.AlignVCenter
                IconImage {
                    id: big
                    anchors.fill: parent
                    source: ql.d ? (Quickshell.iconPath(ql.d.mimeIcon || "", true) || Quickshell.iconPath(ql.d.icon || "unknown", true)) : ""
                    visible: source != ""
                }
                Glyph { anchors.centerIn: parent; visible: !big.visible; text: ql.d && !ql.d.ok ? "󰀦" : "󰈔"; font.pixelSize: 72; color: Colors.acc }
            }
            GridLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                columns: 2; columnSpacing: 14; rowSpacing: 7
                Repeater {
                    model: !ql.d ? [] : !ql.d.ok ? [["Ошибка", ql.d.error || "?"], ["Путь", ql.d.path || ql.path]]
                         : [["Тип", ql.d.mime], ["Размер", ql.d.sizeText + " (" + Number(ql.d.size).toLocaleString(Qt.locale("ru_RU"), "f", 0) + " байт)"],
                            ["Изменён", ql.d.mtimeText], ["Создан", ql.d.ctimeText], ["Папка", ql.d.dir]]
                    Text {
                        required property var modelData
                        required property int index
                        Layout.row: index; Layout.column: 0
                        text: modelData[0]; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                    }
                }
                Repeater {
                    model: !ql.d ? [] : !ql.d.ok ? [ql.d.error || "?", ql.d.path || ql.path]
                         : [ql.d.mime, ql.d.sizeText + " (" + Number(ql.d.size).toLocaleString(Qt.locale("ru_RU"), "f", 0) + " байт)", ql.d.mtimeText, ql.d.ctimeText, ql.d.dir]
                    Text {
                        required property var modelData
                        required property int index
                        Layout.row: index; Layout.column: 1; Layout.fillWidth: true
                        text: modelData; elide: Text.ElideMiddle
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                    }
                }
            }
        }
    }
}
