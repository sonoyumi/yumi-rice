import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Карточка уведомления (центр уведомлений; всплывашки с 29.10 — в центральном острове): значок 36 в квадрате radius 12
// (акцент 20 %), заголовок 14 DemiBold, время, текст fgDim, полоса прогресса, кнопки действий, поле быстрого ответа.
// «Остров» (29.10): плитка isl2 radius 18, крестик при наведении, закрытие — уезжает вправо. Свайп вправо закрывает (swipeable).
// Клик по карточке — действие «default» (или запуск приложения для истёкшей копии).
Item {
    id: root
    property QtObject entry
    property bool inCenter: false          // в центре: непрозрачнее, без кромки, radius Theme.radius
    property bool swipeable: true
    // центр уведомлений с клавиатуры (16.10): выбрана стрелками / раскрыта целиком / выбранная кнопка действия (-1 — нет)
    property bool selected: false
    property bool full: false
    property int actSel: -1
    property bool hiddenMark: false        // запись скрыта (фильтр «Скрытые»)
    readonly property bool critical: entry ? entry.urgency === 2 : false
    readonly property bool low: entry ? entry.urgency === 0 : false
    readonly property bool hovered: mouse.containsMouse || closeBtn.hovered
    // «Остров»: одинаково в центре и где угодно — плитка isl2 с отступом 14; выбранная стрелками — кромка акцентом
    readonly property int pad: 14
    readonly property bool hasPic: !!(entry && entry.image && entry.image.length > 0)
    signal dismissed()

    implicitHeight: Math.ceil(body.implicitHeight) + pad * 2    // целые высоты — текст на целых пикселях (без размытия)
    clip: false

    Rectangle {
        id: card
        width: root.width; height: root.height
        radius: Theme.radiusTile                                    // «Остров»: плитка 18
        color: root.hovered ? Colors.hover : Colors.isl2
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        border.width: root.critical ? 1.5 : 0
        border.color: Colors.bad
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
        // critical: лёгкая красная подложка
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Colors.alpha(Colors.bad, 0.08); visible: root.critical }

        // выбор с клавиатуры — тихо: заливка акцентом 0.12, рамка 1px 0.5 (правило subtle-glow)
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Colors.alpha(Colors.acc, 0.12)
            border.width: 1.5; border.color: Colors.acc        // выбранная стрелками — кромка акцентом
            opacity: root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        }

        // свайп вправо
        Behavior on x { enabled: !mouse.drag.active; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        opacity: 1 - Math.min(1, Math.max(0, x) / (width * 0.8))

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            drag.target: root.swipeable ? card : undefined
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.threshold: 8
            property bool dragged: false
            onPressed: dragged = false
            onPositionChanged: if (drag.active) dragged = true
            onReleased: {
                if (card.x > card.width * 0.3) { card.x = card.width * 1.2; swipeOut.start() }
                else card.x = 0
            }
            onClicked: if (!dragged && root.entry) Notifs.activate(root.entry)
            Timer { id: swipeOut; interval: Theme.normal; onTriggered: { root.dismissed(); if (root.entry) Notifs.dismiss(root.entry) } }
        }

        RowLayout {
            id: body
            x: root.pad; y: root.pad
            width: parent.width - root.pad * 2
            spacing: 12

            // ---- значок / картинка: квадрат 36 radius 12, подложка акцентом 20 % (красным у критичных) ----
            Item {
                Layout.preferredWidth: 36; Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignTop
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 12
                    color: big.status === Image.Ready && root.hasPic ? "transparent" : Colors.alpha(root.critical ? Colors.bad : Colors.acc, 0.20)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Image {
                        id: big
                        anchors.fill: parent
                        anchors.margins: root.hasPic ? 0 : 7
                        source: root.entry ? Notifs.iconFor(root.entry, true) : ""
                        sourceSize.width: Math.ceil(44 * Screen.devicePixelRatio); sourceSize.height: Math.ceil(44 * Screen.devicePixelRatio); smooth: true   // ровно в точках экрана
                        fillMode: root.hasPic ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        onStatusChanged: {
                            // image-data → png в кэш журнала (как yumi-notify-log)
                            if (status === Image.Ready && root.entry && root.entry.image.startsWith("image://") && !root.entry.imageFile) {
                                const e = root.entry
                                big.grabToImage(r => { const p = Notifs.imageName(e); if (r.saveToFile(p)) Notifs.setImageFile(e, p) }, Qt.size(96, 96))
                            }
                        }
                    }
                    Glyph { anchors.centerIn: parent; text: root.critical ? "󰀦" : "󰂚"; color: root.critical ? Colors.bad : Colors.acc
                            font.pixelSize: 18; visible: big.status !== Image.Ready && big.status !== Image.Loading }
                }
                // маленький значок приложения поверх картинки (как app-icon у swaync)
                ClippingRectangle {
                    visible: small.status === Image.Ready && root.entry && root.entry.image.length > 0
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: -4; anchors.bottomMargin: -4
                    width: 18; height: 18; radius: 6
                    color: Colors.isl
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                    Image { id: small; anchors.fill: parent; anchors.margins: 2
                            source: root.entry && root.entry.image.length > 0 ? Notifs.iconFor(root.entry, false) : ""
                            sourceSize.width: Math.ceil(16 * Screen.devicePixelRatio); sourceSize.height: Math.ceil(16 * Screen.devicePixelRatio); smooth: true; fillMode: Image.PreserveAspectFit; asynchronous: true }
                }
            }

            // ---- текст ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: root.entry ? (root.entry.summary.length ? root.entry.summary : root.entry.app) : ""
                        font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
                        color: root.critical ? Colors.bad : Colors.fg
                        elide: Text.ElideRight; maximumLineCount: root.full ? 12 : 2; wrapMode: Text.Wrap
                        Layout.alignment: Qt.AlignTop; Layout.preferredHeight: Math.ceil(implicitHeight)
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                    Text {
                        text: root.entry ? (root.hiddenMark ? "󰘓 " : "") + (root.full ? Qt.formatDateTime(new Date(root.entry.time), "dd.MM HH:mm") : Notifs.ago(root.entry.time)) : ""
                        font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 })
                        color: Colors.fgDim
                        Layout.alignment: Qt.AlignTop; Layout.topMargin: 2; Layout.preferredHeight: Math.ceil(implicitHeight)
                        Layout.rightMargin: 22; Layout.minimumWidth: 40; horizontalAlignment: Text.AlignRight
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.entry ? root.entry.body : ""
                    textFormat: Text.StyledText
                    font.family: Theme.fontUi; font.pixelSize: 12
                    color: Colors.fgDim
                    linkColor: Colors.acc
                    wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: root.full ? 400 : 8
                    Layout.preferredHeight: Math.ceil(implicitHeight)
                    onLinkActivated: (l) => Quickshell.execDetached(["xdg-open", l])
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
                // полоса прогресса: hint value (громкость/яркость/загрузка)
                Rectangle {
                    Layout.fillWidth: true; Layout.topMargin: 4
                    visible: root.entry && root.entry.hints && root.entry.hints["value"] !== undefined
                    height: 4; radius: 2
                    color: Colors.alpha(Colors.fg, 0.16)
                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, (visible && root.entry ? Number(root.entry.hints["value"]) : 0) / 100))
                        height: parent.height; radius: 2
                        color: root.critical ? Colors.bad : Colors.acc
                        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
                    }
                }
                // кнопки действий: капсулы, первая — акцентом 22 %
                Flow {
                    Layout.fillWidth: true; Layout.topMargin: 6
                    visible: acts.count > 0
                    spacing: 6
                    Repeater {
                        id: acts
                        model: root.entry ? root.entry.actions.filter(a => a.id !== "default" && a.id !== "inline-reply") : []
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            required property int index
                            implicitHeight: 28; radius: 14
                            implicitWidth: lbl.implicitWidth + 26
                            color: index === 0 ? Colors.alpha(Colors.acc, bm.containsMouse ? 0.32 : 0.22)
                                 : (bm.containsMouse ? Colors.hover : Colors.isl)
                            border.width: root.actSel === index ? 1.5 : 0          // кнопка выбрана ←→
                            border.color: Colors.fg
                            /* выбор — без затухания (29.10) */
                            scale: bm.pressed ? 0.94 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                            Text { id: lbl; anchors.centerIn: parent; text: btn.modelData.text
                                   font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                                   color: index === 0 ? Colors.acc : Colors.fg }
                            MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true
                                        onClicked: if (root.entry) Notifs.invoke(root.entry, btn.modelData.id) }
                        }
                    }
                }
                // быстрый ответ (hint inline-reply, только пока уведомление живо); Loader — TextInput создаётся
                // только когда нужен (иначе Qt ругается на text-input при скрытии окна)
                Loader {
                    Layout.fillWidth: true; Layout.topMargin: 6
                    active: root.entry ? (root.entry.hasInlineReply && root.entry.alive) : false
                    visible: active
                    sourceComponent: RowLayout {
                    spacing: 6
                    HoverHandler { id: replyHover }   // пассивный: не перехватывает наведение у полей ниже
                    // 19.10: всплывашке клавиатура — только пока курсор на карточке/поле или в поле начат ответ
                    Binding { target: Notifs; property: "replyArmed"; value: true
                              when: !root.inCenter && (root.hovered || replyHover.hovered || field.text.length > 0) }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 32; implicitHeight: 32; radius: 16
                        color: Colors.isl
                        border.width: field.activeFocus ? 1.5 : 0; border.color: Colors.acc
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                        TextInput {
                            id: field
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontUi; font.pixelSize: 13
                            color: Colors.fg; selectionColor: Colors.alpha(Colors.acc, 0.5); selectedTextColor: Colors.fg
                            clip: true
                            onAccepted: if (root.entry) Notifs.reply(root.entry, text)
                            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                   visible: !field.text.length && !field.activeFocus
                                   text: root.entry && root.entry.replyPlaceholder.length ? root.entry.replyPlaceholder : "Ответить…"
                                   font: field.font; color: Colors.fgDim }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32; implicitWidth: 32; implicitHeight: 32; radius: 16
                        color: sm.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc
                        Glyph { anchors.centerIn: parent; text: "󰒊"; color: Colors.onAcc; font.pixelSize: 15 }
                        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true
                                    onClicked: if (root.entry) Notifs.reply(root.entry, field.text) }
                    }
                } }
            }
        }

        // крестик-кружок: виден при наведении, красный под курсором; закрытие — карточка уезжает вправо
        Rectangle {
            id: closeBtn
            property bool hovered: cm.containsMouse
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: 10; anchors.rightMargin: 10
            width: 22; height: 22; radius: 11
            color: cm.containsMouse ? Colors.bad : Colors.isl
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Glyph { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 13; color: cm.containsMouse ? Colors.onAcc : Colors.fg }
            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true
                        onClicked: { card.x = card.width * 1.2; swipeOut.start() } }
        }
    }
}
