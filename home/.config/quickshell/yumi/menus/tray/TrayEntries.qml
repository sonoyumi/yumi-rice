import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.menus.wifi

// Пункты dbusmenu программы (QsMenuOpener над QsMenuHandle): разделители, флажки/переключатели, подменю
// раскрываются каскадом под строкой (Reveal + вложенный TrayEntries). Подписи и значки — как в yumi-menu-tray.
// Клавиатура (16.10, аккордеон трея): key(k) — "up"/"down"/"left"/"right"/"enter"/"esc", true — нажатие обработано;
// false — уйти уровнем выше (↑ с первого пункта, ↓ с последнего, ←). → на подменю раскрывает его и заходит внутрь.
// «Остров» (29.10): фокус — подложка акцентом 16 % и кромка (kbOn — у этого уровня сейчас клавиатура).
ColumnLayout {
    id: root
    property var handle: null                 // QsMenuHandle (SystemTrayItem.menu или QsMenuEntry подменю)
    property int depth: 0
    property bool dry: false
    property bool open: true                  // для каскада появления
    property bool kbOn: false                 // клавиатура на этом уровне (родитель передаёт)
    property int focusIdx: -1                 // номер пункта с фокусом (в opener.children)
    property bool subActive: false            // клавиатура внутри раскрытого подменю пункта focusIdx
    signal picked(string label)               // пункт нажат (triggered уже отправлен)
    readonly property int count: opener.children ? opener.children.values.length : 0
    readonly property bool hasShow: {         // у программы свой «Открыть/Показать» — без дубля
        const vals = opener.children ? opener.children.values : []
        for (const e of vals) if (!e.isSeparator && /показ|открыть|відкри|развернуть|розгорн|show|open|restore|window/i.test(clean(e.text))) return true
        return false
    }
    property string openedSub: ""             // текст раскрытого подменю
    spacing: 2

    readonly property var glyphs: [
        [/выход|выйти|вийти|вихід|закрыть|закрити|quit|exit|close/i, "󰗼"],
        [/настро|налашт|параметр|предпочт|settings|preferences|options|configure/i, "󰒓"],
        [/показ|открыть|відкри|развернуть|розгорн|show|open|restore|window/i, "󰖯"],
        [/скрыть|сховати|свернуть|згорн|hide|minimi/i, "󰖰"],
        [/звук|уведомл|сповіщ|mute|notif|sound/i, "󰂚"],
        [/обнов|update|check/i, "󰚰"],
        [/о программе|about|справк|help/i, "󰋽"],
        [/перезапуск|restart|reload/i, "󰑓"],
        [/пауза|pause|resume|продолж/i, "󰏤"],
        [/монтир|mount|eject|извлечь|unmount/i, "󰋊"],
        [/аккаунт|account|профил|profile/i, "󰀄"],
        [/новый|new|создать|compose/i, "󰐕"] ]
    readonly property var danger: /выход|выйти|вийти|вихід|закрыть|закрити|quit|exit/i
    function clean(label) { return (label || "").replace(/_(?!_)/g, "").replace(/__/g, "_").replace(/&&/g, "&").trim() }
    function glyphFor(label) { for (const g of glyphs) if (g[0].test(label)) return g[1]; return "󰄾" }

    // ---- клавиатура ----
    function rowAt(i) { return i >= 0 ? rep.itemAt(i) : null }
    function nav(i) { const r = rowAt(i); return !!r && r.visible && !r.sep && r.modelData.enabled }
    function next(from, d) { for (let i = from + d; i >= 0 && i < rep.count; i += d) if (nav(i)) return i; return -1 }
    function focusFirst() { subActive = false; focusIdx = next(-1, 1); return focusIdx >= 0 }
    function subOf(i) { const r = rowAt(i); return r && r.subOpen ? r.subItem : null }
    function activateRow(r) {
        if (!r) return
        if (r.sub) { openedSub = r.subOpen ? "" : r.label; return }
        if (dry) console.log("[dry-run] dbusmenu triggered «" + r.label + "»"); else r.modelData.triggered()
        picked(r.label)
    }
    function key(k) {
        if (subActive) {
            const s = subOf(focusIdx)
            if (s && s.key(k)) return true
            if (k === "up" || k === "left" || k === "esc") { subActive = false; if (k !== "up") openedSub = ""; return true }
            if (k === "down") { subActive = false; const n = next(focusIdx, 1); if (n < 0) return false; focusIdx = n; return true }
            return true
        }
        if (k === "down") {
            const s = subOf(focusIdx)
            if (s && s.focusFirst()) { subActive = true; return true }
            const n = next(focusIdx, 1); if (n < 0) return false; focusIdx = n; return true
        }
        if (k === "up") { const n = next(focusIdx, -1); if (n < 0) return false; focusIdx = n; return true }
        if (k === "right") {
            const r = rowAt(focusIdx)
            if (r && r.sub) {
                openedSub = r.label
                Qt.callLater(() => { const s = subOf(root.focusIdx); if (s && s.focusFirst()) root.subActive = true })
            }
            return true
        }
        if (k === "enter") { activateRow(rowAt(focusIdx)); return true }
        return false                          // ← и Esc — уровнем выше
    }

    QsMenuOpener { id: opener; menu: root.handle }

    Repeater {
        id: rep
        model: opener.children
        delegate: ColumnLayout {
            id: row
            required property var modelData
            required property int index
            readonly property string label: root.clean(modelData.text)
            readonly property bool sep: modelData.isSeparator
            readonly property bool sub: modelData.hasChildren
            readonly property bool checked: modelData.checkState === Qt.Checked
            readonly property bool toggle: modelData.buttonType !== QsMenuButtonType.None
            readonly property bool subOpen: root.openedSub === label && sub
            readonly property bool kb: root.kbOn && !root.subActive && root.focusIdx === index
            readonly property var subItem: ldr.item
            Layout.fillWidth: true
            spacing: 0
            visible: sep ? (index > 0 && index < root.count - 1) : label.length > 0
            opacity: root.open ? 1 : 0
            Behavior on opacity { SequentialAnimation { PauseAnimation { duration: root.open ? 60 + Math.min(index, 12) * Theme.cascade : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }

            Item { visible: row.sep; Layout.fillWidth: true; implicitHeight: 8 }   // «Остров»: разделитель — отступ, без черты
            Rectangle {
                visible: !row.sep
                Layout.fillWidth: true
                implicitHeight: 36; radius: 12              // «Остров» (29.10): пункт — строка radius 12, наведение isl2, фокус — кромка акцентом
                color: row.kb ? Colors.alpha(Colors.acc, 0.16)
                     : (ma.containsMouse && modelData.enabled) || row.subOpen ? Colors.isl2 : "transparent"
                border.width: row.kb ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                opacity: modelData.enabled ? 1 : 0.45
                scale: ma.pressed && modelData.enabled ? 0.98 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10 + root.depth * 14; anchors.rightMargin: 10; spacing: 8
                    Glyph {   // флажок/переключатель — значком (это состояние, не украшение)
                        visible: row.toggle || row.checked
                        text: row.checked ? "󰄬" : (modelData.buttonType === QsMenuButtonType.RadioButton ? "󰄰" : "󰄱")
                        font.pixelSize: 13; Layout.minimumWidth: 16; horizontalAlignment: Text.AlignHCenter
                        color: row.checked ? Colors.acc : Colors.fgDim
                    }
                    Text { Layout.fillWidth: true; text: row.label; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13
                           color: root.danger.test(row.label) ? Colors.bad : Colors.fg }
                    Glyph { visible: row.sub; text: "󰅂"; font.pixelSize: 15; color: Colors.fgDim
                            rotation: row.subOpen ? 90 : 0
                            Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack } } }
                    Text { visible: row.kb && !row.sub; text: "↵"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true; enabled: modelData.enabled; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.focusIdx = row.index; root.subActive = false; root.activateRow(row) }
                }
            }
            Reveal {
                shown: row.subOpen
                spacing: 0
                Loader {
                    id: ldr
                    Layout.fillWidth: true
                    active: row.sub && (row.subOpen || item !== null)
                    source: "TrayEntries.qml"
                    onLoaded: { item.handle = row.modelData; item.depth = root.depth + 1; item.dry = root.dry; item.open = Qt.binding(() => row.subOpen)
                                item.kbOn = Qt.binding(() => root.kbOn && root.subActive && root.focusIdx === row.index)
                                item.picked.connect(root.picked) }
                }
            }
        }
    }
}
