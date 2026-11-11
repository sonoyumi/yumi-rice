pragma Singleton
import QtQuick
import Quickshell

// Общее состояние OSD. «Остров» (29.10): своего окна у OSD больше нет — osd/Osd.qml считает, что показать, и кладёт
// сюда (post), а показывает центральный остров (island/Island.qml): уровни — полосой 340×48, слова — сообщением 270×30.
// suppressed: центр управления ставит true, пока открыт, чтобы его ползунки не вызывали OSD поверх окна.
Singleton {
    id: root
    property bool suppressed: false
    property string kind: "vol"
    property real level: 0            // 0..1
    property bool hasLevel: true      // есть полоса (vol/player/mic/bri/kbd); нет — короткое сообщение
    property bool off: false          // выключено (звук/микрофон) — полоса и значок тусклые
    property string icon: "󰕾"
    property bool yumiIcon: false
    property bool pods: false         // AirPods — значок PodsGlyph, как в баре
    property string label: ""         // проценты или текст сообщения
    property int seq: 0               // растёт с каждым показом — остров перезапускает таймер
    signal shown()
    function post(o) {
        for (const k in o) root[k] = o[k]
        seq++
        shown()
    }
}
