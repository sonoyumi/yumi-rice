import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.bar.modules
import qs.services
import qs.island

// Бар «Остров» (29.10): по экземпляру на монитор, отдельные острова-капсулы 30 px сверху на 6 px (как .bar в превью):
// расположение и порядок — как в баре до «Острова» (по пилюле на модуль, батарея+профиль+режим — одна), меняется только вид;
// по центру — место центрального острова (island/: плеер, уведомления, OSD) в общем потоке, без наложений.
// Внутри острова — кнопки K (24 px). Меню открываются из своей кнопки: Menus.toggleFrom(имя, кнопка).
// Неэксклюзивный, лежит в полосе reserved=38 Hyprland. Окно выше полосы на тень островов, ввод — только полоса (mask).
// YUMI_QS_DEV=1 — на 38 px ниже (под работающим Waybar), =2 — ещё ниже (свой экземпляр агента «бар», dev-bar.qml).
Variants {
    property var screens: Quickshell.screens          // dev-bar.qml ограничивает одним экраном
    model: screens
    delegate: PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property string home: Quickshell.env("HOME")
        readonly property string bin: home + "/.local/bin/"
        readonly property string lib: home + "/.local/lib/yumi/bar/"
        readonly property int gap: 5                               // промежуток между островами (было 6 — место для подписей)
        readonly property var pw: Pipewire.defaultAudioSink

        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.barH + 22                            // + место под тень островов
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.devLevel * Theme.barH
        mask: Region { item: strip }
        Item { id: strip; width: parent.width; height: Theme.barH }

        // Скрытие (qs -c yumi ipc call bar toggle): содержимое уезжает вверх и гаснет, потом окно прячется
        // (Hyprland добавляет fade по правилу yumi_qs_fade); показ — окно сразу, содержимое съезжает вниз.
        visible: (Signals.barVisible || hideWait.running) && !Signals.bootHold
        Timer { id: hideWait; interval: Theme.normal + 40 }
        Connections { target: Signals; function onBarVisibleChanged() { if (!Signals.barVisible) { hideWait.restart(); Tips.hide(null) } } }

        Tooltip { bar: win }

        // ---- скрипты пилюль (те же, что у Waybar) ----
        BarScript { id: sTop;      command: [win.lib + "pillfmt", "mem"];   interval: 20;  name: "top" }
        BarScript { id: sUpdates;  command: [win.lib + "updates-split"];        interval: 86400; name: "updates" }   // внутри зовёт yumi-update check (обновлятор не тронут) + разбивка по источникам
        BarScript { id: sBackup;   command: [win.lib + "backup"];               interval: 1800;  name: "backup" }
        BarScript { id: sLang;     command: [win.lib + "lang"];             interval: 0;   name: "lang" }
        BarScript { id: sVpn;      command: [win.lib + "vpn"];              interval: 60;  name: "vpn" }
        BarScript { id: sCaff;     command: [win.lib + "caffeine"];         interval: 120; name: "caffeine" }
        BarScript { id: sWifi;     command: [win.lib + "wifi"];             interval: 60;  name: "wifi" }
        BarScript { id: sBt;       command: [win.lib + "bt"];               interval: 60;  name: "bt" }
        BarScript { id: sPods;     command: [win.lib + "airpods"];          interval: 0;   name: "airpods" }   // заряд из службы yumi-airpods
        BarScript { id: sPpd;      command: [win.lib + "ppd"];              interval: 120; name: "ppd" }
        BarScript { id: sWf;       command: [win.lib + "workflow"];         interval: 120; name: "workflow" }
        // плеер (название, обложка, эквалайзер) — в острове по центру (island/Island.qml), скрипт обложки — там же

        Item {
            id: content
            width: parent.width; height: Theme.barH
            y: Signals.barVisible ? 0 : -Theme.barH
            opacity: Signals.barVisible ? 1 : 0
            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }

            // 19.10: обои поставлены из виджета (Signals.desktopPop) — бар съезжает сверху пружинкой, вместе с окнами.
            transform: Translate { id: popT }
            Connections {
                target: Signals
                function onDesktopPop(name) {
                    if (name !== win.screen.name) return
                    popAnim.stop(); popT.y = -Theme.barH; barInner.opacity = 0; popAnim.start()
                }
                // 30.10: выбор обоев на этом экране — бар уезжает вверх; вернулся (уже в новых цветах) — пружинкой
                function onWallHideChanged() {
                    const hid = Signals.wallHide === win.screen.name
                    if (hid) { popAnim.stop(); awayAnim.restart() }
                    else if (popT.y < 0 || barInner.opacity < 1) { awayAnim.stop(); popAnim.restart() }
                }
            }
            ParallelAnimation {
                id: awayAnim
                NumberAnimation { target: popT; property: "y"; to: -Theme.barH; duration: 260; easing.type: Easing.InCubic }
                NumberAnimation { target: barInner; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
            }
            ParallelAnimation {
                id: popAnim
                NumberAnimation { target: popT; property: "y"; to: 0; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
                NumberAnimation { target: barInner; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }

            Item {
                id: barInner
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8

                // ---- бар «Два крыла по смыслу» (29.10, вариант E): левое — работа, правое — связь и состояние;
                //      центральный остров — строго по середине экрана (island/), крылья его не сдвигают ----
                readonly property bool wide: win.width >= 1920           // имя Wi-Fi и подпись режима — только на широком экране
                // крылья → IslandState: остров в покое не шире 2·(середина − дальнее крыло) − 16
                readonly property real lo: leftRow.x + leftRow.width
                readonly property real hi: rightRow.x
                onLoChanged: Qt.callLater(publish)
                onHiChanged: Qt.callLater(publish)
                Component.onCompleted: Qt.callLater(publish)
                function publish() { IslandState.setSlot(win.screen.name, 8 + lo, 8 + hi) }
                // проверка ширины: YUMI_BAR_LOG=1 — в журнал ширины крыльев, место острова и прикидка для экрана 1920
                // (на 1920 справа добавятся имя Wi-Fi и подпись режима)
                Text { id: wfProbe; visible: false; text: sWf.raw.replace(/^\S+\s*/, ""); font.family: Theme.fontUi; font.pixelSize: Theme.barFont }
                Timer { running: Quickshell.env("YUMI_BAR_LOG") === "1"; interval: 3000
                        onTriggered: {
                            const L = leftRow.width, R = rightRow.width
                            const R19 = barInner.wide ? R : R + wifiName.implicitWidth + 6 + wfProbe.implicitWidth + 4
                            console.log("БАР", win.width, "лево", Math.round(L), "право", Math.round(R), "место острова", Math.round(IslandState.room(win.screen.name, win.width)),
                                        "| 1920: право ≈", Math.round(R19), "место ≈", Math.round(2 * Math.min(960 - 8 - L, 1920 - 8 - R19 - 960) - 16))
                        } }

                // ЛЕВОЕ КРЫЛО: [печать + столы (занятые и текущий)] [ЦП/ОЗУ] [обновления · бэкап · трей]
                RowLayout {
                    id: leftRow
                    anchors.left: parent.left; y: 6
                    spacing: win.gap
                    Is { K { menu: "system"; padX: 5; tip: "Система"                   // 29.10: 18 px и отступы — печать целиком внутри капсулы
                             YumiMark { size: 18; color: Theme.seal; ink: Theme.sealInk } } }   // знак системы — красная печать, как при загрузке (решение пользователя 29.10)
                    // 29.10: столы — отдельным островом (с печатью сливались в одно пятно)
                    Is { Workspaces { screenName: win.screen.name; occOnly: true; Layout.alignment: Qt.AlignVCenter } }
                    Is { K { menu: "top"; ipcX: "top"                                    // меню «Процессы» под кнопкой
                             Cpu {}
                             Mod { script: sTop; minW: 40; tone: has("heavy") ? Colors.warn : Colors.fg } }
                    }
                    Is {
                        K { visible: sUpdates.ok && sUpdates.raw.length > 0; menu: "updates"   // одно число (pacman + AUR + flatpak); подробно — в подсказке и меню
                            Mod { id: updMod
                                  readonly property bool any: (" " + sUpdates.cls + " ").indexOf(" updates ") >= 0
                                  readonly property int total: (sUpdates.raw.match(/\d+/g) || []).reduce((a, n) => a + Number(n), 0)
                                  tip: sUpdates.tooltip; icon: "󰚰"; tone: any ? Colors.acc : Colors.fg; glow: any
                                  Text { visible: updMod.total > 0; text: updMod.total; font.family: Theme.fontUi; font.pixelSize: Theme.barFont
                                         font.features: ({ "tnum": 1 }); color: updMod.ink } } }
                        K { id: kBackup; menu: "backup"                                               // бэкап (borg): клик — компактное меню бэкапа (menus/backup, «Сделать бэкап» внутри)
                             readonly property bool running: (" " + sBackup.cls + " ").indexOf(" running ") >= 0
                             busy: running; progress: sBackup.percentage >= 0 ? sBackup.percentage / 100 : -1   // идёт бэкап — полоска снизу
                             Mod { script: sBackup; iconOnly: true                   // только значок (возраст — в подсказке)
                                   // 29.10: цвет по возрасту бэкапа — до 1 дня зелёный, к 7 дням плавно красный (через жёлтый/оранжевый), Colors.goodTone
                                   readonly property real ageDays: { try { const a = JSON.parse(sBackup.raw).age; return a === null || a === undefined ? -1 : Number(a) } catch (e) { return -1 } }
                                   tone: has("running") ? Colors.acc : ageDays >= 0 ? Colors.goodTone(1 - Math.max(0, Math.min(1, (ageDays - 1) / 6))) : Colors.fg
                                   dim: has("none") ? 0.55 : 1; glow: has("overdue") || has("running") }
                             Timer { interval: 2000; repeat: true; running: kBackup.running; onTriggered: sBackup.refresh() } }   // пока идёт — опрос каждые 2 с
                        K { visible: tray.count > 0; menu: "tray"; ipcX: "tray"; padX: 6; Tray { id: tray } }   // трей: штатный SystemTray
                    }
                }

                // ПРАВОЕ КРЫЛО: [уведомления · RU/EN · не засыпать] [AirPods] [VPN · Wi-Fi · BT · звук] [часы · батарея · профиль · режим] [питание]
                RowLayout {
                    id: rightRow
                    anchors.right: parent.right; y: 6
                    spacing: win.gap
                    Is { spacing: 1; padX: 2                                            // 30.10: компактнее (буфер обмена убран из бара)
                        K { menu: "control"; padX: 4                                               // колокольчик → центр управления; правый клик — журнал
                             onRightClicked: Notifs.visible = !Notifs.visible
                             Mod { icon: Notifs.dnd ? "󰂛" : (Notifs.count > 0 ? "󰂚" : "󰂜")
                                   tip: Notifs.dnd ? "Не беспокоить" : (Notifs.count > 0 ? "Уведомлений: " + Notifs.count : "Уведомлений нет")
                                   readonly property bool lit2: Notifs.count > 0 && !Notifs.dnd
                                   tone: lit2 ? Colors.acc : Colors.fg
                                   dim: Notifs.dnd ? 0.6 : 1 }
                             Rectangle {   // бейдж: число уведомлений, появляется пружинкой
                                 readonly property bool show: Notifs.count > 0 && !Notifs.dnd
                                 Layout.preferredWidth: show ? Math.max(16, cnt.implicitWidth + 8) : 0
                                 Layout.preferredHeight: 16
                                 visible: show || scale > 0.01        // спрятан — уходит из ряда целиком (колокольчик по центру острова)
                                 radius: 8; color: Colors.acc
                                 scale: show ? 1 : 0
                                 Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                 Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                                 Text { id: cnt; anchors.centerIn: parent; text: Notifs.count > 99 ? "99+" : Notifs.count
                                        font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Normal; font.features: ({ "tnum": 1 })
                                        color: Colors.onAcc } } }
                        K { padX: 4; visible: sLang.ok && sLang.raw.length > 0; cmd: win.bin + "yumi-kb-switch"
                            Mod { script: sLang; noIcons: true } }
                        K { padX: 4; visible: sCaff.ok && sCaff.raw.length > 0; cmd: win.bin + "yumi-cc caffeine toggle"
                            active: (" " + sCaff.cls + " ").indexOf(" activated ") >= 0
                            Mod { script: sCaff; tone: has("activated") ? Colors.acc : Colors.fg } }
                    }
                    // 30.10: AirPods — маленьким островом справа от уведомлений (значок и заряд мельче); нет наушников — острова нет
                    Is { padX: 2; visible: sPods.ok && sPods.cls !== "off" && sPods.cls !== ""
                        K { menu: "airpods"; ipcX: "airpods"; padX: 5; spacing: 3
                            Mod {   // значок YumiIcons + меньший заряд; подсказка — левый/правый/кейс
                                  id: pods
                                  tip: sPods.tooltip
                                  readonly property string c: " " + sPods.cls + " "
                                  tone: c.indexOf(" critical ") >= 0 ? Colors.bad : (c.indexOf(" low ") >= 0 ? Colors.warn
                                        : (c.indexOf(" charging ") >= 0 ? Colors.ok : Colors.acc))
                                  PodsGlyph { color: pods.ink; pixelSize: Theme.barIcon - 2 }
                                  Text { visible: sPods.raw.length > 0; text: sPods.raw; font.family: Theme.fontUi; font.pixelSize: Theme.barFont - 1
                                         font.features: ({ "tnum": 1 }); color: pods.ink
                                         Behavior on color { ColorAnimation { duration: 100 } } } } } }
                    Is {
                        K { visible: sVpn.ok && sVpn.raw.length > 0; menu: "vpn"                 // скрипт пуст, когда VPN выключен
                            Mod { script: sVpn; tone: has("connected") ? Colors.acc : (has("connecting") ? Colors.warn : Colors.fg) } }
                        K { menu: "wifi"
                            Mod { id: wifiMod; script: sWifi
                                  tone: has("weak") ? Colors.warn : Colors.fg; dim: (has("disconnected") || has("off")) ? 0.45 : 1
                                  // куда подключён: имя сети; модем iPhone — «Phone», кабель — «Ethernet»; нет сети — «нет сети».
                                  // Подпись — только на экране ≥ 1920 (иначе значок, имя — в подсказке скрипта)
                                  readonly property string ssid: { const m = sWifi.tooltip.match(/<b>([^<]+)<\/b>/); return m ? m[1] : "" }
                                  Text { id: wifiName; visible: text.length > 0 && barInner.wide; Layout.maximumWidth: 110; elide: Text.ElideRight
                                         text: wifiMod.has("off") ? "" : wifiMod.has("phone") ? "Phone" : wifiMod.has("ethernet") ? "Ethernet" : (wifiMod.ssid && !wifiMod.has("disconnected") ? wifiMod.ssid : "нет сети")
                                         font.family: Theme.fontUi; font.pixelSize: Theme.barFont; font.weight: Font.Medium; color: wifiMod.ink } } }
                        K { menu: "bluetooth"
                            Mod { id: btMod; script: sBt
                                  // 30.10: есть устройства — значок и число ярко (как Wi-Fi); включён без устройств — приглушённо
                                  tone: has("connected") ? Colors.fg : Colors.fgDim; dim: has("off") ? 0.45 : (has("connected") ? 1 : 0.7)
                                  // число подключённых устройств (0 — включён без подключений, выключен — без числа)
                                  readonly property string count: { const m = sBt.tooltip.match(/Подключено:\s*(\d+)/); return m ? m[1] : (has("on") ? "0" : "") }
                                  Text { visible: text.length > 0; text: btMod.count; font.family: Theme.fontUi; font.pixelSize: Theme.barFont
                                         font.features: ({ "tnum": 1 }); color: btMod.lit ? Colors.acc : btMod.has("connected") ? Colors.fg : Colors.fgDim } } }
                        K { menu: "sound"
                            Volume { cmdMid: win.bin + "yumi-volume -o m"; cmdUp: win.bin + "yumi-volume -o i"; cmdDown: win.bin + "yumi-volume -o d" } }
                    }
                    Is {
                        K { menu: "calendar"; Clock {} }
                        K { menu: "power"                                                         // батарея · профиль питания · режим (Main…)
                            Battery {}
                            Mod { script: sPpd; tone: has("power-saver") ? Colors.ok : (has("performance") ? Colors.warn : Colors.fg) }
                            Mod { script: barInner.wide ? sWf : null; visible: sWf.raw.length > 0          // узкий экран — только значок режима
                                  icon: barInner.wide ? "" : (sWf.raw.split(" ")[0] || ""); tip: sWf.tooltip } }
                    }
                    Is { K { id: powerK; menu: "session"; danger: true; tip: "Питание системы"
                             Glyph { text: "⏻"; font.pixelSize: 13; color: powerK.hovered ? Colors.bad : (powerK.on ? Colors.acc : Colors.fg)
                                     Behavior on color { ColorAnimation { duration: Theme.fast } } } } }
                }
            }
        }
    }
}
