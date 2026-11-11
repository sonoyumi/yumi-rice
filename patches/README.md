# Patches

🇬🇧 [English](#-english) · 🇮🇹 [Italiano](#-italiano) · 🇺🇦 [Українська](#-українська) · 🇷🇺 [Русский](#-русский)

---

## 🇬🇧 English

Small source patches yumi-rice runs on. None of them is required: the desktop works on stock packages, the patches only remove specific glitches.

| Folder | For | What it fixes |
|---|---|---|
| `hyprland/0001-yumi-boot-hold.patch` | Hyprland 0.56.2 | Holds the first frame until a client surface is ready — no black frame with a cursor between the boot splash and the lock screen. Active only when `HYPRLAND_HOLD_FIRST_CLIENT` is set. |
| `hyprland/0002-yumi-splash-handoff.patch` | Hyprland 0.56.2 | Hooks the hold into the compositor start so the splash hands the screen over without a flash. |
| `hyprland/0003-yumi-lock-keyboard-resend.patch` | Hyprland 0.56.2 | After suspend (s2idle) the lock screen could stay without a keyboard: the seat is re-created but `wl_keyboard.enter` is not sent again. The patch repeats leave/enter for a locked session. |
| `hyprland/PKGBUILD` | Arch `hyprland 0.56.2-4` | The official PKGBUILD plus the three patches; builds `0.56.2-4.3`. |
| `awww/fix-buffer-release.patch` | awww 0.12.1 | The wallpaper daemon crashed (SIGSEGV, black screen) when the compositor released a buffer twice. Buffers are now kept for reuse. |
| Touch Bar | touchbard | Lives in its own repository: [sonoyumi/yumi-touchbar](https://github.com/sonoyumi/yumi-touchbar) (swipe between layers, two-finger swipe, capsule style, Touch ID prompt). |

**Build Hyprland** (takes a while, needs ~4 GB RAM):

```sh
cd patches/hyprland && makepkg -s          # builds hyprland-0.56.2-4.3
sudo pacman -U hyprland-0.56.2-4.3-*.pkg.tar.*
```

Then pin the package (`IgnorePkg = hyprland …` in `/etc/pacman.conf`), otherwise the next update replaces it with the stock build. `yumi-freeze-check` verifies the pins.

**Build awww:** take the `awww` PKGBUILD from the AUR, add `fix-buffer-release.patch` to `source=()` and apply it in `prepare()` with `patch -Np1`.

To go back, reinstall the stock package: `sudo pacman -S hyprland` / `awww`.

---

## 🇮🇹 Italiano

Piccole patch ai sorgenti su cui gira yumi-rice. Nessuna è obbligatoria: il desktop funziona con i pacchetti originali, le patch eliminano solo difetti specifici.

| Cartella | Per | Cosa risolve |
|---|---|---|
| `hyprland/0001-yumi-boot-hold.patch` | Hyprland 0.56.2 | Trattiene il primo fotogramma finché la superficie di un client non è pronta: niente fotogramma nero con il cursore tra lo splash di avvio e la schermata di blocco. Attiva solo se è impostata `HYPRLAND_HOLD_FIRST_CLIENT`. |
| `hyprland/0002-yumi-splash-handoff.patch` | Hyprland 0.56.2 | Collega l'attesa all'avvio del compositor, così lo splash cede lo schermo senza lampi. |
| `hyprland/0003-yumi-lock-keyboard-resend.patch` | Hyprland 0.56.2 | Dopo la sospensione (s2idle) la schermata di blocco poteva restare senza tastiera: il seat viene ricreato ma `wl_keyboard.enter` non viene reinviato. La patch ripete leave/enter per la sessione bloccata. |
| `hyprland/PKGBUILD` | Arch `hyprland 0.56.2-4` | Il PKGBUILD ufficiale più le tre patch; produce `0.56.2-4.3`. |
| `awww/fix-buffer-release.patch` | awww 0.12.1 | Il demone degli sfondi andava in crash (SIGSEGV, schermo nero) quando il compositor rilasciava un buffer due volte. Ora i buffer vengono conservati per il riuso. |
| Touch Bar | touchbard | Sta in un repository a parte: [sonoyumi/yumi-touchbar](https://github.com/sonoyumi/yumi-touchbar) (scorrimento tra i livelli, scorrimento a due dita, stile a capsule, richiesta Touch ID). |

**Compilare Hyprland** (richiede tempo e circa 4 GB di RAM):

```sh
cd patches/hyprland && makepkg -s          # produce hyprland-0.56.2-4.3
sudo pacman -U hyprland-0.56.2-4.3-*.pkg.tar.*
```

Poi blocca il pacchetto (`IgnorePkg = hyprland …` in `/etc/pacman.conf`), altrimenti il prossimo aggiornamento lo sostituisce con quello originale. `yumi-freeze-check` controlla i blocchi.

**Compilare awww:** prendi il PKGBUILD di `awww` dall'AUR, aggiungi `fix-buffer-release.patch` a `source=()` e applicala in `prepare()` con `patch -Np1`.

Per tornare indietro reinstalla il pacchetto originale: `sudo pacman -S hyprland` / `awww`.

---

## 🇺🇦 Українська

Невеликі патчі до вихідного коду, на яких працює yumi-rice. Жоден не обов'язковий: стіл працює на звичайних пакетах, патчі лише прибирають конкретні вади.

| Тека | Для чого | Що виправляє |
|---|---|---|
| `hyprland/0001-yumi-boot-hold.patch` | Hyprland 0.56.2 | Тримає перший кадр, доки не готова поверхня клієнта: немає чорного кадру з курсором між заставкою завантаження та екраном блокування. Працює лише коли задано `HYPRLAND_HOLD_FIRST_CLIENT`. |
| `hyprland/0002-yumi-splash-handoff.patch` | Hyprland 0.56.2 | Підключає утримання до запуску композитора, щоб заставка передала екран без спалаху. |
| `hyprland/0003-yumi-lock-keyboard-resend.patch` | Hyprland 0.56.2 | Після сну (s2idle) екран блокування міг лишитися без клавіатури: seat створюється заново, а `wl_keyboard.enter` повторно не надсилається. Патч повторює leave/enter для заблокованого сеансу. |
| `hyprland/PKGBUILD` | Arch `hyprland 0.56.2-4` | Офіційний PKGBUILD і три патчі; збирає `0.56.2-4.3`. |
| `awww/fix-buffer-release.patch` | awww 0.12.1 | Демон шпалер падав (SIGSEGV, чорний екран), коли композитор звільняв буфер двічі. Тепер буфери зберігаються для повторного використання. |
| Touch Bar | touchbard | В окремому репозиторії: [sonoyumi/yumi-touchbar](https://github.com/sonoyumi/yumi-touchbar) (свайп між шарами, свайп двома пальцями, стиль капсул, вікно Touch ID). |

**Зібрати Hyprland** (довго, потрібно близько 4 ГБ пам'яті):

```sh
cd patches/hyprland && makepkg -s          # збирає hyprland-0.56.2-4.3
sudo pacman -U hyprland-0.56.2-4.3-*.pkg.tar.*
```

Потім закріпи пакет (`IgnorePkg = hyprland …` у `/etc/pacman.conf`), інакше наступне оновлення замінить його звичайним. `yumi-freeze-check` перевіряє закріплення.

**Зібрати awww:** візьми PKGBUILD `awww` з AUR, додай `fix-buffer-release.patch` у `source=()` і застосуй у `prepare()` через `patch -Np1`.

Щоб повернути як було, перевстанови звичайний пакет: `sudo pacman -S hyprland` / `awww`.

---

## 🇷🇺 Русский

Небольшие патчи к исходному коду, на которых работает yumi-rice. Ни один не обязателен: стол работает на обычных пакетах, патчи только убирают конкретные недочёты.

| Папка | Для чего | Что исправляет |
|---|---|---|
| `hyprland/0001-yumi-boot-hold.patch` | Hyprland 0.56.2 | Держит первый кадр, пока не готова поверхность клиента: нет чёрного кадра с курсором между заставкой загрузки и экраном блокировки. Работает, только когда задана `HYPRLAND_HOLD_FIRST_CLIENT`. |
| `hyprland/0002-yumi-splash-handoff.patch` | Hyprland 0.56.2 | Подключает удержание к запуску композитора, чтобы заставка передала экран без вспышки. |
| `hyprland/0003-yumi-lock-keyboard-resend.patch` | Hyprland 0.56.2 | После сна (s2idle) экран блокировки мог остаться без клавиатуры: seat создаётся заново, а `wl_keyboard.enter` повторно не отправляется. Патч повторяет leave/enter для заблокированного сеанса. |
| `hyprland/PKGBUILD` | Arch `hyprland 0.56.2-4` | Официальный PKGBUILD и три патча; собирает `0.56.2-4.3`. |
| `awww/fix-buffer-release.patch` | awww 0.12.1 | Демон обоев падал (SIGSEGV, чёрный экран), когда композитор освобождал буфер дважды. Теперь буферы сохраняются для повторного использования. |
| Touch Bar | touchbard | В отдельном репозитории: [sonoyumi/yumi-touchbar](https://github.com/sonoyumi/yumi-touchbar) (свайп между слоями, свайп двумя пальцами, стиль капсул, окно Touch ID). |

**Собрать Hyprland** (долго, нужно около 4 ГБ памяти):

```sh
cd patches/hyprland && makepkg -s          # собирает hyprland-0.56.2-4.3
sudo pacman -U hyprland-0.56.2-4.3-*.pkg.tar.*
```

Потом закрепи пакет (`IgnorePkg = hyprland …` в `/etc/pacman.conf`), иначе следующее обновление заменит его обычным. `yumi-freeze-check` проверяет закрепления.

**Собрать awww:** возьми PKGBUILD `awww` из AUR, добавь `fix-buffer-release.patch` в `source=()` и примени в `prepare()` через `patch -Np1`.

Чтобы вернуть как было, переустанови обычный пакет: `sudo pacman -S hyprland` / `awww`.
