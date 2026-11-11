pragma Singleton
import QtQuick

// Общее состояние подсказок бара: какой модуль под курсором и что показать.
// Окно Tooltip на каждом экране само решает, его ли это модуль (по окну модуля).
QtObject {
    id: root
    property Item target: null
    property string text: ""          // при скрытии не очищается — затухает старый текст
    function show(item, html) { text = html; target = item }
    function hide(item) { if (!item || target === item) target = null }
}
