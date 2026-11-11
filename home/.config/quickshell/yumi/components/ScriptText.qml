import QtQuick
import qs
import "Pango.js" as Pango

// Текст модуля из BarScript: rich text, значки крупнее (как iconwrap), пустой текст прячет модуль.
Text {
    property BarScript script
    property bool big: false                      // весь текст = значок (archlogo и т.п.)
    property int iconPx: Theme.iconSize           // размер значков (бар: Theme.barIcon)
    property bool noIcons: false                  // «Тушь»: значки шрифта Nerd убрать — вместо них японская подпись (Mod.jp)
    readonly property string raw: script ? script.text : ""
    text: Pango.icons(noIcons ? raw.replace(/[\uE000-\uF8FF]|[\uDB80-\uDBFF][\uDC00-\uDFFF]/g, "").replace(/^\s+/, "") : raw, iconPx, Theme.fontIcon)
    textFormat: Text.RichText
    font.family: Theme.fontUi
    font.pixelSize: Theme.fontSize
    color: Colors.fg
    visible: text.length > 0
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: 100 } }
}
