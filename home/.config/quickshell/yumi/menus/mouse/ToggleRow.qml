import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.menus.wifi

// Строка с переключателем (yp.toggle_row). «Остров» (29.10): значок в квадрате 32 (isl2), подпись Onest Medium,
// переключатель справа. checked — из состояния, toggled(on) — желание.
RowLayout {
    id: root
    property string icon: ""
    property string text: ""
    property bool checked: false
    property bool toggleEnabled: true
    signal toggled(bool on)
    Layout.fillWidth: true
    Layout.leftMargin: 4; Layout.rightMargin: 2
    implicitHeight: 40
    spacing: 12
    MIconSq { visible: root.icon.length > 0; icon: root.icon; size: 32 }
    MText { text: root.text; Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.Medium }
    MToggle { checked: root.checked; enabled: root.toggleEnabled; onToggled: on => root.toggled(on) }
}
