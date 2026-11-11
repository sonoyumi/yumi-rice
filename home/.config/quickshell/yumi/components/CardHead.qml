import QtQuick
import QtQuick.Layouts
import qs

// «Остров» (29.10): шапка карточки — название Onest 16 SemiBold, под ним строка состояния 12 приглушённо.
// jp — устарело (японских подписей нет, свойство оставлено для совместимости и не показывается).
// back — слева «‹» (страницы внутри меню), extra — справа (переключатель, кнопки; default-свойство).
// rule — по умолчанию нет: в «Острове» разделы разделяются отступами и подписями, а не чертами.
ColumnLayout {
    id: root
    property string title: ""
    property string jp: ""
    property string status: ""
    property color statusColor: Colors.fgDim
    property bool dry: false
    property bool back: false
    property bool rule: false
    default property alias extra: extraRow.data
    signal backClicked()
    Layout.fillWidth: true
    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            visible: root.back
            implicitWidth: 30; implicitHeight: 30; radius: 15
            color: backMa.containsMouse ? Colors.isl2 : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Glyph { anchors.centerIn: parent; text: String.fromCodePoint(0xf0141); font.pixelSize: 18; color: Colors.fg }
            MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.backClicked() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            RowLayout {
                spacing: 8
                Text { text: root.title; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg
                       Behavior on color { ColorAnimation { duration: Theme.normal } } }
                Text { visible: root.dry; text: "DRY-RUN"; font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Colors.acc }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.status
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 12
                color: root.statusColor
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
        }
        RowLayout { id: extraRow; spacing: 8 }
    }
    Rectangle {
        visible: root.rule
        Layout.fillWidth: true; Layout.topMargin: 8
        implicitHeight: 1
        color: Colors.edge
    }
}
