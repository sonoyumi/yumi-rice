import QtQuick
import QtQuick.Layouts
import qs
import "Kb.js" as Kb
import qs.components

// Строка-кнопка (yp.row_button): значок, текст, пометка справа (meta), галочка у активной.
// Фон активной рисует родитель (DeviceList — ползущая подсветка) либо сама строка (ownHighlight).
Item {
    id: root
    property string icon: ""
    property string text: ""
    property string meta: ""
    property bool active: false
    property bool ownHighlight: true
    property bool dim: false
    property string tooltip: ""
    signal clicked()
    signal secondary()      // правый клик / долгое нажатие

    Layout.fillWidth: true
    implicitHeight: 48
    activeFocusOnTab: visible
    Keys.onPressed: (e) => {           // ↑↓ — фокус дальше, Enter/Пробел — нажать, «.» / Menu — настройки (как правый клик)
        if (Kb.nav(root, e)) return
        if (Kb.activate(e)) { root.clicked(); e.accepted = true }
        else if (e.key === Qt.Key_Period || e.key === Qt.Key_Menu) { root.secondary(); e.accepted = true }
    }
    scale: area.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius           // «Остров»: вид IRow; активная — подложка акцентом 0.16
        color: root.active && root.ownHighlight ? Colors.alpha(Colors.acc, 0.16)
             : (area.containsMouse ? Colors.isl2 : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    FocusRing { on: root.activeFocus }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 7; anchors.rightMargin: 10
        spacing: 12
        Rectangle {
            visible: root.icon.length > 0
            implicitWidth: 34; implicitHeight: 34; radius: 12
            color: root.active ? Colors.acc : Colors.isl2
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            Glyph { anchors.centerIn: parent; text: root.icon; font.pixelSize: 16
                    color: root.active ? Colors.onAcc : (root.dim ? Colors.fgDim : Colors.fg) }
        }
        Text { text: root.text; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
               color: root.dim ? Colors.fgDim : Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true
               Behavior on color { ColorAnimation { duration: Theme.normal } } }
        Text { visible: root.meta.length > 0; text: root.meta; font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
        Glyph { visible: root.active; text: "󰄬"; color: Colors.acc; font.pixelSize: 16 }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => { if (e.button === Qt.RightButton) root.secondary(); else root.clicked() }
        onPressAndHold: root.secondary()
    }
}
