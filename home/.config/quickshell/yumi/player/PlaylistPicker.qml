import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// ♡ — «Добавить в плейлист»: список плейлистов yumi-music (как лист выбора в yumi-menu-music), клик — pl-add.
Item {
    id: root
    signal done()
    Component.onCompleted: Player.requestPlaylists()

    ColumnLayout {
        anchors.fill: parent
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Добавить в плейлист"; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium   // «Остров»: как ISection
                   font.capitalization: Font.AllUppercase; font.letterSpacing: 1; color: Colors.fgDim; Layout.fillWidth: true; Layout.leftMargin: 4 }
            Text { text: "Отмена"; font.family: Theme.fontUi; font.pixelSize: 12; color: cancel.containsMouse ? Colors.fg : Colors.fgDim
                   MouseArea { id: cancel; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: root.done() } }
        }
        Text { text: (Player.artist ? Player.artist + " — " : "") + Player.title; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
               color: Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true; Layout.leftMargin: 2 }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 2
            model: Player.playlists
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width; height: 44; radius: Theme.radius           // «Остров»: как IRow
                color: area.containsMouse ? Colors.isl2 : "transparent"
                scale: area.pressed ? 0.985 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 12; spacing: 12
                    Rectangle { implicitWidth: 32; implicitHeight: 32; radius: 11; color: Colors.isl2
                                Text { anchors.centerIn: parent; text: "󰲸"; font.family: Theme.fontIcon; font.pixelSize: 15; color: Colors.fg } }
                    Text { text: row.modelData.short; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: row.modelData.count; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
                }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { Player.addToPlaylist(row.modelData.id); root.done() } }
            }
        }
        Text { visible: Player.playlists.length === 0; text: "Нет плейлистов yumi-music"; font.family: Theme.fontUi
               font.pixelSize: Theme.fontSize; color: Colors.fgDim; Layout.alignment: Qt.AlignHCenter }
    }
}
