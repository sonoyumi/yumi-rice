import QtQuick
import QtQuick.Layouts
import qs

// «Остров» (29.10): мини-шкала заряда (как mini() превью) — подпись сверху, число 16 DemiBold, шкала 70×8 акцентом.
// value — 0..100 или -1 (нет данных: «—»); charging — значок молнии и шкала Colors.ok; stale — приглушённо (последний известный).
ColumnLayout {
    id: m
    property string label: ""
    property int value: -1
    property bool charging: false
    property bool stale: false
    property string note: ""
    spacing: 4
    Text { Layout.alignment: Qt.AlignHCenter; text: m.label; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: m.value < 0 ? "—" : (m.charging ? "󰂄 " : "") + m.value + "%"
        font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 })
        color: m.value < 0 || m.stale ? Colors.fgDim : m.value <= 20 && !m.charging ? Colors.bad : Colors.fg
    }
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 70; implicitHeight: 8; radius: 4
        color: Colors.alpha(Colors.fg, 0.14)
        Rectangle {
            height: parent.height; radius: 4
            width: parent.width * Math.max(0, Math.min(100, m.value)) / 100
            color: m.charging ? Colors.ok : Colors.acc
            opacity: m.stale ? 0.5 : 1
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
    Text { visible: m.note.length > 0; Layout.alignment: Qt.AlignHCenter; text: m.note; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
}
