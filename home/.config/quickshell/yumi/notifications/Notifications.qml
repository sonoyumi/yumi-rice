import QtQuick
import Quickshell
import qs.services

// Уведомления: центр («шторка»). Сервер, журнал и IPC живут в синглтоне Notifs (services/Notifs.qml).
// «Остров» (29.10): всплывашки показывает центральный остров (island/Island.qml, очередь — island/IslandState.qml);
// своего окна всплывашек больше нет (Popups.qml — пустая заглушка для совместимости).
Scope {
    Center {}
    Component.onCompleted: Notifs.now = Date.now()   // создать синглтон (сервер занимает имя на шине) сразу при старте
}
