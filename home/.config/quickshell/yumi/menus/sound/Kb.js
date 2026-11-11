.pragma library
// Клавиатура в меню звука (16.10): ↑↓ (и Tab) переводят фокус по цепочке фокусируемых элементов страницы.
// Элементы с activeFocusOnTab зовут nav() из своего Keys.onPressed; Esc не трогаем — он уходит в SoundMenu (назад).
function nav(item, e) {
    const k = e.key
    let fwd
    if (k === Qt.Key_Down || k === Qt.Key_Tab) fwd = true
    else if (k === Qt.Key_Up || k === Qt.Key_Backtab) fwd = false
    else return false
    const n = item.nextItemInFocusChain(fwd)
    if (n) n.forceActiveFocus()
    e.accepted = true
    return true
}
function activate(e) { return e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space }
