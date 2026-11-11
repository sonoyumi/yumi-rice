import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// «Стопка загрузок» (30.10): последние загрузки под островом — миниатюры картинок, имя, размер, куда легло, когда.
// Клик — открыть, правый клик / значок папки — показать в папке, перетаскивание строки в другое окно — файл
// (text/uri-list). Данные — ~/.cache/yumi/downloads-recent.json (пишет служба yumi-downloads), читаются через
// `downloads list` (без исчезнувших файлов). Открыть/закрыть: qs -c yumi ipc call downloads toggle.
// Бэкенд ~/.local/lib/yumi/qs/downloads. YP_DRYRUN=1 — открытие только печатается (бэкенд), YUMI_DL_RECENT — другая стопка.
Scope {
    id: menu
    readonly property bool open: Menus.current === "downloads"
    readonly property string backend: Quickshell.env("HOME") + "/.local/lib/yumi/qs/downloads"
    readonly property string recentPath: Quickshell.env("YUMI_DL_RECENT") || (Quickshell.env("HOME") + "/.cache/yumi/downloads-recent.json")
    property var items: []
    property bool dragging: false
    property real now: Date.now()

    function reload() { if (!listProc.running) listProc.running = true; else listAgain = true }
    property bool listAgain: false
    Process {
        id: listProc
        command: ["python3", "-I", menu.backend, "list"]
        stdout: StdioCollector { onStreamFinished: { try { const l = JSON.parse(text); menu.items = Array.isArray(l) ? l.slice(0, 8) : [] } catch (e) {} } }
        onExited: if (menu.listAgain) { menu.listAgain = false; running = true }
    }
    FileView {                                   // служба дописала загрузку — обновить, если открыто
        path: menu.recentPath; watchChanges: true; printErrors: false
        onFileChanged: if (menu.open) menu.reload()
    }
    onOpenChanged: if (open) { now = Date.now(); reload() }
    Timer { interval: 30000; repeat: true; running: menu.open; onTriggered: menu.now = Date.now() }

    function run(verb, id) { Quickshell.execDetached(["python3", "-I", menu.backend, verb, id]) }
    function ago(t) {
        const s = Math.max(0, Math.round(now / 1000 - t))
        if (s < 60) return "только что"
        if (s < 3600) return Math.floor(s / 60) + " мин назад"
        if (s < 86400) return Math.floor(s / 3600) + " ч назад"
        const d = new Date(t * 1000)
        return d.toLocaleDateString(Qt.locale("ru_RU"), "d MMM")
    }
    function kindIcon(k) {
        return ({ image: "󰋩", doc: "󰈙", archive: "󰗄", pkg: "󰏗", audio: "󰎈", video: "󰕧" })[k] || "󰈔"
    }
    function fileUri(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/") }

    IpcHandler {
        target: "downloads"
        function toggle(): void { Menus.toggle("downloads") }
        function state(): string { return JSON.stringify({ open: menu.open, items: menu.items.length, dragging: menu.dragging }) }
    }

    Popup {
        id: pop
        name: "downloads"
        open: menu.open
        screen: Menus.screen
        contentW: 400
        pad: 18
        holdOpen: menu.dragging
        contentH: body.implicitHeight + pad * 2

        ColumnLayout {
            id: body
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            spacing: 10

            CardHead {
                title: "Загрузки"
                status: menu.items.length ? "последние " + menu.items.length + " · тащи строку в окно" : "пока пусто"
                IButton { icon: "󰉋"; onClicked: { Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Downloads"]); Menus.close("downloads") } }
            }

            Text {
                visible: menu.items.length === 0
                Layout.fillWidth: true; leftPadding: 10; wrapMode: Text.Wrap
                text: "Новые загрузки появятся здесь — последние 20, с миниатюрами картинок."
                font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Repeater {
                    model: menu.items
                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Theme.radius
                        color: ma.containsMouse || ma.drag.active ? Colors.isl2 : "transparent"
                        scale: ma.pressed && !ma.drag.active ? 0.985 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                        readonly property bool isImg: modelData.kind === "image" && !/\.(svg|heic|heif|avif|ico|jxl)$/i.test(modelData.name)
                        // каскад 40 мс на строку
                        opacity: 0
                        Component.onCompleted: fadeIn.start()
                        SequentialAnimation { id: fadeIn
                            PauseAnimation { duration: row.index * Theme.cascade }
                            NumberAnimation { target: row; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 12
                            ClippingRectangle {
                                implicitWidth: 40; implicitHeight: 40; radius: 12
                                color: Colors.isl2
                                Glyph { anchors.centerIn: parent; text: menu.kindIcon(row.modelData.kind); font.pixelSize: 17; color: Colors.fg
                                        visible: !row.isImg || thumb.status !== Image.Ready }
                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    visible: row.isImg
                                    source: row.isImg ? menu.fileUri(row.modelData.path) : ""
                                    sourceSize.width: 96; sourceSize.height: 96
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { Layout.fillWidth: true; text: row.modelData.name; elide: Text.ElideMiddle
                                       font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                                Text { Layout.fillWidth: true; elide: Text.ElideRight
                                       text: row.modelData.sizeText + (row.modelData.folder ? " · " + row.modelData.folder : "") + " · " + menu.ago(row.modelData.time)
                                       font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                            }
                            Rectangle {      // показать в папке
                                implicitWidth: 30; implicitHeight: 30; radius: 15
                                color: fm.containsMouse ? Colors.hover : "transparent"
                                opacity: ma.containsMouse || fm.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                                Glyph { anchors.centerIn: parent; text: "󰉋"; font.pixelSize: 15; color: Colors.fgDim }
                                MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { menu.run("reveal", row.modelData.id); Menus.close("downloads") } }
                            }
                        }

                        // перетаскивание: системный drag (QDrag) с text/uri-list — файл в другое окно
                        Item {
                            id: proxy
                            width: row.width; height: row.height
                            Drag.active: ma.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.proposedAction: Qt.CopyAction
                            Drag.mimeData: ({ "text/uri-list": menu.fileUri(row.modelData.path) + "\r\n", "text/plain": row.modelData.path })
                            Drag.imageSource: row.isImg ? menu.fileUri(row.modelData.path) : ""
                            Drag.imageSourceSize: Qt.size(96, 96)          // миниатюра под курсором, не картинка целиком
                            Drag.onDragFinished: { menu.dragging = false; proxy.x = 0; proxy.y = 0 }   // карточка остаётся — можно тащить ещё
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent; z: -1
                            hoverEnabled: true; cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: proxy
                            drag.threshold: 8
                            onPressed: (e) => { if (e.button === Qt.LeftButton) { proxy.x = 0; proxy.y = 0 } }
                            drag.onActiveChanged: if (drag.active) menu.dragging = true
                            onClicked: (e) => {
                                if (e.button === Qt.RightButton) menu.run("reveal", row.modelData.id)
                                else menu.run("open", row.modelData.id)
                                Menus.close("downloads")
                            }
                        }
                    }
                }
            }

            CardHints { items: [["клик", "открыть"], ["ПКМ", "в папке"], ["тащи", "в окно"]] }
        }
    }
}
