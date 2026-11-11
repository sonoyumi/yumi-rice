import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Последние уведомления в центре управления: из сервиса Notifs — живые (center) + архив history.json (items),
// без дублей по key, новые сверху, 3 штуки. «Все · N» → центр уведомлений (openAll), «Очистить» → Notifs.closeAll()
// (сервис сам чистит history.json). Пусто — «Нет уведомлений», кнопки скрыты.
ColumnLayout {
    id: list
    property int max: 3
    property bool shown: true          // для каскада
    property string kb: ""             // фокус клавиатуры шторки: "clear" | "all" | ""
    signal openAll()
    readonly property var items: {
        const out = [], seen = new Set()
        for (const e of Notifs.center) { if (e.key) seen.add(e.key); out.push({ app: e.app, summary: e.summary, body: e.body, t: e.time }) }
        for (const i of Notifs.items) { if (seen.has(i.key)) continue; seen.add(i.key); out.push({ app: i.app, summary: i.summary, body: i.body, t: i.time * 1000 }) }
        out.sort((a, b) => b.t - a.t)
        return out
    }
    spacing: 8

    function when(ms) {
        const d = new Date(ms), now = new Date()
        const diff = (now - d) / 1000
        if (diff < 60) return "только что"
        if (diff < 3600) return Math.floor(diff / 60) + " мин"
        if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, "HH:mm")
        return Qt.formatDate(d, "dd.MM") + " " + Qt.formatTime(d, "HH:mm")
    }
    function plain(s) { return String(s || "").replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim() }

    // «Остров» (29.10): подпись раздела ISection, справа «нет новых» / капсулы «Очистить» и «Все · N»;
    // уведомления — строки на подложке isl2 radius 16, каскадом
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text { text: "Уведомления"; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
               font.capitalization: Font.AllUppercase; font.letterSpacing: 1; color: Colors.fgDim; Layout.fillWidth: true }
        Text { visible: list.items.length === 0; text: "нет новых"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
        Chip { visible: list.items.length > 0; label: "Очистить"; ink: Colors.bad; kb: list.kb === "clear"; onClicked: Notifs.closeAll() }
        Chip { visible: list.items.length > 0; label: "Все · " + list.items.length; kb: list.kb === "all"; onClicked: list.openAll() }
    }
    Repeater {
        model: list.items.slice(0, list.max)
        delegate: Rectangle {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: col.implicitHeight + 20
            radius: Theme.radius
            color: nma.containsMouse ? Colors.hover : Colors.isl2
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            scale: nma.pressed ? 0.985 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
            opacity: list.shown ? 1 : 0
            Behavior on opacity { SequentialAnimation { PauseAnimation { duration: list.shown ? index * 40 : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
            RowLayout {
                id: col
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10; anchors.rightMargin: 12
                spacing: 12
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 34; implicitHeight: 34; radius: 12; color: Colors.hover
                    Glyph { anchors.centerIn: parent; text: "󰂚"; font.pixelSize: 16 }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: list.plain(modelData.app) || "Система"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: list.when(modelData.t); font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                    }
                    Text { text: list.plain(modelData.summary); font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { visible: text.length > 0; text: list.plain(modelData.body); font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 1 }
                }
            }
            MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: list.openAll() }
        }
    }
}
