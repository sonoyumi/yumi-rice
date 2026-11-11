import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Страница «Сохранённые сети» (как open_saved в yumi-menu-wifi): все профили NM, и тех сетей, которых сейчас нет рядом.
// Поиск — когда профилей больше 8. Клик по строке → страница профиля.
Flickable {
    id: page
    required property var owner
    readonly property bool shown: owner.page === "saved"
    readonly property int pageH: col.implicitHeight
    property string query: ""
    contentHeight: col.implicitHeight
    clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
    visible: opacity > 0; opacity: shown ? 1 : 0
    property real slide: shown ? 0 : (owner.page === "profile" ? -30 : 30)
    transform: Translate { x: page.slide }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    Behavior on slide { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
    onShownChanged: if (!shown) search.release()

    function matches(m) {
        const q = query.trim().toLowerCase()
        return !q || (m.ssid || "").toLowerCase().indexOf(q) >= 0 || (m.name || "").toLowerCase().indexOf(q) >= 0
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 6

        MField { id: search; Layout.fillWidth: true; visible: Network.profilesCount > 8; placeholder: "Поиск сети"
                 onTextChanged: page.query = text }
        RowLayout { visible: !Network.profilesLoaded; spacing: 8; Layout.leftMargin: 6
                    MSpinner {} MText { text: "Читаю профили…"; font.pixelSize: 12; color: Colors.fgDim } }
        MHint { visible: Network.profilesLoaded && Network.profilesCount === 0; text: "Сохранённых сетей нет"; font.pixelSize: 12 }

        Repeater {
            model: Network.profileModel
            delegate: Rectangle {
                id: row
                required property var model
                required property int index
                visible: page.matches(model)
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radius                        // «Остров»: строка IRow-вида, значок в квадрате 34
                color: m.containsMouse ? Colors.isl2 : (model.current === true ? Colors.alpha(Colors.acc, 0.16) : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                scale: m.pressed ? 0.985 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10; spacing: 12
                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: 12
                        color: row.model.current === true ? Colors.acc : Colors.isl2
                        Glyph { anchors.centerIn: parent; text: row.model.current === true ? "󰖩" : "󰆓"; font.pixelSize: 16
                                color: row.model.current === true ? Colors.onAcc : Colors.fg }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        MText { Layout.fillWidth: true; text: row.model.ssid || ""; elide: Text.ElideRight; font.weight: Font.Medium }
                        MText { Layout.fillWidth: true; text: row.model.sub || ""; elide: Text.ElideRight; font.pixelSize: 12; color: Colors.fgDim }
                    }
                    Glyph { text: "󰅂"; color: Colors.fgDim; font.pixelSize: 15 }
                }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: page.owner.openProfile(row.model.uuid) }
            }
        }
    }
}
