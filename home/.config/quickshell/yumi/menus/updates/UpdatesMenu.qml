import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi
import qs.menus.system

// Компактное меню обновлений — «Остров» (29.10): шапка, счёт по источникам плитками (pacman · AUR · Flatpak), пакеты строками
// IRow по источникам, замороженные пакеты (IgnorePkg из /etc/pacman.conf, версии — pacman -Q), кнопка. Бэкап — своё меню menus/backup.
// Прежде пилюля обновлений открывала полноэкранное меню «Система» (sysmenu toggleAt) — теперь открывает этот попап;
// полноэкранный дашборд остаётся за пилюлей Arch (menu toggle system). Данные — тот же бэкенд ~/.local/lib/yumi/qs/system
// (свой экземпляр SysData, живёт пока меню открыто). Открыть/закрыть: qs -c yumi ipc call menu toggle updates.
// Клавиши: ↑↓ прокрутка списка, ↵ — «Обновить систему», Esc / клик мимо — закрыть.
Scope {
    id: menu
    readonly property bool open: Menus.current === "updates"

    // данные обновлений (тот же бэкенд, что у меню «Система»)
    SysData { id: sys; wanted: menu.open }

    readonly property var mgrName: ({ pacman: "pacman", paru: "AUR", yay: "AUR", flatpak: "flatpak" })
    function plural(n, one, few, many) {
        const a = n % 10, b = n % 100
        return a === 1 && b !== 11 ? one : (a >= 2 && a <= 4 && (b < 12 || b > 14)) ? few : many
    }

    readonly property int updTotal: sys.recs ? sys.recs.reduce((a, r) => a + r[1], 0) : 0
    readonly property int updListTotal: sys.updList ? Object.values(sys.updList).reduce((a, v) => a + v.length, 0) : 0
    readonly property bool anyUpd: (sys.updList ? updListTotal : updTotal) > 0
    // разбивка по менеджерам: [{ name, count, pkgs:[[пакет, старая, новая]] }]
    readonly property var updSections: {
        if (!sys.updList) return []
        const out = []
        for (const name in sys.updList) { const p = sys.updList[name]; if (p.length) out.push({ name: mgrName[name] || name, count: p.length, pkgs: p }) }
        return out
    }

    function subtitle() {
        if (sys.listing) return "Проверяю обновления…"
        if (!sys.loaded) return "…"
        if (!sys.recs && !sys.updList) return "нажмите «Обновить», чтобы проверить"
        const n = sys.updList ? updListTotal : updTotal
        if (n === 0) return "Система обновлена"
        const src = sys.recs ? sys.recs.filter(r => r[1] > 0).map(r => (mgrName[r[0]] || r[0]) + " " + r[1]).join(" · ") : ""
        return n + " " + plural(n, "обновление", "обновления", "обновлений") + (src ? " · " + src : "")
    }

    // загрузить список пакетов, когда бэкенд готов и меню открыто
    function refresh() { if (open && sys.loaded && !sys.listing) sys.listUpdates() }
    onOpenChanged: if (open) { refresh(); frozenProc.running = true; showAllFrozen = false }

    // ---- счёт по источникам: pacman · AUR · Flatpak ----
    function countOf(kind) {
        const src = sys.updList ? Object.keys(sys.updList).map(k => [k, sys.updList[k].length]) : (sys.recs || [])
        return src.filter(r => (kind === "aur" ? (r[0] === "paru" || r[0] === "yay") : r[0] === kind)).reduce((a, r) => a + r[1], 0)
    }

    // ---- замороженные пакеты: IgnorePkg из pacman.conf и их версии ----
    property var frozen: []                   // [[пакет, версия]]
    property bool showAllFrozen: false
    property var frozenAcc: []
    Process {
        id: frozenProc
        command: ["sh", "-c", "p=$(sed -n 's/^[[:space:]]*IgnorePkg[[:space:]]*=//p' /etc/pacman.conf | tr '\\n' ' '); [ -n \"$p\" ] && pacman -Q $p 2>/dev/null; true"]
        stdout: SplitParser { onRead: (l) => { const p = l.trim().split(/\s+/); if (p.length >= 2) menu.frozenAcc.push([p[0], p[1]]) } }
        onStarted: menu.frozenAcc = []
        onExited: menu.frozen = menu.frozenAcc.slice()
    }

    Connections { target: sys
        function onLoadedChanged() { menu.refresh() }
        function onLaunched(key) { Menus.close("updates") }   // «Обновить» ушло в терминал — закрыть карточку
    }

    // проверка: qs -c yumi ipc call updmenu state
    IpcHandler {
        target: "updmenu"
        function state(): string {
            return JSON.stringify({ open: menu.open, loaded: sys.loaded, listing: sys.listing,
                                    total: menu.updListTotal || menu.updTotal, sections: menu.updSections.length,
                                    frozen: menu.frozen.length })
        }
    }

    PillCard {
        id: pop
        name: "updates"
        open: menu.open
        screen: Menus.screen
        marginRight: 200
        pad: 18
        contentW: 400                          // «Остров»: как в превью
        readonly property int maxH: 640
        // окно постоянного размера (fixedH), высоту анимирует карточка внутри — иначе слой переконфигурируется каждый кадр
        fixedH: maxH + pad * 2
        contentH: Math.min(body.implicitHeight, maxH - bottom.implicitHeight - 12) + bottom.implicitHeight + 12 + pad * 2

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            function scrollBy(dy) { flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + dy)) }
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) Menus.close("updates")
                else if (e.key === Qt.Key_Up) scope.scrollBy(-60)
                else if (e.key === Qt.Key_Down) scope.scrollBy(60)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) updBtn.clicked()
                else return
                e.accepted = true
            }
            Connections { target: menu; function onOpenChanged() { if (menu.open) scope.forceActiveFocus() } }

            Flickable {
                id: flick
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.bottom: bottom.top; anchors.bottomMargin: 12
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                Behavior on contentY { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: body
                    width: flick.width
                    spacing: 12

                    CardHead {
                        title: "Обновления"; status: menu.subtitle(); dry: sys.dry
                        MSpinner { visible: sys.listing }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3; columnSpacing: 8; rowSpacing: 8
                        Repeater {
                            model: [["pacman", "pacman"], ["AUR", "aur"], ["Flatpak", "flatpak"]]
                            IStat { required property var modelData; Layout.preferredWidth: 1
                                    label: modelData[0]; value: sys.recs || sys.updList ? String(menu.countOf(modelData[1])) : "—" }
                        }
                    }

                    // пакеты по источникам
                    Repeater {
                        model: menu.updSections
                        ColumnLayout {
                            id: sec
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true; spacing: 0
                            ISection { text: sec.modelData.name + " · " + sec.modelData.count; Layout.bottomMargin: 4 }
                            Repeater {
                                model: sec.modelData.pkgs
                                IRow {
                                    id: pkgRow
                                    required property var modelData
                                    required property int index
                                    icon: "󰚰"; title: modelData[0]
                                    sub: modelData[1] ? modelData[1] + " → " + modelData[2] : modelData[2]
                                    hoverable: false
                                    // каскад: только первые 12 строк раздела (40 мс на строку), остальные — сразу
                                    opacity: index < 12 ? 0 : 1
                                    Component.onCompleted: if (index < 12) fadeIn.start()
                                    SequentialAnimation { id: fadeIn
                                        PauseAnimation { duration: index * Theme.cascade }
                                        NumberAnimation { target: pkgRow; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                    Text { visible: sys.updList !== null && menu.updListTotal === 0; Layout.fillWidth: true; leftPadding: 10
                           text: "Новых версий нет. Система обновлена."; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }

                    // замороженные пакеты (IgnorePkg)
                    ColumnLayout {
                        visible: menu.frozen.length > 0
                        Layout.fillWidth: true; spacing: 0
                        ISection { text: "Заморожено · " + menu.frozen.length; Layout.bottomMargin: 4 }
                        Repeater {
                            model: menu.showAllFrozen ? menu.frozen : menu.frozen.slice(0, 3)
                            IRow {
                                required property var modelData
                                icon: "󰐃"; title: modelData[0]; sub: "заморожено · не обновляется"; hoverable: false
                                Text { text: modelData[1]; font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim
                                       Layout.maximumWidth: 120; elide: Text.ElideLeft }
                            }
                        }
                        IChip {
                            visible: menu.frozen.length > 3
                            Layout.leftMargin: 10; Layout.topMargin: 4
                            text: menu.showAllFrozen ? "Свернуть" : "Ещё " + (menu.frozen.length - 3)
                            onClicked: menu.showAllFrozen = !menu.showAllFrozen
                        }
                    }

                    Text { visible: menu.updSections.length > 0; Layout.fillWidth: true; leftPadding: 10; wrapMode: Text.Wrap
                           text: "Откат обновления: sudo snapper -c root undochange ДО..ПОСЛЕ"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                }
            }

            // ---- низ: кнопка «Обновить» и подсказки клавиш ----
            ColumnLayout {
                id: bottom
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                spacing: 10
                IButton {
                    id: updBtn
                    Layout.fillWidth: true
                    primary: true
                    icon: "󰚰"; text: "Обновить систему"
                    onClicked: sys.launch("update")
                }
                CardHints { items: [["↑↓", "прокрутка"], ["↵", "обновить"], ["Esc", "закрыть"]] }
            }
        }
    }
}
