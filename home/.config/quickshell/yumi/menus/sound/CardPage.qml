import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Выключенная карта (профиль «Выкл.»): только выбор профиля, чтобы снова появились её выходы и входы.
ColumnLayout {
    id: root
    property var menu
    property string card: ""
    readonly property var info: Sound.cardInfo(card)
    readonly property string title: "Звуковая карта"
    readonly property string subtitle: info ? info.desc : ""
    spacing: 6

    Connections { target: Sound; function onStateChanged() { if (Sound.ready && !root.info) { root.menu.pop(); Sound.toast("Карта пропала", false) } } }

    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; Layout.leftMargin: 6
           text: "Карта выключена. Выберите профиль, чтобы снова появились её выходы и входы." }
    Section { text: "Профиль" }
    ProfileList { card: root.info; Layout.fillWidth: true }
    Item { Layout.fillHeight: true }
}
