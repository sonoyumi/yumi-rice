.pragma library
// Поиск пикера — как expand_query()/score() в ~/.local/bin/yumi-menu-picker.
// Русские слова → английские ключи баз (базы HyDE только на английском). Ищется и по началу слова.
var RU = {
    "улыбка": "smile", "смех": "laugh joy", "лицо": "face", "грусть": "sad", "грустный": "sad",
    "плач": "cry", "слёзы": "tear cry", "слезы": "tear cry", "злой": "angry", "злость": "angry",
    "сердце": "heart", "любовь": "love heart", "поцелуй": "kiss", "огонь": "fire", "звезда": "star",
    "солнце": "sun", "луна": "moon", "облако": "cloud", "дождь": "rain", "снег": "snow", "погода": "weather",
    "молния": "lightning zap", "кот": "cat", "кошка": "cat", "собака": "dog", "пёс": "dog", "мышь": "mouse",
    "птица": "bird", "рыба": "fish", "цветок": "flower", "дерево": "tree", "лист": "leaf",
    "еда": "food", "кофе": "coffee", "чай": "tea", "пицца": "pizza", "торт": "cake", "фрукт": "fruit",
    "яблоко": "apple", "пиво": "beer", "вино": "wine", "рука": "hand", "палец": "finger", "класс": "thumbs up",
    "ок": "ok", "хлопать": "clap", "праздник": "party celebration", "подарок": "gift", "деньги": "money",
    "машина": "car", "дом": "home house", "музыка": "music", "нота": "note music", "игра": "game",
    "спорт": "sport ball", "мяч": "ball", "флаг": "flag", "часы": "clock", "время": "clock time",
    "телефон": "phone", "компьютер": "computer laptop", "ноутбук": "laptop", "клавиатура": "keyboard",
    "папка": "folder", "файл": "file", "документ": "document file", "стрелка": "arrow", "вверх": "up",
    "вниз": "down", "влево": "left", "вправо": "right", "назад": "back", "вперёд": "forward",
    "поиск": "search magnify", "лупа": "magnify search", "настройки": "settings cog gear", "шестерёнка": "cog gear",
    "замок": "lock", "ключ": "key", "пользователь": "account user", "человек": "person account",
    "почта": "mail email", "письмо": "mail letter", "календарь": "calendar", "звонок": "bell",
    "уведомление": "bell notification", "звук": "volume sound", "громкость": "volume", "микрофон": "microphone",
    "камера": "camera", "фото": "camera image", "картинка": "image", "видео": "video", "плей": "play",
    "пауза": "pause", "стоп": "stop", "батарея": "battery", "заряд": "battery charging", "сеть": "network",
    "вайфай": "wifi", "блютуз": "bluetooth", "питание": "power", "выключить": "power", "корзина": "trash delete",
    "удалить": "delete trash", "плюс": "plus add", "минус": "minus", "галочка": "check", "крестик": "close",
    "предупреждение": "alert warning", "ошибка": "alert error", "инфо": "information", "вопрос": "question help",
    "код": "code", "терминал": "terminal console", "гит": "git", "ветка": "branch", "линукс": "linux",
    "арч": "arch", "питон": "python", "облачко": "cloud", "глаз": "eye", "книга": "book", "ручка": "pen pencil",
    "карандаш": "pencil", "ножницы": "scissors", "копировать": "copy", "буфер": "clipboard", "закладка": "bookmark",
    "дом.": "home", "карта": "map", "место": "map marker", "земля": "earth globe", "мир": "earth globe",
    "ракета": "rocket", "самолёт": "airplane", "поезд": "train", "велосипед": "bike bicycle",
    "привет": "wave hand", "сон": "sleep", "спать": "sleep", "череп": "skull", "призрак": "ghost",
    "робот": "robot", "инопланетянин": "alien", "обезьяна": "monkey", "медведь": "bear", "лиса": "fox",
    "единорог": "unicorn", "дракон": "dragon", "змея": "snake", "паук": "spider", "бабочка": "butterfly"
}

// слова запроса → для каждого слова набор вариантов (русские — с переводом)
function expand(q) {
    var groups = []
    var words = q.toLowerCase().split(/\s+/).filter(function (w) { return w.length > 0 })
    for (var i = 0; i < words.length; i++) {
        var w = words[i], alts = [w]
        if (/[а-яё]/.test(w)) {
            for (var ru in RU) {
                if (ru.indexOf(w) === 0 || (w.length >= 4 && w.indexOf(ru.slice(0, Math.max(ru.length - 2, 3))) === 0))
                    alts = alts.concat(RU[ru].split(" "))
            }
        }
        groups.push(alts)
    }
    return groups
}

// it = [символ, название, подпись, строка поиска]; 0 — не подходит; больше — выше в выдаче
function score(it, groups) {
    var hay = it[3], name = it[1].toLowerCase(), total = 0
    var sh = " " + hay + " ", sh1 = " " + hay, sn = " " + name, words = name.split(" ")
    for (var g = 0; g < groups.length; g++) {
        var best = 0, alts = groups[g]
        for (var i = 0; i < alts.length; i++) {
            var a = alts[i]
            if (a === it[0] || a === name) best = Math.max(best, 100)
            else if (name.indexOf(a) >= 0) best = Math.max(best, words.indexOf(a) >= 0 ? 8 : (sn.indexOf(" " + a) >= 0 ? 6 : 4))
            else if (sh.indexOf(" " + a + " ") >= 0) best = Math.max(best, 3)
            else if (sh1.indexOf(" " + a) >= 0) best = Math.max(best, 2)
            else if (hay.indexOf(a) >= 0) best = Math.max(best, 1)
        }
        if (!best) return 0
        total += best
    }
    return total
}

// индексы подходящих: по убыванию очков, при равенстве — короче описание, потом порядок базы
function filter(items, q) {
    var groups = expand(q), scored = []
    for (var i = 0; i < items.length; i++) { var s = score(items[i], groups); if (s) scored.push([s, i]) }
    scored.sort(function (x, y) { return (y[0] - x[0]) || (items[x[1]][3].length - items[y[1]][3].length) || (x[1] - y[1]) })
    return scored.map(function (x) { return x[1] })
}
