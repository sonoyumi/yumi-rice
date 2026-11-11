import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs
import qs.components

// Громкость через PipeWire (pulseaudio в Waybar): значок по уровню/устройству, AirPods и разъём 3,5 мм — YumiIcons;
// muted — красный, Bluetooth-выход — акцент; min-length 6. Подсказка: «{desc} // {volume}%»
// 18.10: значок AirPods и тогда, когда звук идёт в них мимо выхода по умолчанию (поток приложения направлен
// в AirPods, напр. звонок Vesktop) — проценты и колёсико по-прежнему у выхода по умолчанию.
Mod {
    id: m
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property int pct: Math.round(vol * 100)
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string sinkName: sink ? sink.name : ""
    readonly property string podsPrefix: "bluez_output.98_1C_A2_DD_1F_EE"
    readonly property var podsNode: Array.from(Pipewire.nodes.values).find(n => n.isSink && !n.isStream && n.name.startsWith(podsPrefix)) || null
    // потоки приложений, подключённые к AirPods: Pipewire.links (PwNodeLinkTracker на выходе bluez групп не отдаёт;
    // состояние связи без отслеживания неизвестно — считаем по самому факту связи). source/target у новой связи
    // заполняются позже и не уведомляют (constant) — пересчёт таймером после любой смены связей/узлов
    property var podsApps: []
    function podsScan() {
        podsApps = Array.from(Pipewire.links.values)
            .filter(l => m.podsNode && l.target === m.podsNode && l.source && l.source.isStream)
            .map(l => l.source.properties["application.name"] || l.source.description || l.source.name)
            .filter((a, i, arr) => a && arr.indexOf(a) === i)
    }
    Timer { id: podsLater; interval: 300; onTriggered: m.podsScan() }
    Connections { target: Pipewire.links; function onValuesChanged() { podsLater.restart() } }
    Connections { target: Pipewire.nodes; function onValuesChanged() { podsLater.restart() } }
    onPodsNodeChanged: podsLater.restart()
    Component.onCompleted: podsLater.restart()
    readonly property bool podsDefault: sinkName.startsWith(podsPrefix)
    readonly property bool podsRouted: !podsDefault && podsApps.length > 0
    readonly property bool airpods: podsDefault || podsRouted
    readonly property bool bt: sinkName.startsWith("bluez_output.") || podsRouted
    readonly property bool jack: sinkName === "alsa_output.platform-sound.HiFi__Headphones__sink"
    PwObjectTracker { objects: [m.sink, m.podsNode] }
    tone: muted ? Colors.bad : (bt ? Colors.acc : Colors.fg)
    minW: 36
    tip: (sink ? (sink.description || sink.name) : "Нет выхода") + " // " + pct + "%"
         + (podsRouted ? "\nВ AirPods: " + podsApps.join(", ") : "")
    // значки BMP-PUA — только escape-ами: редакторы/терминалы их теряют
    PodsGlyph { visible: m.airpods; color: m.ink }
    Glyph { visible: m.jack && !m.airpods; text: String.fromCodePoint(0xF04C3); font.pixelSize: Theme.barIcon; color: m.ink }   // 19.10: 3,5 мм — колонки
    Glyph { visible: !m.airpods && !m.jack; text: m.muted ? "󰝟" : (m.vol < 0.33 ? "\uf026" : (m.vol < 0.66 ? "\uf027" : "\uf028")); font.pixelSize: Theme.barIcon; color: m.ink }
    Text { visible: !m.muted; text: m.pct + "%"; font.family: Theme.fontUi; font.pixelSize: Theme.barFont; font.features: ({ "tnum": 1 })
           color: m.lit ? Colors.acc : (m.tone === Colors.fg ? Colors.fgDim : m.tone)
           Behavior on color { ColorAnimation { duration: 100 } } }
    Glyph { visible: m.muted && (m.airpods || m.jack); text: "󰝟"; font.pixelSize: Theme.barIcon; color: m.ink }
}
