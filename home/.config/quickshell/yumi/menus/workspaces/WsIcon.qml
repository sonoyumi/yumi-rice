import QtQuick
import Quickshell
import qs
import qs.components

// Значок приложения окна: из .desktop (имя/путь находит бэкенд, как gicon_for в yumi-menu-workspaces) или Nerd-глиф по классу.
// Картинка — в размере значка × devicePixelRatio экрана: ровно в точках, без мыла на MSI и ступенек на макбуке.
Item {
    id: root
    property string cls: ""
    property string icon: ""
    property int size: 15
    readonly property var glyphs: ({ firefox: "󰈹", kitty: "󰄛", code: "󰨞", telegram: "", steam: "󰓓",
                                     discord: "󰙯", spotify: "󰓇", chromium: "", obs: "󰑋", thunar: "󰉋", nautilus: "󰉋",
                                     btop: "󰨇", mpv: "󰕼", pavucontrol: "󰕾", solaar: "󰍽" })
    readonly property string glyph: {
        const k = cls.toLowerCase()
        for (const g in glyphs) if (k.indexOf(g) >= 0) return glyphs[g]
        return "󰣆"
    }
    readonly property string src: !icon ? "" : (icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true))
    implicitWidth: size; implicitHeight: size
    Image {
        anchors.fill: parent
        visible: root.src.length > 0 && status === Image.Ready
        source: root.src
        sourceSize.width: Math.ceil(root.size * Screen.devicePixelRatio); sourceSize.height: Math.ceil(root.size * Screen.devicePixelRatio)
        smooth: true; asynchronous: true; fillMode: Image.PreserveAspectFit
    }
    Glyph {
        anchors.centerIn: parent
        visible: root.src.length === 0
        text: root.glyph; color: Colors.acc; font.pixelSize: Math.round(root.size * 0.9)
    }
}
