.pragma library
// Pango-разметка скриптов бара (span size/rise/font_family/alpha/foreground, b, sup) → rich text Qt.
// base — размер текста в px, fg — цвет текста (для alpha).
function toQt(s, base, fg) {
    if (!s) return "";
    s = s.replace(/  /g, "&nbsp; ");   // rich text схлопывает пробелы, Pango — нет (двойной пробел перед временем в плеере)
    return s.replace(/<span([^>]*)>/g, function (m, attrs) {
        var st = [];
        var a;
        if ((a = /size='([^']+)'/.exec(attrs))) {
            var v = a[1];
            if (/%$/.test(v)) st.push("font-size:" + Math.round(base * parseFloat(v) / 100) + "px");
            else if (/^\d+$/.test(v)) st.push("font-size:" + Math.round(parseInt(v) / 1024) + "px");
            else if (v === "large" || v === "larger") st.push("font-size:" + Math.round(base * 1.2) + "px");
            else if (v === "small" || v === "smaller") st.push("font-size:" + Math.round(base * 0.85) + "px");
        }
        if ((a = /font_family='([^']+)'/.exec(attrs))) st.push("font-family:'" + a[1] + "'");
        if ((a = /foreground='([^']+)'/.exec(attrs))) st.push("color:" + a[1]);
        else if ((a = /alpha='([^']+)'/.exec(attrs))) {
            var p = parseFloat(a[1]) / 100;
            st.push("color:rgba(" + Math.round(fg.r * 255) + "," + Math.round(fg.g * 255) + "," + Math.round(fg.b * 255) + "," + p + ")");
        }
        if ((a = /weight='([^']+)'/.exec(attrs))) st.push("font-weight:" + a[1]);
        return st.length ? '<span style="' + st.join(";") + '">' : "<span>";
    });
}
// Голый текст без разметки (для ширины/подсказок)
function strip(s) { return (s || "").replace(/<[^>]+>/g, ""); }
// Значки Nerd Font (приватные области Unicode) крупнее текста — как bar/iconwrap (size='130%')
var PUA = /((?:[-]|[\uDB80-\uDBBF][\uDC00-\uDFFF])+)/g;
function icons(s, iconPx, family) {
    if (!s) return "";
    if (s.indexOf("Nerd Font Propo") >= 0) return s;
    return s.replace(PUA, '<span style="font-size:' + iconPx + "px;font-family:'" + family + "'\">$1</span>");
}
