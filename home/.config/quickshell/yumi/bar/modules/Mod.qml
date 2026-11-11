import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Модуль пилюли (label.module в Waybar): текст скрипта (script), значок (icon) или своё содержимое (дети).
// «Остров» (29.10): лежит в кнопке K; lit (кнопка открыла меню) — цвет ink = акцент вместо tone. Иероглифов (jp) больше нет.
// Цвет/бледность/свечение по классу задаёт Bar (tone, dim, glow…), как правила #custom-*.class в user-style.css.
// Клики и колесо — команды оболочки; без команды событие уходит в пилюлю. Подсказка — через 500 мс, Tips.
Item {
    id: m
    default property alias content: box.data
    property BarScript script: null
    property string icon: ""
    property bool noIcons: false                 // убрать значки из текста скрипта (раскладка «󰌌 RU» → «RU»)
    property bool iconOnly: false                // только значок из текста скрипта (бэкап «󰁯 4д» → «󰁯»), текст — в подсказке
    readonly property string scriptIcon: { const r = script ? script.raw : ""; const m = r.match(/[\uE000-\uF8FF]|[\uDB80-\uDBFF][\uDC00-\uDFFF]/); return m ? m[0] : "" }
    property int iconPx: Theme.barIcon
    property string cmd: ""
    property string cmdMid: ""
    property string cmdRight: ""
    property string cmdUp: ""
    property string cmdDown: ""
    property string tip: ""                      // своя подсказка; пусто — поле tooltip скрипта
    property color tone: Colors.fg
    property bool lit: false                     // кнопка K открыла своё меню — акцентом
    readonly property color ink: lit ? Colors.acc : tone
    property real dim: 1                         // opacity в покое (под курсором — 1)
    property bool glow: false
    property color glowColor: ink
    property real glowR: 3
    property real glowA: 0.35                    // 16.10: тише (было 0.75)
    property int minW: 0                         // min-length Waybar: ширина не прыгает
    readonly property string cls: script ? script.cls : ""
    readonly property var win: QsWindow.window          // окно бара — Tooltip сверяет, его ли это модуль
    readonly property bool hovered: ma.containsMouse
    function has(c) { return (" " + cls + " ").indexOf(" " + c + " ") >= 0 }
    function run(c) { if (c) Quickshell.execDetached(["sh", "-c", c]) }

    visible: script ? txt.raw.length > 0 : true     // не через txt.visible: это эффективная видимость, с родителем — петля
    implicitWidth: Math.max(minW, box.implicitWidth)
    implicitHeight: Math.max(box.implicitHeight, 22)

    RowLayout {
        id: box
        anchors.centerIn: parent
        spacing: 4
        opacity: m.hovered ? 1 : m.dim
        Behavior on opacity { NumberAnimation { duration: 200 } }
        ScriptText { id: txt; script: m.script; iconPx: m.iconPx; font.pixelSize: Theme.barFont; color: m.ink
                     font.features: ({ "tnum": 1 }); noIcons: m.noIcons; visible: m.script !== null && text.length > 0 && !m.iconOnly }
        Glyph { visible: (m.iconOnly ? m.scriptIcon : m.icon).length > 0; text: m.iconOnly ? m.scriptIcon : m.icon; font.pixelSize: m.iconPx; color: m.ink }
    }
    Glow { source: box; on: m.glow; color: m.glowColor; radius: m.glowR; strength: m.glowA; opacity: box.opacity }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        function cmdFor(b) { return b === Qt.LeftButton ? m.cmd : (b === Qt.MiddleButton ? m.cmdMid : m.cmdRight) }
        onPressed: (e) => { if (!cmdFor(e.button)) e.accepted = false }
        onClicked: (e) => m.run(cmdFor(e.button))
        onWheel: (w) => { const c = w.angleDelta.y > 0 ? m.cmdUp : m.cmdDown; if (c) m.run(c); else w.accepted = false }
        onEntered: delay.restart()
        onExited: { delay.stop(); Tips.hide(m) }
    }
    Timer {
        id: delay; interval: 500
        onTriggered: { const t = m.tip || (m.script ? m.script.tooltip : ""); if (t && ma.containsMouse) Tips.show(m, t) }
    }
}
