.pragma library
// Простая подсветка строки кода для «Быстрого просмотра»: комментарии, строки, числа, ключевые слова. Строка → StyledText.
// Без состояния между строками (многострочные комментарии/строки не отслеживаются — это «просмотр», не редактор).

const KW = {
    python: "and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield self",
    js: "async await break case catch class const continue default delete do else export extends false finally for function if import in instanceof let new null of return static super switch this throw true try typeof undefined var void while yield property readonly signal required component alias pragma library",
    shell: "if then else elif fi for while until do done case esac in function return local export readonly set unset source exit echo printf cd true false",
    lua: "and break do else elseif end false for function goto if in local nil not or repeat return then true until while",
    c: "auto break case char const continue default do double else enum extern float for goto if inline int long register return short signed sizeof static struct switch typedef union unsigned void volatile while bool true false nullptr class public private protected template typename namespace using new delete fn let mut impl pub use mod match struct enum trait func package import go defer chan var type interface map range",
    sql: "select from where and or not insert into values update set delete create table drop alter index join left right inner outer on group by order having limit as distinct null is like in",
    css: "", conf: "true false yes no on off", json: "true false null", xml: "", md: "", diff: ""
}
const sets = {}
for (const k in KW) sets[k] = new Set(KW[k].split(" ").filter(x => x))

function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;") }
function span(c, s) { return `<font color="${c}">${esc(s)}</font>` }

// pal: { kw, str, num, com, fn, dim }
function line(text, lang, pal) {
    if (!text) return "&nbsp;"
    if (!lang) return esc(text)
    if (lang === "diff") {
        const c = text[0] === "+" ? pal.str : text[0] === "-" ? pal.kw : text.startsWith("@@") ? pal.num : null
        return c ? span(c, text) : esc(text)
    }
    if (lang === "md") {
        if (/^\s*#/.test(text)) return `<b>${span(pal.kw, text)}</b>`
        if (/^\s*(```|    )/.test(text)) return span(pal.str, text)
        return esc(text)
    }
    if (lang === "conf") {
        if (/^\s*[#;]/.test(text)) return span(pal.com, text)
        if (/^\s*\[.*\]\s*$/.test(text)) return span(pal.kw, text)
        const m = text.match(/^(\s*[\w.\-"']+\s*)([=:])(.*)$/)
        if (m) return span(pal.fn, m[1]) + esc(m[2]) + span(pal.str, m[3])
        return esc(text)
    }
    const com = (lang === "python" || lang === "shell" || lang === "conf") ? "#" : lang === "lua" || lang === "sql" ? "--" : "//"
    const kw = sets[lang] || new Set()
    const re = /("(?:\\.|[^"\\])*"?|'(?:\\.|[^'\\])*'?|`(?:\\.|[^`\\])*`?)|(\b\d[\d_.xXa-fA-F]*\b)|([A-Za-z_$][\w$]*)|(\s+)|(.)/g
    let out = "", m
    while ((m = re.exec(text)) !== null) {
        const rest = text.slice(m.index)
        if (!m[1] && (rest.startsWith(com) || (lang === "c" || lang === "js" || lang === "css") && rest.startsWith("/*"))) {
            out += span(pal.com, rest); break
        }
        if (lang === "xml" && m[5] === "<") {
            const t = rest.match(/^<\/?[\w:.\-]+/)
            if (t) { out += span(pal.kw, t[0]); re.lastIndex = m.index + t[0].length; continue }
        }
        if (m[1]) out += span(pal.str, m[1])
        else if (m[2]) out += span(pal.num, m[2])
        else if (m[3]) {
            if (kw.has(m[3])) out += span(pal.kw, m[3])
            else if (text[re.lastIndex] === "(") out += span(pal.fn, m[3])
            else out += esc(m[3])
        }
        else out += esc(m[0])
    }
    return out
}
