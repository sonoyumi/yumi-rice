pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Сигналы снаружи вместо pkill -RTMIN+N waybar:
//   qs -c yumi ipc call bar refresh wifi      (имена: wifi bt vpn ppd workflow caffeine lang top updates tray cc player)
//   qs -c yumi ipc call bar toggle            — показать/скрыть бар
Singleton {
    id: root
    signal refresh(string name)
    // 19.10: виджет обоев поставил обои «из меню» — бар на этом экране появляется пружинкой (bar/Bar.qml)
    signal desktopPop(string screen)
    // 30.10: экран, где открыт выбор обоев: бар и остров там уезжают вверх; после применения возвращаются уже в новых цветах
    property string wallHide: ""
    property bool barVisible: true
    // вход при загрузке (lock/LockReal.qml): бар скрыт, пока вход «из логотипа» не растворился — иначе он
    // просвечивает (session_lock_xray), когда экран блокировки на кадр перестраивается (16.10, видео IMG_1201)
    property bool bootHold: false
    // 18.10: фоновая догрузка бара и меню (LazyLoader в shell.qml) отбирала кадры у интро экрана блокировки при
    // загрузке (пропуски 60–100 мс «на 90 %»). При загрузке системы — только после растворения интро
    // (LockReal: introGone) или через 6 с; при обычном перезапуске Quickshell — сразу.
    property bool lazyReady: false
    FileView { id: upFile; path: "/proc/uptime"; blockLoading: true; printErrors: false }
    Component.onCompleted: {
        const up = parseFloat((upFile.text() || "").split(" ")[0])
        if (!(up > 0 && up < 60)) lazyReady = true
    }
    Timer { running: !root.lazyReady; interval: 6000; onTriggered: root.lazyReady = true }
    // центр пилюли плеера по x на каждом экране (бар двигает её, если мешают соседи) — по нему встаёт остров
    property var playerCx: ({})
    function setPlayerCx(screen: string, cx: real): void {
        if (playerCx[screen] === cx) return
        const m = Object.assign({}, playerCx); m[screen] = cx; playerCx = m
    }

    IpcHandler {
        target: "bar"
        function refresh(name: string): void { root.refresh(name) }
        function toggle(): void { root.barVisible = !root.barVisible }
        function show(): void { root.barVisible = true }
        function hide(): void { root.barVisible = false }
    }
}
