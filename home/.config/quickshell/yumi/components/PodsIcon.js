.pragma library
// Значок наушников-вкладышей: простая геометрия (головка, ножка, амбушюра) — два слоя:
// корпус полным цветом и амбушюры полупрозрачные. API: VIEWBOX, ASPECT, svg(корпус, амбушюры, прозрачность).
var VIEWBOX = "0 0 160 105";
var ASPECT = 1.5238;          // ширина / высота
function bud(cx, dir) {       // dir = -1 — левый (амбушюра слева), 1 — правый
    var sx = cx - 8 * dir;
    return '<ellipse cx="' + cx + '" cy="36" rx="25" ry="23"/>'
         + '<rect x="' + (sx - 8) + '" y="44" width="16" height="58" rx="8"/>'
}
function tip(cx, dir) {
    return '<circle cx="' + (cx + 22 * dir) + '" cy="52" r="12"/>'
}
function svg(body, tips, tipAlpha) {
    return "data:image/svg+xml;utf8," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + VIEWBOX + '">'
        + '<g fill="' + tips + '" fill-opacity="' + tipAlpha + '">' + tip(44, -1) + tip(116, 1) + '</g>'
        + '<g fill="' + body + '">' + bud(44, -1) + bud(116, 1) + '</g></svg>')
}
