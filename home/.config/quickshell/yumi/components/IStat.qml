import QtQuick
import QtQuick.Layouts
import qs

// «Остров»: плитка «подпись / значение» (сетка 2 колонки в меню питания, системы, VPN).
Rectangle {
    id: st
    property string label: ""
    property string value: ""
    Layout.fillWidth: true
    implicitHeight: 54; radius: 16
    color: Colors.isl2
    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 0
        Text { Layout.fillWidth: true; text: st.label; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
        Text { Layout.fillWidth: true; text: st.value; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold
               font.features: ({ "tnum": 1 }); color: Colors.fg }
    }
}
