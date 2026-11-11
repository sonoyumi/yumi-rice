import QtQuick
import qs

// «Курсор ушёл далеко» (как FAR в yumipanel.py): кормить точками track(x, y) в координатах экрана; если точка
// дальше Theme.menuFar от прямоугольника rect и держится там Theme.menuLeaveMs — сигнал far(). Возврат ближе
// (или reset(), когда курсор над самой карточкой) — отмена. Общий для Popup и шторки уведомлений.
QtObject {
    id: root
    property bool enabled: true
    property rect rect: Qt.rect(0, 0, 0, 0)
    property bool away: false
    signal far()
    function track(x, y) {
        const r = rect, f = Theme.menuFar
        away = x < r.x - f || x > r.x + r.width + f || y < r.y - f || y > r.y + r.height + f
    }
    function reset() { away = false }
    onAwayChanged: if (away && enabled) timer.restart(); else timer.stop()
    onEnabledChanged: if (!enabled) timer.stop()
    property Timer timer: Timer { interval: Theme.menuLeaveMs; onTriggered: if (root.away && root.enabled) root.far() }
}
