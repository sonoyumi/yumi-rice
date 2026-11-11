import QtQuick
import Quickshell
import qs

// Значок программы или файла: names — имена значков темы по порядку (берётся первое найденное), path — файл (Icon= с путём).
// sourceSize = размер × плотность экрана: значок рисуется ровно в точках экрана (без мыла на MSI и ступенек на макбуке).
Item {
    id: root
    property var names: []
    property string path: ""
    property int size: 30
    readonly property string src: {
        if (path) return "file://" + path
        for (const n of names) { if (!n) continue; const p = Quickshell.iconPath(n, true); if (p) return p }
        return ""
    }
    implicitWidth: size; implicitHeight: size
    Image {
        anchors.fill: parent
        source: root.src
        sourceSize.width: Math.ceil(root.size * Screen.devicePixelRatio); sourceSize.height: Math.ceil(root.size * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true; asynchronous: true
    }
}
