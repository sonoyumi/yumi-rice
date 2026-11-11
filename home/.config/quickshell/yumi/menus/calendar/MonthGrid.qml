import QtQuick
import qs
import "Cal.js" as Cal

// Сетка одного месяца (6×7 ячеек, лишняя 6-я строка скрыта как в GTK). «Остров» (29.10): ячейки 36 px radius 12 с зазором 4,
// сегодня — акцентная плашка (число onAcc, жирное), выбранный — подложка isl2 с кромкой акцентом, дни с планами — точка
// (все выполнены — бледная), чужой месяц — бледно.
Item {
    id: grid
    property date month: new Date()          // первое число месяца
    property string today: ""
    property string sel: ""
    property var byDay: ({})                 // iso → { on, done }
    property int cellH: 36
    property int gap: 4
    readonly property int rows: Cal.gridRows(month)
    readonly property date start: Cal.addDays(month, -Cal.weekday(month))
    signal dayClicked(string isoDate)
    implicitHeight: rows * cellH + (rows - 1) * gap

    Grid {
        anchors.fill: parent
        columns: 7; rows: 6
        spacing: grid.gap
        Repeater {
            model: 42
            Rectangle {
                id: cell
                required property int index
                readonly property date d: Cal.addDays(grid.start, index)
                readonly property string key: Cal.iso(d)
                readonly property bool other: d.getMonth() !== grid.month.getMonth()
                readonly property bool isToday: key === grid.today
                readonly property bool isSel: key === grid.sel
                readonly property var ev: grid.byDay[key]
                width: (grid.width - 6 * grid.gap) / 7; height: grid.cellH
                visible: index < grid.rows * 7
                radius: 12
                color: isToday ? Colors.acc
                     : isSel ? Colors.isl2
                     : mouse.containsMouse ? Colors.isl2 : "transparent"
                border.width: isSel && !isToday ? 1.5 : (isSel ? 0 : 0)
                border.color: Colors.acc
                // 30.10: без затухания — подсветка уходившей ячейки тянулась «тенью» за выбором (как было в приложениях)
                scale: mouse.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }

                Text {
                    anchors.centerIn: parent
                    text: cell.d.getDate()
                    font.family: Theme.fontUi; font.pixelSize: 13
                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                    font.features: ({ "tnum": 1 })
                    color: cell.isToday ? Colors.onAcc : cell.other ? Colors.alpha(Colors.fg, 0.30) : Colors.fg
                }
                Rectangle {   // точка: в этот день есть планы
                    anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 9
                    width: 4; height: 4; radius: 2
                    visible: !!cell.ev
                    color: cell.isToday ? Colors.onAcc : Colors.acc
                    opacity: cell.ev && cell.ev.done ? 0.4 : 1
                }
                MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: grid.dayClicked(cell.key) }
            }
        }
    }
}
