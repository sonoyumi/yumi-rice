import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components

// Значок приложения: из .desktop (имя значка или путь находит бэкенд, как app_icon в yumi-menu-top) или Nerd-глиф по имени.
Item {
    id: root
    property string name: ""
    property string icon: ""               // имя значка темы или путь к файлу от бэкенда
    property int size: 18
    property color tone: Colors.acc
    readonly property var glyphs: ({ zen: "󰖟", firefox: "󰈹", kitty: "󰄛", code: "󰨞", telegram: "", python: "󰌠", node: "󰎙",
                                     hyprland: "", waybar: "󰕮", quickshell: "󰕮", pipewire: "󰕾", wireplumber: "󰕾",
                                     solaar: "󰍽", steam: "󰓓", discord: "󰙯", vesktop: "󰙯", spotify: "󰓇", chromium: "", obs: "󰑋" })
    readonly property string key: name.toLowerCase()
    readonly property string iconPath: !icon ? "" : (icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true))
    readonly property string glyph: {
        for (const k in glyphs) if (key.indexOf(k) >= 0) return glyphs[k]
        return "󰓅"
    }
    implicitWidth: size + 4; implicitHeight: size + 4
    IconImage { anchors.centerIn: parent; visible: root.iconPath.length > 0; source: root.iconPath; implicitSize: root.size }
    Glyph { anchors.centerIn: parent; visible: root.iconPath.length === 0; text: root.glyph; color: root.tone; font.pixelSize: root.size }
}
