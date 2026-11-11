import QtQuick
import QtQuick.Layouts
import qs

// «Остров» (29.10): строка-переключатель — значок в квадрате, подпись (и подпись помельче), переключатель справа
// (как .row с .tg в превью). checked задаёт родитель, toggled(on) — что хочет пользователь.
RowLayout {
    id: r
    property string icon: ""
    property string text: ""
    property string sub: ""
    property bool checked: false
    property color base: Colors.isl2
    signal toggled(bool on)
    Layout.fillWidth: true
    spacing: 12
    MIconSq { visible: r.icon.length > 0; icon: r.icon; size: 32; base: r.base }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 1
        MText { Layout.fillWidth: true; text: r.text; font.weight: Font.Medium; elide: Text.ElideRight }
        MText { Layout.fillWidth: true; visible: r.sub.length > 0; text: r.sub; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight }
    }
    MToggle { checked: r.checked; enabled: r.enabled; onToggled: on => r.toggled(on) }
}
