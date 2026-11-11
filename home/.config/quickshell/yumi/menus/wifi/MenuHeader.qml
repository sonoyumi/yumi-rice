import QtQuick
import QtQuick.Layouts
import qs

// Шапка меню. «Остров» (29.10): как components/CardHead — название Onest 16 DemiBold, под ним состояние 12
// приглушённо (ошибка — Colors.bad), справа переключатель (IToggle-вид). Свойства прежние; icon, jp и rule оставлены
// для совместимости и не показываются (в «Острове» у шапки нет значка слева, иероглифов и черты).
ColumnLayout {
    id: root
    property string icon: ""               // устарело — не показывается
    property bool iconOn: true
    property string title: ""
    property string jp: ""                 // устарело — не показывается
    property string subtitle: ""
    property bool error: false
    property bool checked: false
    property bool toggleEnabled: true
    property bool showToggle: true
    property bool dry: false
    property bool rule: true               // устарело — черты нет
    default property alias extra: extraRow.data
    signal toggled(bool on)
    Layout.fillWidth: true
    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: root.title; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg
                       Behavior on color { ColorAnimation { duration: Theme.normal } } }
                Text { visible: root.dry; text: "DRY-RUN"; font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Colors.acc }
                Item { Layout.fillWidth: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle; elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 12
                color: root.error ? Colors.bad : Colors.fgDim
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
        }
        RowLayout { id: extraRow; spacing: 8 }
        MToggle { visible: root.showToggle; checked: root.checked; enabled: root.toggleEnabled; onToggled: on => root.toggled(on) }
    }
}
