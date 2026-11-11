import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import qs
import qs.services

// НАСТОЯЩИЙ экран блокировки (с 16.10.2026 основной, hyprlock — запасной): WlSessionLock + PAM.
// Вызывается через yumi-lock (hypridle → loginctl lock-session → yumi-lock --now, крышка, SUPER+N, вход в систему).
//   qs -c yumi ipc call lockscreen lock       заблокировать
//   qs -c yumi ipc call lockscreen boot       заблокировать «из логотипа» (вход при загрузке)
//   qs -c yumi ipc call lockscreen isLocked   yes / no
// Команды «разблокировать» нет намеренно: снять блокировку можно только паролем.
// Флаги в $XDG_RUNTIME_DIR (tmpfs, чистится при выходе):
//   yumi-locked        — экран заблокирован; пишет этот файл. Упал или перезапущен Quickshell — новый процесс
//                        видит флаг и блокирует снова (Hyprland держит сеанс: misc.allow_session_lock_restore).
//   yumi-lock-request  — запрос «boot» от yumi-lock --boot, пока Quickshell ещё не поднялся (вход при загрузке).
// Пароль — PAM-сервис hyprlock (auth include login): faillock считает неверные попытки так же, как у hyprlock.
// Touch ID (19.10.2026) — параллельно с паролем, PAM-сервис yumi-fingerprint (только pam_fprintd, без faillock):
// ждёт касания, пока экран заблокирован (при входе из логотипа — после растворения заставки); совпало — то же
// растворение, что после пароля; промах/таймаут — новое ожидание; нет сенсора (крышка, нет yumi-fingerprint) — раз в 5 с.
// Аварийно (по SSH, если Quickshell не может показать экран): запустить hyprlock в сеансе — он перехватит
// блокировку, разблокировать паролем.
Scope {
    id: root
    property string pending: ""                // введённый пароль ждёт запроса PAM
    property var asking: null                  // поверхность, с которой пришёл пароль
    property bool bootMode: false              // первый кадр — логотип загрузки, затем растворение
    // вход растворился: поверхности, созданные позже (MSI включается после входа — yumi-boot-monitors), появляются
    // обычным проявлением, а не загрузочным входом
    property bool introDone: false
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string flagPath: runDir + "/yumi-locked"
    readonly property string requestPath: runDir + "/yumi-lock-request"
    // Touch ID: fpOk — палец совпал (поверхности растворяются); fpState — подсказка: off | wait | miss
    property bool fpOk: false
    property string fpState: "off"
    property double fpStartedAt: 0
    property int fpQuickFails: 0               // быстрых отказов подряд (сенсор не поднялся / крышка закрыта)
    property bool pwOk: false                  // пароль принят (идёт растворение) — палец больше не ждём
    // Touch ID «armed» (/run/yumi-touchid/armed, tmpfs): ставится после первого ВЕРНОГО пароля. Пока флага нет
    // (первый экран после загрузки) — сканер НЕ запускаем: иначе requisite-отказ yumi-fingerprint даёт PAM
    // System error, и родитель PamContext застревает ~25 с (серый фон вместо замка). boot = только пароль.
    property bool fpArmed: false
    readonly property bool fpAllowed: sessionLock.locked && (!bootMode || introDone) && !fpOk && !pwOk && fpArmed
    // общий ввод (19.10): Hyprland отдаёт клавиатуру поверхности монитора под курсором — после сна это бывал MSI
    // с заглушкой, и на Mac ничего не менялось. Текст один на все поверхности, ответ PAM — тоже всем
    property string typed: ""
    signal authResult(string state, string err)     // checking | error | ok

    function fpStart(): void {
        if (!fpAllowed || fp.active) return
        fpStartedAt = Date.now()
        console.info("fp: запуск сканера →", fp.start())
    }
    function fpStop(): void {
        fpRetry.stop()
        if (fp.active) { console.info("fp: остановка"); fp.abort() }
        fpState = "off"
    }
    onFpAllowedChanged: { console.info("fp: разрешено =", fpAllowed); fpQuickFails = 0; if (fpAllowed) Qt.callLater(fpStart); else fpStop() }
    // сторож (19.10): экран заблокирован, палец разрешён, а сканер не ждёт и повтора нет — запустить.
    // После входа паролем повторная блокировка иногда оставалась без Touch ID (05:26), причина не поймана
    Timer {
        interval: 2000; repeat: true
        running: root.fpAllowed && !fp.active && !fpRetry.running
        onTriggered: { console.info("fp: сторож — сканер не ждал, запускаю"); root.fpStart() }
    }
    // сканер ждёт дольше 1,5 с — сенсор жив, подсказку показать (19.10: перед сном было 4 быстрых отказа
    // «Cannot run while suspended», после пробуждения палец ждали без подсказки)
    Timer {
        interval: 1500
        running: fp.active && root.fpState === "off"
        onTriggered: { root.fpQuickFails = 0; root.fpState = "wait" }
    }
    // после сна (hypridle after_sleep_cmd → ipc lockscreen wake): счётчик отказов сбросить, сканер сразу
    function wake(): void {
        fpQuickFails = 0
        console.info("lock-focus: пробуждение, заблокирован =", sessionLock.locked, "bootMode =", bootMode, "introDone =", introDone)
        snap("wake")
        if (sessionLock.locked && bootMode) leaveBoot("пробуждение")
        if (!fpAllowed || fp.active) return
        console.info("fp: пробуждение — запуск сканера")
        fpRetry.stop(); fpStart()
    }

    // 19.10: вход после загрузки не разблокировали, а закрыли крышку → после сна поверхность блокировки осталась без
    // клавиатуры (16:34 → 18:40, лечил только перезапуск Quickshell); утром, разблокировав до сна, — норма.
    // Повторный запрос блокировки (крышка/сон: yumi-lock --now) или пробуждение переводит вход в обычную блокировку:
    // заставка считается растворившейся, курсор — обычный, окно-заставка yumi-splash закрыто.
    function leaveBoot(why: string): void {
        console.info("lock-focus: режим загрузки → обычная блокировка:", why)
        if (!introDone) { introDone = true; Signals.lazyReady = true; Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yumi-boot-monitors"]) }
        bootMode = false; Signals.bootHold = false
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yumi-cursor-restore"])
        Quickshell.execDetached(["pkill", "-x", "yumi-splash"])
    }
    // диагностика фокуса (19.10): снимок Hyprland в $XDG_RUNTIME_DIR/yumi-lock-focus.log и журнал (yumi-lock-focus)
    function snap(why: string): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yumi-lock-focus-snap", why])
    }

    function lock(boot: bool): void {
        if (sessionLock.locked) { if (bootMode && !boot) leaveBoot("повторная блокировка"); return }
        fpOk = false; pwOk = false; typed = ""; armedFile.reload()
        bootMode = boot; introDone = false
        if (boot) Signals.bootHold = true
        Quickshell.execDetached(["touch", root.flagPath])
        sessionLock.locked = true
    }
    // снять блокировку — только после верного пароля (растворение закончилось); флаг удаляется здесь же,
    // не полагаясь на сигнал lockedChanged (16.10: он не удалил флаг)
    function unlock(): void {
        Quickshell.execDetached(["rm", "-f", root.flagPath])
        bootMode = false; asking = null; Signals.bootHold = false
        sessionLock.locked = false
        fpOk = false; pwOk = false; typed = ""
    }
    // 29.10: разблокировка с iPhone (phone unlock, PIN проверен там) — как верный пароль: растворение → unlock();
    // растворения не было за 4 с (например, вход ещё не показан) — снять блокировку напрямую
    function remoteUnlock(): void {
        if (!sessionLock.locked) return
        console.info("lock: разблокировка с iPhone")
        pwOk = true; Quickshell.execDetached(["touch", runDir + "/yumi-lock-pw-ok"]); fpStop(); authResult("ok", "")   // отметка — тачбар без «не распознан»
        remoteFallback.restart()
    }
    Timer { id: remoteFallback; interval: 4000; onTriggered: if (sessionLock.locked && root.pwOk) root.unlock() }

    IpcHandler {
        target: "lockscreen"            // не "lock": это имя занято превью
        function lock(): void { root.lock(false) }
        function boot(): void { root.lock(true) }
        function isLocked(): string { return sessionLock.locked ? "yes" : "no" }
        function wake(): void { root.wake() }
        function unlock(): void { root.remoteUnlock() }   // только для phone unlock (после проверки PIN)
    }

    // при старте процесса: прерванная блокировка → снова заблокировать; запрос входа → «из логотипа».
    // Быстрый путь — синхронное чтение флагов при загрузке конфига (до первого кадра бара); Process ниже —
    // запасной и убирает запрос. lock() повторно ничего не делает.
    FileView { path: root.flagPath; blockLoading: true; printErrors: false
               onLoaded: Qt.callLater(() => root.lock(false)) }
    FileView { path: root.requestPath; blockLoading: true; printErrors: false
               onLoaded: { Signals.bootHold = true; Qt.callLater(() => root.lock(true)) } }
    // флаг armed — читаем и СЛЕДИМ: появляется после первого верного пароля → отпечаток снова разрешён
    FileView { id: armedFile; path: "/run/yumi-touchid/armed"; blockLoading: true; watchChanges: true; printErrors: false
               onLoaded: root.fpArmed = true
               onLoadFailed: root.fpArmed = false }
    // бар вернуть: вход растворился (LockSurface.introFinished) или, на всякий случай, через 15 с
    Timer { running: Signals.bootHold; interval: 15000; onTriggered: Signals.bootHold = false }
    // запасная проверка (и удаление запроса)
    Process {
        running: true
        command: ["sh", "-c", 'if [ -e "$1" ]; then echo restore; elif [ -e "$2" ]; then rm -f "$2"; echo boot; fi', "sh", root.flagPath, root.requestPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim()
                if (s === "restore") root.lock(false)
                else if (s === "boot") root.lock(true)
            }
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"                     // /etc/pam.d/hyprlock: auth include login
        user: Quickshell.env("USER")
        onPamMessage: { if (responseRequired && root.pending.length) { respond(root.pending); root.pending = "" } }
        onCompleted: (result) => {
            root.pending = ""
            if (result === PamResult.Success) { root.pwOk = true; Quickshell.execDetached(["touch", root.runDir + "/yumi-lock-pw-ok"]); root.fpStop(); root.authResult("ok", "") }   // 29.10: отметка «вошли паролем» — тачбар не покажет «не распознан» на прерванной проверке пальца
            else root.authResult("error", "Неверный пароль")
        }
        onError: (err) => { root.pending = ""; root.authResult("error", "Ошибка проверки: " + PamError.toString(err)) }
    }

    // Touch ID: отвечать ему нечего (pam_fprintd сам ждёт касания); вопрос с вводом — не наш сценарий, прервать
    PamContext {
        id: fp
        config: "yumi-fingerprint"             // /etc/pam.d/yumi-fingerprint: только pam_fprintd, без faillock
        user: Quickshell.env("USER")
        onActiveChanged: if (active && root.fpQuickFails < 4) root.fpState = "wait"
        onPamMessage: {
            if (responseRequired) { abort(); return }
            if (messageIsError) { root.fpState = "miss"; fpMissTimer.restart() }
        }
        onCompleted: (result) => {
            if (result === PamResult.Success && root.fpAllowed) { root.fpState = "off"; root.fpOk = true; return }
            // «не распознан» показывает только сообщение-ошибка pam_fprintd (onPamMessage), таймаут — молча
            root.fpRetryAfter()
        }
        // сбой сенсора (SESSION_COMMIT refused и т.п.) и таймаут pam_fprintd приходят сюда, а не в completed
        onError: root.fpRetryAfter()
    }
    // быстрый отказ (<2 с после старта) — сенсор не поднялся: подсказка остаётся, повтор через 1 с; 4 раза подряд —
    // похоже, сенсора нет (крышка закрыта, fprintd не готов): подсказку убрать, повтор раз в 5 с.
    // Промах/таймаут (долгое ожидание) — повтор почти сразу, счётчик сброшен.
    function fpRetryAfter(): void {
        const quick = Date.now() - fpStartedAt < 2000
        fpQuickFails = quick ? fpQuickFails + 1 : 0
        const gone = fpQuickFails >= 4
        if (fpState !== "miss") fpState = gone ? "off" : "wait"
        fpRetry.interval = gone ? 5000 : quick ? 1000 : 300
        fpRetry.restart()
    }
    Timer { id: fpRetry; onTriggered: root.fpStart() }
    Timer { id: fpMissTimer; interval: 1600; onTriggered: if (root.fpState === "miss") root.fpState = fp.active ? "wait" : "off" }

    // позиция и текст песни свежие; when — чтобы не спорить с Binding превью (тот держал false и гасил опрос)
    Binding { target: Player; property: "lockOpen"; value: true; when: sessionLock.locked }

    WlSessionLock {
        id: sessionLock
        locked: false
        // поверхность создаётся на каждый монитор; пароль можно вводить на любом
        WlSessionLockSurface {
            id: lockSurf
            // сплошной чёрный, кроме анимаций появления/растворения — тогда сквозь него виден рабочий стол
            color: surface.solid ? "black" : "transparent"
            LockSurface {
                id: surface
                anchors.fill: parent
                screenName: lockSurf.screen ? lockSurf.screen.name : ""
                // заглушка на втором мониторе, пока встроенный экран есть (крышка закрыта — полный экран блокировки)
                placeholder: Theme.lockPlaceholder(screenName)
                active: sessionLock.locked
                focusDiag: true
                bootIntro: root.bootMode && !root.introDone
                blankCursor: root.bootMode           // 18.10 (cursor6): при загрузке курсора нет до разблокировки
                notifCount: Notifs.count
                notifApps: Notifs.centerApps
                notifCounts: Notifs.centerApps.map(a => ({ app: a, n: Notifs.centerFor(a).length }))
                fpState: root.fpState
                fpOk: root.fpOk
                sharedText: root.typed
                onTyped: (t) => root.typed = t
                onSubmitted: (pw) => { if (pam.active) return; root.pending = pw; root.asking = surface; root.authResult("checking", ""); pam.start() }
                Connections {
                    target: root
                    function onAuthResult(state, err) { if (err) surface.errorText = err; surface.authState = state }
                }
                onCancelled: {}                // Esc на настоящем экране только возвращает к часам
                onDissolved: root.unlock()
                onIntroFinished: Signals.bootHold = false
                onIntroGone: if (!root.introDone) { root.introDone = true; Signals.lazyReady = true; Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yumi-boot-monitors"]) }
            }
        }
    }
}
