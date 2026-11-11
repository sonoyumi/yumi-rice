import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import "Cal.js" as Cal

// Сегменты «Напомнить» — «Остров» (29.10): ISeg из пяти долей (нет / в момент / 10 мин / 1 час / 1 день).
ISeg {
    id: root
    property string currentKey: "10"
    signal pickedKey(string key)
    model: Cal.REMIND.map(r => r.text)
    current: Cal.REMIND.findIndex(r => r.key === currentKey)
    onPicked: (i) => root.pickedKey(Cal.REMIND[i].key)
}
