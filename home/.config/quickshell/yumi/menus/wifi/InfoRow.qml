import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Строка «Ключ   значение» (как yp.info_row); copy — клик копирует значение (wl-copy)
// «Остров» (29.10): ключ Onest 12 fgDim, значение 12 справа (табличные цифры).
RowLayout {
    id: root
    property string key: ""
    property string value: ""
    property bool copy: false
    property bool copied: false
    Layout.fillWidth: true
    visible: value.length > 0
    spacing: 10
    Text { text: root.key; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; Layout.minimumWidth: 86 }
    Text {
        Layout.fillWidth: true
        text: root.copied ? "скопировано" : root.value
        horizontalAlignment: Text.AlignRight; elide: Text.ElideMiddle
        font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: root.copied ? Colors.ok : Colors.fg
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        MouseArea {
            anchors.fill: parent; enabled: root.copy; cursorShape: Qt.PointingHandCursor
            onClicked: { Quickshell.execDetached(["wl-copy", root.value]); root.copied = true; back.restart() }
        }
    }
    Timer { id: back; interval: 1200; onTriggered: root.copied = false }
}
