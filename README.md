# 🍚 yumi-rice

<p>
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-0.56%20Lua-58E1FF?logo=hyprland&logoColor=white">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-QML-a6da95?logo=qt&logoColor=white">
  <img alt="Asahi Linux" src="https://img.shields.io/badge/Asahi-Arch%20Linux%20ARM-1793D1?logo=archlinux&logoColor=white">
  <img alt="ARM64" src="https://img.shields.io/badge/aarch64-16K%20pages-f5a97f">
  <img alt="Version" src="https://img.shields.io/badge/version-3.1-ed8796">
  <img alt="License" src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue">
</p>

**🇬🇧 [English](#en)** · **🇮🇹 [Italiano](#it)** · **🇺🇦 [Українська](#uk)** · **🇷🇺 [Русский](#ru)**

![Desktop](assets/screenshots/v3.1/desktop.jpg)

<p align="center"><b>3.1</b> — the whole shell on Quickshell, the “Ink” style, login screen on greetd, an installer for Arch<br><a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v3.0">3.0</a> — entirely my own base, without HyDE: pult, doctor, wallpaper collections · <a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v2.5">2.5</a> — AirPods, music with lyrics, GTK4 control center · <a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v2.1">2.1</a> — lighter: events instead of polling, monitors in one file · <a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v2.0">2.0</a> — GTK4 menus, accent from the wallpaper, new lock screen · <a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0">1.0</a> — rofi menus, HyDE themes</p>

---

<a name="en"></a>

## 🇬🇧 English

My Hyprland desktop on a MacBook Pro M1 running Asahi Linux. Since 3.1 the whole shell — bar, menus, notifications,
on-screen indicators, lock screen, login screen and the password dialog — is written in QML on
[Quickshell](https://quickshell.org/), in the “Ink” style: serif type, Japanese captions, a red hanko seal. Everything
takes its colors from the current wallpaper. Plus an installer for Arch Linux / Arch Linux ARM and a sync script that
keeps the repository and the system in step, with a backup of every file it touches.

| | |
|---|---|
| Hardware | MacBook Pro 13" M1 (2020), 8 GB RAM, 2560×1600 display, scale 1.666667 · second monitor MSI G27C3F 1920×1080 over USB-C · Logitech PRO keyboard and PRO X 2 mouse |
| OS | Arch Linux ARM ([Asahi](https://asahilinux.org/)), `linux-asahi` kernel, 16K memory pages, btrfs |
| Desktop | Hyprland 0.56 with the Lua config, my own base `~/.config/hypr/yumi` |
| Bar / notifications / menus / OSD | Quickshell (QML) — one service, `yumi-quickshell` |
| Lock / login / password dialog | Quickshell lock screen · greetd with a Quickshell login screen · Quickshell polkit agent |
| Idle / wallpaper | hypridle · awww |
| Terminal / shell / font | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Shell fonts | Noto Serif · Noto Serif CJK JP · JetBrains Mono Nerd Font · Inter |
| Browser | [Zen](https://zen-browser.app/) (optional) |

### What's new in 3.1

> [!NOTE]
> **Tested on a MacBook Pro M1 (Asahi).** The installer is written for any Arch Linux / Arch Linux ARM machine, but it
> has not been tried on other hardware yet — that is the next thing to check. If something breaks, please open an issue.

**The “Island” look**
- Solid capsules in the wallpaper colors across the bar, every menu, the lock screen and the Touch Bar; the 弓 seal
  as the mark of the system.
- **Dynamic Island** in the middle of the bar: the current track, timers and Pomodoro, downloads, microphone in use,
  network and VPN changes, AirPods — one place for everything that is happening right now (`yumi-island`).
- New menus: updates as a compact popup, backup (borg), quick look, downloads, YouTube.

**MacBook keyboard light** (`yumi-light`)
- The key backlight follows the ambient light sensor: on in the dark, off in daylight. A slider and an “auto” switch
  sit in the control center, and the Touch Bar has its own slider.
- The keys “breathe” when a Pomodoro phase ends or the battery runs low. A manual change always wins.

**Health check and patches**
- `yumi-doctor` now also checks the Touch Bar, Touch ID, pinned packages, the login screen, earlyoom and the key light.
- The source patches the desktop runs on (Hyprland first-frame hold and lock-screen keyboard fix, the awww crash fix)
  are in [`patches/`](patches/README.md).

**The whole shell on Quickshell**
- Bar, all menus, notification popups and the notification center, OSD (volume, brightness, keyboard backlight,
  layout, keep-awake), lock screen and the polkit / sudo password dialog are QML in `~/.config/quickshell/yumi`, started
  as one service, `yumi-quickshell`. The logic stays in small Python backends (`~/.local/lib/yumi/qs`) that speak
  JSON; QML only draws.
- **Removed:** Waybar, swaync, rofi, the GTK menus and SDDM. hyprlock stays only as an emergency fallback, used if
  Quickshell does not answer.
- Colors: the template `quickshell.dcol` → `~/.config/yumi/quickshell/colors.json`; the shell rereads it on the fly,
  so a new wallpaper recolors everything without a restart.

**The “Ink” style**
- Serif type (Noto Serif + Noto Serif CJK JP), thin lines instead of capsules, a red hanko seal 弓, animations
  without springs.
- In the bar: workspaces 一 二 三…, captions 核 (CPU), 憶 (memory), 電 (battery), 護 (VPN); menus as cards, square
  cover art in the player.

**Lock, login, password**
- **Lock screen “Scroll”** with the **“Stroke”** password field: a single line instead of a box.
- **Login screen on greetd** instead of SDDM — the same look, Quickshell inside a small sway session. At boot, autologin
  goes straight to Hyprland and the lock screen; after “Log out” you get this login screen instead of a black screen.
- **Password dialog** for polkit / sudo in the same style: `yumi-polkit-switch on|off|status` (`off` brings back
  hyprpolkitagent).

**Menus and wallpapers**
- Menus: Pult (`SUPER+Space`), Apps and files, Music, System, Wi-Fi, Bluetooth, VPN, Sound, Battery and power modes,
  Clipboard, Calendar, Workspaces, Processes, Tray, Keyboard shortcuts, Emoji and glyphs, Web search. The control
  center (`SUPER+C`) is a hub with links to every menu.
- **Session ring** (`SUPER+Esc`, `SUPER+Delete`): lock 鍵, sleep 眠, log out 出, reboot 再, power off 終 — hold to confirm.
- **Music** (`yumi-music`): YouTube Music + SoundCloud without an account, playlists, queue, synced lyrics.
- **Wallpaper widget** (`SUPER+SHIFT+W`): a carousel, styles (folders) → wallpapers, arrows to browse, a preview of the
  accent color under the picture. Colors of the whole desktop come from the wallpaper (`yumi-colors`).

**Portability**
- **`./install.sh`** — Arch Linux / Arch Linux ARM only: a question before every step, a backup first, `--dry-run`
  and `--uninstall`. Package lists in `packages/`: `arch.txt` (required), `aur.txt`, `optional.txt` (groups you can
  skip), `mac.txt`.
- **Mac parts are optional modules** (`RICE_MAC`): Touch Bar, battery charge limit, lid guard, AirPods mode, boot
  splash. They are installed only when a MacBook is detected. Touch ID is a separate public repository:
  [yumi-touchid](https://github.com/sonoyumi/yumi-touchid).
- **Monitors:** the built-in screen is any output named `eDP*`; scales and names live in
  `~/.config/yumi/monitors.conf` (an empty file is fine — everything gets 1.0).
- **License:** GPL-3.0-or-later instead of MIT — the color engine is a port of wallbash from HyDE (GPL-3.0).
  See [NOTICE](NOTICE).

<details>
<summary><b>Earlier versions: 3.0 · 2.5 · 2.1 · 2.0</b></summary>

#### 3.0

The first release on a base entirely my own, without HyDE: Hyprland in modules (`~/.config/hypr/yumi`), my own color
engine `yumi-colors`, the Pult (`SUPER+Space`), `yumi-doctor`, wallpaper collections, an SDDM theme, Zen as the
browser. The full notes are on the [3.0 release page](https://github.com/sonoyumi/yumi-rice/releases/tag/v3.0).

#### What's new in 2.5

> [!NOTE]
> **3.0 is coming — a big update.** The next major version moves to a base that is entirely my own: my own
> Hyprland config, systemd units, theming and scripts, **without HyDE underneath**. 2.5 is the last release built on HyDE.

**New**
- **AirPods on Linux** (`yumi-airpods` service): taking a bud out pauses the music, stem presses work, and the buds go
  back to the iPhone when the laptop locks. Pixel-drawn AirPods icons in Waybar (`YumiIcons` font, `build-font.py`).
- **Music** (`yumi-music`, `SUPER+SHIFT+M`): a YouTube Music + SoundCloud library with covers, playlists, queue and
  search. SoundCloud goes through its own WARP proxy (`yumi-music-proxy`); weekly update and sync timers.
- **Lyrics in the player:** under the card, synced line by line (YouTube Music → LRCLIB), with an offset for Bluetooth
  delay (`lyrics.conf`). Equalizer in the player pill — `yumi-eq`, a Waybar CFFI module in C (`.local/src/yumi-eq`).
- **Control center on GTK4** (`yumi-menu-control`): tiles, sliders, player card, "Do not disturb" and notification
  history (`yumi-notify-log`; service noise is filtered by `ignore.json`).
- **VPN without ExpressVPN** (`yumi-vpn`): Cloudflare WARP and Proton Free locations as NetworkManager WireGuard
  connections — menu, Waybar pill and control-center tile.
- **Keep awake everywhere** (☕ `yumi-caffeine` + guard timer), the lock screen goes dark while ☕ is on
  (`yumi-idle-action`), battery charge limit (`yumi-battery-limit`).
- **Apps in wallpaper colors** through accent hooks: Zen, Firefox, Vesktop, hyprtoolkit dialogs, Touch Bar; folder
  icons recolored to the palette (`recolor.py`, `yumi-folders-update`).

**Cleaner**
- `~/.local/bin`: 155 → ~90 files. 39 `*-uninstall` scripts, 27 `.bak` copies and 17 backup folders moved to
  `~/.local/share/yumi-archive`. One command for every rollback: `yumi-uninstall` (list) and `yumi-uninstall <module>` —
  it puts the backups back for the rollback and archives them again afterwards.
- About 4 GB of caches freed (AUR builds, HyDE installer, cargo, pip).
- Fixes: the VPN tile in the control center still called ExpressVPN; the music proxy check wrote to the journal
  twice a second (now cached for 30 s).

**`rice`**
- `./rice drift` — how far the system has drifted from the repository; a daily timer (`yumi-rice-drift`) sends a
  notification when it is time to `pull`.
- `./rice doctor` — all yumi services, crashes in the last 24 h, `.bak` files in PATH, files missing from the manifest.
- `./rice gc` — also moves `.bak` copies and rollbacks out of `~/.local/bin` into the archive.
- `./rice push-system` — takes a snapper snapshot before the first change in `/etc`.

#### What's new in 2.1

> [!IMPORTANT]
> **Built and tested only on my own machine:** MacBook Pro M1 (2560×1600, scale 1.666667) + MSI G27C3F
> (1920×1080 @ 180 Hz, scale 1). Versions 2.0–2.1 contain a lot of fine-tuning for exactly these two monitors and their
> scales — menu and rofi sizes, lock-screen fonts per monitor, panel heights. I don't know how the build behaves on
> another configuration: treat it as an example and adjust it to your hardware. Since 2.1 monitor names, interface
> scale and rofi DPI live in one file, `~/.config/yumi/monitors.conf` (a monitor that is not listed gets 1.0); only `yumi-panel/style.css`, `waybar/user-style.css` and the lock-screen template still have per-monitor values.
> Version 1.0 (rofi menus, HyDE themes) is still available: [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0).
>
> **Coming next:** I will keep checking performance and functionality and fix things where needed. In the next few days I'll add lock-screen screenshots and two more things that are already done but not published yet.

Measured on my machine (MacBook Pro M1, 8 GB, Firefox, Telegram and terminals open).

**Simpler**
- **Monitors in one file.** `~/.config/yumi/monitors.conf` holds each output's interface scale, rofi DPI and name
  (plus size and scale for building the lock screen while a monitor is unplugged). It is read by the menus
  (`yumipanel.py` through `yumimon.py`), `yumi-player`, `yumi-menu-workspaces`, `hyprlock-google-build`, `rofi` and
  `rofi-panel` — before, these values were hard-coded in six scripts. A monitor that is not listed gets 1.0, so a new
  machine works without edits. Per-monitor values remain only in CSS and in the lock-screen template.
- **Public and private parts in one file.** Private blocks are marked `yumi:private-begin/-end`, single lines
  `yumi:private-line`, public-only lines `yumi:public:`. `./rice pull` builds the public copy by itself
  (`tools/publicize`), no more maintaining two versions by hand.
- **Old rofi menus removed** — 13 files (they live on in [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)); `menu-workflows`, `rofi-panel` and
  `player-cover` stay. `hyde-patches.sh` lost two patches that `hyprland.lua` now does itself.
- **New `rice` commands:** `./rice check` — syntax of every file, personal paths, secrets, leftover markers, references
  to scripts that are not in the repository; `--install-hook` runs it before every commit. `./rice gc` — clean-up of
  `__pycache__` and old backups (shows first, deletes with `--apply`). `./rice doctor` now also shows the yumi services,
  failed units, faillock count, Waybar errors and memory pressure.

**Lighter**

| | 2.0 | 2.1 |
|---|---|---|
| Waybar script runs | ~100 a minute, 12.4 % of a core | ~12 a minute, 1.4 % |
| Wi-Fi / Bluetooth / VPN pill after a change in a menu | up to 5 s | right away |
| Mouse pill | ~1.7 s (Solaar), no DPI | 40 ms (kernel `hidpp_battery`), DPI shown |
| `nm-applet` + blueman tray icon | ~48 MB | off |

- **Pills on events:** the `yumi-bar-events` service (~9 MB) listens to NetworkManager, BlueZ and power-profiles-daemon
  on D-Bus and signals Waybar; timers stay only as a safety net (30–120 s).
- **Mouse:** battery and charging come from the kernel; DPI and polling rate from a cache that Solaar refreshes at most
  every 30 minutes (the mouse menu clears it after a change). `blueman-applet` stays as the pairing agent (PIN dialog).
- **Memory, honestly:** a GTK menu takes ~60 MB while it is open (a rofi menu took ~12 MB) and frees it on close; in the
  background the whole shell (Waybar, swaync, tray, Solaar…) is ~170 MB — about 2 % of 8 GB.

#### What's new in 2.0

- **GTK4 menus instead of rofi in the bar (`yumi-panel`):** one framework (`~/.local/lib/yumi-panel`) — a layer-shell
  window with blur, wallpaper colors, keyboard navigation. Menus: Wi-Fi, Bluetooth, sound, VPN (ExpressVPN / Tailscale),
  power and HyDE modes, session, system (updates, btrfs snapshots, resources), processes, mouse (DPI, polling rate),
  calendar with reminders, clipboard, wallpaper picker, workspaces, tray. The old rofi menus were removed in 2.1 (they are in [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)).
- **Accent from the wallpaper (`yumi-accent`):** one accent color is taken from the wallpaper and passed through hooks
  to Waybar, swaync, rofi, kitty, GTK/Qt, window borders, VS Code and Telegram.
- **New lock screen "Yumi Google":** `hyprlock-google-build` builds it from a template for each monitor — clock,
  quotes, player, system info. The previous layout (`layout20.conf`) is still there.
- **Pills and control center:** Wi-Fi, Bluetooth, "keep awake" (☕ stops hypridle), a player pill with cover art and
  the `yumi-player` popup; control center with "Do not disturb", keep-awake and mouse buttons.
- **Also:** calendar reminders (systemd timer), a tray without duplicate applets, a Telegram theme in wallpaper colors,
  hiding unneeded app launchers (`yumi-app-hide`), `SUPER+K` switches the layout on all keyboards at once, and the lock
  screen always opens with the English layout. Every add-on has its own `*-uninstall` script.
</details>

### Features

- **Bar in the “Ink” style:** the seal, workspaces in kanji, CPU and memory on the left; the player with cover art
  and a cava equalizer of small squares in the center; control center, keyboard layout, VPN (only while it is on),
  keep-awake, Wi-Fi with the network name, Bluetooth with the number of devices, sound, clock, battery and power on
  the right. Pills update on D-Bus events (`yumi-bar-events`), not by polling.
- **Menus on QML:** one framework, one menu open at a time, keyboard navigation, closes on `Esc` or a click outside.
- **Notifications:** popups and a notification center — a list with `↑` `↓`, `Enter`, `Del`, `H` to hide an app,
  `D` for “Do not disturb”, “Clear” with a second press.
- **OSD** for volume, microphone, brightness, keyboard backlight, layout and keep-awake.
- **Lock screen “Scroll”:** `yumi-lock` locks through Quickshell; if it does not answer in about 2 s, hyprlock takes
  over. At boot the desktop is drawn *under* the lock.
- **Login screen:** greetd + sway + the same QML screen; a copy of the theme lives in `/var/lib/yumi-greeter` and
  follows the wallpaper (`yumi-greeter-sync`).
- **Everything follows the wallpaper:** `yumi-colors` and the hooks in `~/.config/yumi/accent/hooks.d` recolor the
  shell, kitty, GTK/Qt, window borders, VS Code, Zen, Telegram, Vesktop, Obsidian, folder icons, the keyboard
  backlight and the login screen.
- **Music:** `yumi-music` — YouTube Music + SoundCloud with covers, playlists and lyrics; `yumi-airpods` pauses when
  a bud comes out.
- **Living on 8 GB:** zram the size of RAM + a swap file; earlyoom closes browser tabs first and never the desktop;
  Zen runs in its own cgroup (`zen.slice`); `lim 1G <command>` runs test servers in `dev.slice` with a memory cap.
- **System:** silent boot, btrfs snapshots with snapper (optional group: snap-pac before and after every pacman run),
  faillock, BlueZ Experimental for headphone battery.
- **Two monitors on an M1 MacBook:** the external display runs over USB-C DisplayPort alt mode thanks to
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Workspaces 1–5 live on the MacBook, 6–10 on the
  external monitor; unplug it and they move to the laptop.
- **Logitech without G HUB** (optional): a mouse menu with DPI and polling rate (Solaar); the keyboard backlight
  follows the bar accent through an OpenRGB server.
- **MacBook extras** (optional modules): Touch Bar layers and styles ([touchbard](https://github.com/0800tim/touchbard)),
  battery charge limit, a guard that brings the built-in screen back after the lid, Touch ID for sudo and the lock
  screen ([yumi-touchid](https://github.com/sonoyumi/yumi-touchid), installed separately).
- **Every change can be undone:** `./install.sh --uninstall` puts the backups back, `./rice push` keeps the previous
  version of each file, and add-ons are rolled back with `yumi-uninstall <module>`.

### Screenshots

![Wallpaper change](assets/screenshots/v3.1/wallpaper-change.gif)
<p align="center">One new wallpaper — and everything recolors together: the bar, menus, terminals, window borders</p>

| | |
|:---:|:---:|
| ![Lock screen](assets/screenshots/v3.1/lock.jpg) | ![Login screen (greetd)](assets/screenshots/v3.1/greeter.jpg) |
| Lock screen | Login screen (greetd) |
| ![Bar](assets/screenshots/v3.1/bar.png) | ![Password dialog](assets/screenshots/v3.1/polkit.png) |
| Bar | Password dialog (polkit / sudo) |
| ![Control center](assets/screenshots/v3.1/control.png) | ![Notifications](assets/screenshots/v3.1/notifications.png) |
| Control center | Notification center |
| ![Pult](assets/screenshots/v3.1/pult.png) | ![Apps](assets/screenshots/v3.1/launcher.png) |
| Pult (SUPER+Space) | Apps |
| ![Music](assets/screenshots/v3.1/music.png) | ![Player](assets/screenshots/v3.1/player.png) |
| Music with lyrics | Player |
| ![Wi-Fi](assets/screenshots/v3.1/menu-wifi.png) | ![Bluetooth](assets/screenshots/v3.1/menu-bluetooth.png) |
| Wi-Fi | Bluetooth |
| ![Sound](assets/screenshots/v3.1/menu-sound.png) | ![VPN](assets/screenshots/v3.1/menu-vpn.png) |
| Sound | VPN |
| ![System](assets/screenshots/v3.1/menu-system.png) | ![Battery and power](assets/screenshots/v3.1/menu-power.png) |
| System | Battery and power modes |
| ![Clipboard](assets/screenshots/v3.1/menu-clipboard.png) | ![Calendar](assets/screenshots/v3.1/menu-calendar.png) |
| Clipboard | Calendar |
| ![Session ring](assets/screenshots/v3.1/session.png) | ![Workspaces](assets/screenshots/v3.1/menu-workspaces.png) |
| Session ring | Workspaces |

![Wallpaper widget](assets/screenshots/v3.1/wallpaper-widget.png)
<p align="center">Wallpaper widget: styles → wallpapers, accent preview</p>

<p align="center">MacBook (2560×1600) and MSI (1920×1080) side by side</p>

> Private data in the screenshots is blurred.

<details>
<summary><b>3.0 and earlier</b></summary>

https://github.com/user-attachments/assets/72154592-2090-4faa-a56b-40aeb462c0ba
<p align="center">3.0 showcase: windows, dwindle / master / scrolling layouts, workspaces, player with lyrics, wallpaper changes</p>

| | |
|:---:|:---:|
| ![Desktop 3.0](assets/screenshots/v3/desktop.jpg) | ![Pult 3.0](assets/screenshots/v3/pult.png) |
| Desktop (3.0, Waybar) | Pult (3.0) |
| ![Control center 3.0](assets/screenshots/v3/menu-control.png) | ![Login screen 3.0](assets/screenshots/v3/sddm.jpg) |
| Control center (3.0, GTK4) | Login screen (3.0, SDDM) |

| | |
|:---:|:---:|
| ![Player with lyrics](assets/screenshots/v2.5/player-lyrics.png) | ![Control center](assets/screenshots/v2.5/control-center.png) |
| Player with lyrics | Control center (GTK4) |
| ![VPN](assets/screenshots/v2.5/menu-vpn.png) | ![Bluetooth](assets/screenshots/v2.5/menu-bluetooth.png) |
| VPN: WARP / Proton + Tailscale | Bluetooth and AirPods |

![Music](assets/screenshots/v2.5/music.png)
<p align="center">Music: YouTube Music + SoundCloud, lyrics on the side</p>

![Waybar 2.5](assets/screenshots/v2.5/bar.png)

**2.0–2.1**

| | |
|:---:|:---:|
| ![Control center](assets/screenshots/v2/control-center.png) | ![Sound](assets/screenshots/v2/menu-sound.png) |
| Control center | Sound |
| ![Wi-Fi](assets/screenshots/v2/menu-wifi.png) | ![Bluetooth](assets/screenshots/v2/menu-bluetooth.png) |
| Wi-Fi | Bluetooth |
| ![Power](assets/screenshots/v2/menu-power.png) | ![System](assets/screenshots/v2/menu-system.png) |
| Power and HyDE modes | System: updates, snapshots, resources |
| ![Mouse](assets/screenshots/v2/menu-mouse.png) | ![Calendar](assets/screenshots/v2/menu-calendar.png) |
| Mouse | Calendar |
| ![Session](assets/screenshots/v2/menu-session.png) | ![Player](assets/screenshots/v2/player.png) |
| Session | Player |

![Wallpaper picker](assets/screenshots/v2/menu-wallpaper.png)
<p align="center">Wallpaper picker</p>

![Two monitors](assets/screenshots/v2/two-monitors.jpg)
<p align="center">MacBook (2560×1600) and MSI (1920×1080 @ 180 Hz) side by side</p>

![Waybar](assets/screenshots/v2/bar.png)

<details>
<summary><b>Version 1.0</b> — rofi menus (for comparison)</summary>

| | |
|:---:|:---:|
| ![Workspace](assets/screenshots/v1/workspace.jpg) | ![Control center](assets/screenshots/v1/control-center.jpg) |
| Workspace | Control center |
| ![Bluetooth](assets/screenshots/v1/menu-bluetooth.png) | ![Processes](assets/screenshots/v1/menu-top.png) |
| Bluetooth | Heaviest apps |
| ![Player](assets/screenshots/v1/menu-player.png) | ![Network](assets/screenshots/v1/menu-network.png) |
| Player card | Network and VPN |
| ![Sound](assets/screenshots/v1/menu-sound.png) | ![Power](assets/screenshots/v1/menu-power.png) |
| Sound | Power menu |

![Desktop 1.0](assets/screenshots/v1/desktop.jpg)
![Two monitors 1.0](assets/screenshots/v1/two-monitors.jpg)
![Waybar 1.0](assets/screenshots/v1/bar.png)

</details>
</details>

### Keys and gestures

| Keys | Action |
|---|---|
| `SUPER` + `Space` | Pult: apps, commands, files, calculator, emoji, web |
| `SUPER` + `A` / `SUPER` + `SHIFT` + `E` | Apps / files |
| `SUPER` + `C` | Control center — links to every menu |
| `SUPER` + `CTRL` + `W` / `B` / `V` / `A` | Wi-Fi / Bluetooth / VPN / sound |
| `SUPER` + `CTRL` + `E` / `T` / `Y` | Battery and power modes / processes / tray |
| `SUPER` + `CTRL` + `C` / `N` / `K` | Calendar / notification center / keyboard shortcuts |
| `SUPER` + `Esc`, `SUPER` + `Delete`, `CTRL` + `ALT` + `Del` | Session ring: lock, sleep, log out, reboot, power off |
| `SUPER` + `N` | Lock the screen |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Player / music |
| `SUPER` + `V` | Clipboard |
| `SUPER` + `TAB` | Workspaces |
| `SUPER` + `` ` `` | System menu |
| `SUPER` + `,` / `SUPER` + `.` | Emoji / glyphs |
| `SUPER` + `SHIFT` + `/` | Web search |
| `SUPER` + `SHIFT` + `W` | Wallpaper widget |
| `SUPER` + `ALT` + `←` / `→` | Previous / next wallpaper |
| `SUPER` + `ALT` + `↑` / `↓` | Next / previous work mode |
| `SUPER` + `K` | Keyboard layout on all keyboards |
| `SUPER` + `P` / `ALT` + `P` / `SHIFT` + `P`, `Print` | Screenshot: area / frozen screen / monitor / all monitors |
| `SUPER` + `ALT` + `Space` / `,` / `.` | Play-pause / previous / next track |
| `ALT` + `F9`…`F12`, `ALT` + `Print` / `Scroll Lock` / `Pause` | Media and volume on the external keyboard |
| 3 fingers ← / → | Switch workspaces |
| 3 fingers ↓ | Workspace overview |
| 4 fingers | Focus the window in the swipe direction |

### Installation

> [!WARNING]
> **Arch Linux and Arch Linux ARM only.** Tested on a MacBook Pro M1 (Asahi); on other Arch hardware it has not been
> tried yet — please report problems. The system files in `/etc` (GRUB, zram, earlyoom, Bluetooth) come from my
> machine: the installer asks about each one, and if you are not sure, answer “no”.

```zsh
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./install.sh --dry-run   # show what would be done, change nothing
./install.sh             # install: a question before every step, a backup first
```

The installer puts the packages from `packages/` in place (AUR through `paru` or `yay`, optional groups on request),
copies the files with `./rice push`, sets up the greetd login screen, the user services and the password dialog. Then
put some pictures into `~/Pictures/Wallpapers`, reboot and run `yumi-doctor`. Monitors: `~/.config/yumi/monitors.conf`
(output names from `hyprctl monitors`); lock-screen avatar: `~/.config/hypr/hyprlock/avatar.jpg`.

Rollback: `./install.sh --uninstall` — puts back the files from the backups, switches off the services and greetd and
returns the previous login manager. Packages are removed only if you agree separately.

Step by step, with every question and the known limits: [INSTALL.md](INSTALL.md) (in Russian for now).

### The `rice` script

The repository is the source of truth; `rice` syncs it with the system.

| Command | What it does |
|---|---|
| `./rice pull` | System → repository |
| `./rice diff [path]` | What differs between the system and the repository |
| `./rice push` | Repository → `~` (backs up the previous versions) |
| `./rice push-system [filter]` | Repository → `/etc` (diff and confirmation for every file, snapper snapshot first) |
| `./rice files` | Which files `push` installs (honours `RICE_LOCAL` and `RICE_MAC`) |
| `./rice reload` | Reload Hyprland, Quickshell, systemd --user |
| `./rice add <path>` | Start tracking a file |
| `./rice doctor` | `yumi-doctor` plus repository details: services, crashes, drift, files outside the manifest |
| `./rice check` | Repository check before a commit: syntax, private data, secrets (`--install-hook` runs it on every commit) |
| `./rice gc [--apply]` | Clean-up: `__pycache__`, old `rice-bak` archives, `.bak` and rollbacks from `~/.local/bin` into the archive (without `--apply` it only shows) |
| `./rice drift [--notify [N]]` | How far the system drifted from the repository (notification above N blocks) |

Personal tweaks live outside the repository in `~/.config/rice-local/` (same layout as `home/`, plus its own
`manifest.txt`): `./rice` installs them instead of the public files, so private changes never reach GitHub.
Private blocks inside a shared file are marked `yumi:private-begin/-end` and cut out by `tools/publicize`.
`RICE_LOCAL=off ./rice push` installs the clean public version; `RICE_MAC=off` skips the Mac block of the manifest.

Workflow: edit in `home/…` → `./rice push` → `./rice reload` → check → `git commit`.
Didn't like it — `git checkout -- <file>` and `./rice push` again.

### Project structure

```
yumi-rice/
├── install.sh              # installer (Arch / Arch ARM): --dry-run, --uninstall
├── INSTALL.md              # installation step by step
├── packages/               # arch.txt, aur.txt, optional.txt (groups), mac.txt
├── home/
│   ├── .config/quickshell/yumi/  # the shell: bar, menus, notifications, osd, lock, polkit, greeter.qml
│   ├── .config/hypr/       # hyprland.lua + yumi/ (modules, work modes), hypridle, fallback hyprlock
│   ├── .config/yumi/       # monitors.conf, accent hooks, color templates, login screen (greeter/sway.conf)
│   ├── .config/systemd/    # yumi-* services and timers, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # yumi-* commands: lock, wallpaper, colors, music, doctor, greeter…
│   ├── .local/lib/yumi/    # qs (menu backends), bar (bar scripts), colors, tray, calendar, fetch…
│   └── .local/share/       # VS Code theme, music helpers, folder icons, picker data
├── system/etc/             # greetd + PAM, GRUB, zram, sysctl, earlyoom, BlueZ, faillock
├── patches/                # source patches: Hyprland, awww (see patches/README.md)
├── assets/screenshots/
├── manifest.txt            # tracked files from ~ (the Mac part between # @mac and # @end)
├── system-manifest.txt     # tracked files from /etc
├── rice                    # sync script
├── NOTICE                  # authors and third-party licenses
└── tools/                  # publicize (public copy from private), check (pre-commit check)
```

### Gotchas: Hyprland 0.56 Lua, Quickshell and Asahi

- Options use dots: `hyprctl getoption decoration.rounding`. Dispatchers are Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` doesn't work — use `hyprctl eval 'hl.config({...})'`.
- The scale must divide the resolution: `1.666667`, not `1.67`.
- `Hyprland --verify-config` **runs** the `exec` commands of the config it checks — check only the live config, never a copy.
- Quickshell: stop it with `systemctl --user stop yumi-quickshell` or `qs kill -c yumi`, never `pkill qs` — that also
  kills test instances. File watching is off, so QML edits show up only after `systemctl --user restart yumi-quickshell`.
- Don't start and close the real lock screen to test it: an aborted PAM conversation counts as a wrong password for
  faillock (3 attempts → 10 minutes, and sudo is locked too). Use the preview: `qs -c yumi ipc call lock preview`.
- greetd reads `/etc/greetd/config.toml` only when it starts; `systemctl restart greetd` ends the current session.
- `hypridle.conf` sources **every** file in `hypridle/` — any backup next to your config overrides it.
- GRUB can't write `grubenv` on btrfs — no `GRUB_SAVEDEFAULT`. Parameter order matters: `quiet loglevel=3`.
- Asahi has no MGLRU; power-profiles-daemon offers only `balanced` and `power-saver`.
- 16K pages: images with jemalloc built for 4K crash — `muvm` helps. Quickshell itself runs fine on 16K pages.
- `MemoryHigh` without free swap freezes a process instead of killing it — use `MemoryMax`.
- AirPods with macOS dual boot: `br-connection-key-missing` → remove and pair again.
- Solaar reapplies its saved LED zones on start and can switch the keyboard backlight off: mark `led_control` and
  `led_zone_*` as `ignore` in its config.
- OpenRGB `Direct` mode on the PRO keyboard drops keys and its LED order does not match the layout: `Static` is reliable.
- Plain `openrgb` rescans every USB device for a few seconds on each call, and Solaar fails to read the mouse
  meanwhile: start `openrgb --server` once at login and send colors with `--client`.
- A monitor connected after login gets a black background: redraw the wallpaper on `monitor.added`.
- dp-altmode: after unplugging the monitor and suspending, the next connect can fail until a reboot (a known open bug).
  Kernel updates need the patch rebuilt.
- atuin: an empty `sync_address = ""` breaks it — to stay local, set `auto_sync = false` and leave the address out.

### Credits

[Hyprland](https://hyprland.org/) · [Quickshell](https://quickshell.org/) · [Asahi Linux](https://asahilinux.org/) ·
[HyDE](https://github.com/HyDE-Project/HyDE) (the base of versions 1.0–2.5; `yumi-colors` is a port of its wallbash) ·
[greetd](https://git.sr.ht/~kennylevinsen/greetd) · [sway](https://swaywm.org/) (login screen) ·
[touchbard](https://github.com/0800tim/touchbard) (Touch Bar) · [Zen](https://zen-browser.app/) ·
[starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) ·
[fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[dp-altmode](https://github.com/haripako/dp-altmode) by haripako (USB-C DisplayPort on M1) ·
[Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/) ·
fonts Noto Serif, Noto Serif CJK JP, Inter, JetBrains Mono

### Author

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)), Python developer: Telegram bots, web scraping, automation.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Need a Linux desktop set up or a routine automated with scripts? Get in touch.

### License

GPL-3.0-or-later, see [LICENSE](LICENSE). Third-party parts are listed in [NOTICE](NOTICE): wallbash from HyDE
(GPL-3.0), touchbard (MIT), fonts (SIL OFL 1.1, installed from the repositories, not bundled).
Versions up to 3.0 were released under MIT.

---

<a name="it"></a>

## 🇮🇹 Italiano

**[🇬🇧 English](#en)** · **🇮🇹 Italiano** · **[🇺🇦 Українська](#uk)** · **[🇷🇺 Русский](#ru)**

Il mio desktop Hyprland su un MacBook Pro M1 con Asahi Linux. Dalla 3.1 tutta la shell — barra, menu, notifiche,
indicatori a schermo, schermata di blocco, schermata di accesso e finestra della password — è scritta in QML su
[Quickshell](https://quickshell.org/), nello stile “Inchiostro”: caratteri con grazie, didascalie giapponesi, un sigillo
hanko rosso. Tutto prende i colori dallo sfondo attuale. In più, un installer per Arch Linux / Arch Linux ARM e uno
script che tiene allineati repository e sistema, con un backup di ogni file che tocca.

| | |
|---|---|
| Hardware | MacBook Pro 13" M1 (2020), 8 GB di RAM, schermo 2560×1600, scala 1.666667 · secondo monitor MSI G27C3F 1920×1080 via USB-C · tastiera Logitech PRO e mouse PRO X 2 |
| Sistema | Arch Linux ARM ([Asahi](https://asahilinux.org/)), kernel `linux-asahi`, pagine di memoria da 16K, btrfs |
| Desktop | Hyprland 0.56 con configurazione Lua, base mia `~/.config/hypr/yumi` |
| Barra / notifiche / menu / OSD | Quickshell (QML) — un solo servizio, `yumi-quickshell` |
| Blocco / accesso / password | schermata di blocco Quickshell · greetd con schermata di accesso Quickshell · agente polkit Quickshell |
| Inattività / sfondo | hypridle · awww |
| Terminale / shell / font | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Font della shell | Noto Serif · Noto Serif CJK JP · JetBrains Mono Nerd Font · Inter |
| Browser | [Zen](https://zen-browser.app/) (facoltativo) |

### Novità della 3.1

> [!NOTE]
> **Provato su un MacBook Pro M1 (Asahi).** L'installer è scritto per qualsiasi macchina Arch Linux / Arch Linux ARM,
> ma su altro hardware non è ancora stato provato: è la prossima verifica. Se qualcosa non va, apri una issue.

**Lo stile “Isola”**
- Capsule piene nei colori dello sfondo su barra, menu, schermata di blocco e Touch Bar; il sigillo 弓 come marchio
  del sistema.
- **Dynamic Island** al centro della barra: brano in riproduzione, timer e Pomodoro, download, microfono in uso,
  cambi di rete e VPN, AirPods — un solo posto per tutto ciò che sta succedendo adesso (`yumi-island`).
- Nuovi menu: aggiornamenti come popup compatto, backup (borg), anteprima rapida, download, YouTube.

**Luce della tastiera del MacBook** (`yumi-light`)
- La retroilluminazione dei tasti segue il sensore di luce ambientale: accesa al buio, spenta di giorno. Nel centro
  di controllo ci sono un cursore e l'interruttore “auto”; la Touch Bar ha il suo cursore.
- I tasti “respirano” quando finisce una fase del Pomodoro o la batteria è scarica. La regolazione manuale vince sempre.

**Controllo di salute e patch**
- `yumi-doctor` ora controlla anche Touch Bar, Touch ID, pacchetti bloccati, schermata di accesso, earlyoom e luce
  dei tasti.
- Le patch ai sorgenti su cui gira il desktop (attesa del primo fotogramma e tastiera sulla schermata di blocco per
  Hyprland, correzione del crash di awww) sono in [`patches/`](patches/README.md).

**Tutta la shell su Quickshell**
- Barra, tutti i menu, i popup delle notifiche e il centro notifiche, l'OSD (volume, luminosità, retroilluminazione
  della tastiera, layout, “resta sveglio”), la schermata di blocco e la finestra della password polkit / sudo sono QML
  in `~/.config/quickshell/yumi`, avviati come un solo servizio, `yumi-quickshell`. La logica resta in piccoli backend
  Python (`~/.local/lib/yumi/qs`) che parlano JSON; il QML si limita a disegnare.
- **Rimossi:** Waybar, swaync, rofi, i menu GTK e SDDM. hyprlock resta solo come riserva d'emergenza, se Quickshell
  non risponde.
- Colori: il modello `quickshell.dcol` → `~/.config/yumi/quickshell/colors.json`; la shell lo rilegge al volo, quindi
  un nuovo sfondo ricolora tutto senza riavvio.

**Lo stile “Inchiostro”**
- Caratteri con grazie (Noto Serif + Noto Serif CJK JP), linee sottili al posto delle capsule, un sigillo hanko rosso
  弓, animazioni senza molle.
- Nella barra: spazi di lavoro 一 二 三…, didascalie 核 (CPU), 憶 (memoria), 電 (batteria), 護 (VPN); menu a schede,
  copertina quadrata nel lettore.

**Blocco, accesso, password**
- **Schermata di blocco “Rotolo”** con il campo password **“Tratto”**: una sola linea invece di una casella.
- **Schermata di accesso su greetd** al posto di SDDM — lo stesso aspetto, Quickshell dentro una piccola sessione sway.
  All'avvio l'accesso automatico porta dritto a Hyprland e alla schermata di blocco; dopo “Esci” compare questa
  schermata invece di uno schermo nero.
- **Finestra della password** per polkit / sudo nello stesso stile: `yumi-polkit-switch on|off|status` (`off` riporta
  hyprpolkitagent).

**Menu e sfondi**
- Menu: Pult (`SUPER+Space`), App e file, Musica, Sistema, Wi-Fi, Bluetooth, VPN, Audio, Batteria e modalità di
  alimentazione, Appunti, Calendario, Spazi di lavoro, Processi, Tray, Scorciatoie, Emoji e glifi, Ricerca web. Il
  centro di controllo (`SUPER+C`) fa da snodo con i collegamenti a tutti i menu.
- **Anello della sessione** (`SUPER+Esc`, `SUPER+Delete`): blocca 鍵, sospendi 眠, esci 出, riavvia 再, spegni 終 — tieni
  premuto per confermare.
- **Musica** (`yumi-music`): YouTube Music + SoundCloud senza account, playlist, coda, testi sincronizzati.
- **Widget degli sfondi** (`SUPER+SHIFT+W`): un carosello, stili (cartelle) → sfondi, frecce per scorrere, anteprima
  del colore d'accento sotto l'immagine. I colori di tutto il desktop vengono dallo sfondo (`yumi-colors`).

**Portabilità**
- **`./install.sh`** — solo Arch Linux / Arch Linux ARM: una domanda prima di ogni passo, prima un backup,
  `--dry-run` e `--uninstall`. Elenchi dei pacchetti in `packages/`: `arch.txt` (obbligatori), `aur.txt`,
  `optional.txt` (gruppi che si possono saltare), `mac.txt`.
- **Le parti per Mac sono moduli facoltativi** (`RICE_MAC`): Touch Bar, limite di carica della batteria, guardia del
  coperchio, modalità AirPods, splash di avvio. Si installano solo se viene rilevato un MacBook. Touch ID è un
  repository pubblico a parte: [yumi-touchid](https://github.com/sonoyumi/yumi-touchid).
- **Monitor:** lo schermo integrato è qualsiasi uscita con nome `eDP*`; scale e nomi stanno in
  `~/.config/yumi/monitors.conf` (un file vuoto va bene: tutto a 1.0).
- **Licenza:** GPL-3.0-or-later invece di MIT — il motore dei colori è un port di wallbash da HyDE (GPL-3.0).
  Vedi [NOTICE](NOTICE).

<details>
<summary><b>Versioni precedenti: 3.0 · 2.5 · 2.1 · 2.0</b></summary>

#### 3.0

La prima versione su una base tutta mia, senza HyDE: Hyprland a moduli (`~/.config/hypr/yumi`), un motore dei colori
mio `yumi-colors`, il Pult (`SUPER+Space`), `yumi-doctor`, collezioni di sfondi, un tema SDDM, Zen come browser. Le note
complete sono nella [pagina della release 3.0](https://github.com/sonoyumi/yumi-rice/releases/tag/v3.0).

#### Novità della 2.5

> [!NOTE]
> **Sta arrivando la 3.0 — un grande aggiornamento.** La prossima versione passa a una base tutta mia: configurazione
> Hyprland, unità systemd, temi e script miei, **senza HyDE sotto**. La 2.5 è l'ultima versione basata su HyDE.

**Novità**
- **AirPods su Linux** (servizio `yumi-airpods`): togliendo un auricolare la musica va in pausa, i tocchi sullo stelo
  funzionano e gli auricolari tornano all'iPhone quando il portatile si blocca. Icone AirPods disegnate pixel per pixel
  in Waybar (font `YumiIcons`, `build-font.py`).
- **Musica** (`yumi-music`, `SUPER+SHIFT+M`): libreria YouTube Music + SoundCloud con copertine, playlist, coda e
  ricerca. SoundCloud passa da un proxy WARP dedicato (`yumi-music-proxy`); timer settimanali di aggiornamento e sync.
- **Testi nel player:** sotto la scheda, sincronizzati riga per riga (YouTube Music → LRCLIB), con correzione per il
  ritardo Bluetooth (`lyrics.conf`). Equalizzatore nella pillola del player — `yumi-eq`, modulo CFFI di Waybar in C.
- **Centro di controllo in GTK4** (`yumi-menu-control`): riquadri, cursori, scheda del player, "Non disturbare" e
  cronologia delle notifiche (`yumi-notify-log`; il rumore di servizio è filtrato da `ignore.json`).
- **VPN senza ExpressVPN** (`yumi-vpn`): località Cloudflare WARP e Proton Free come connessioni WireGuard di
  NetworkManager — menu, pillola in Waybar e riquadro nel centro di controllo.
- **Schermo sempre acceso ovunque** (☕ `yumi-caffeine` + timer di controllo), la schermata di blocco si spegne con ☕
  attivo (`yumi-idle-action`), limite di carica della batteria (`yumi-battery-limit`).
- **App nei colori dello sfondo** tramite gli hook dell'accento: Zen, Firefox, Vesktop, finestre hyprtoolkit, Touch Bar;
  icone delle cartelle ricolorate con la palette (`recolor.py`, `yumi-folders-update`).

**Più ordine**
- `~/.local/bin`: da 155 a ~90 file. 39 script `*-uninstall`, 27 copie `.bak` e 17 cartelle di backup spostati in
  `~/.local/share/yumi-archive`. Un solo comando per ogni ripristino: `yumi-uninstall` (elenco) e
  `yumi-uninstall <modulo>` — rimette i backup al loro posto per il ripristino e poi li riarchivia.
- Circa 4 GB di cache liberati (build AUR, installer di HyDE, cargo, pip).
- Correzioni: il riquadro VPN nel centro di controllo chiamava ancora ExpressVPN; il controllo del proxy musicale
  scriveva nel journal due volte al secondo (ora il risultato vale 30 s).

**`rice`**
- `./rice drift` — quanto il sistema si è allontanato dal repository; un timer giornaliero (`yumi-rice-drift`) avvisa
  quando è ora di fare `pull`.
- `./rice doctor` — tutti i servizi yumi, crash delle ultime 24 h, file `.bak` nel PATH, file fuori dal manifest.
- `./rice gc` — sposta nell'archivio anche le copie `.bak` e i ripristini da `~/.local/bin`.
- `./rice push-system` — crea uno snapshot snapper prima della prima modifica in `/etc`.

#### Novità della 2.1

> [!IMPORTANT]
> **Costruita e provata solo sulla mia macchina:** MacBook Pro M1 (2560×1600, scala 1.666667) + MSI G27C3F
> (1920×1080 @ 180 Hz, scala 1). Le versioni 2.0–2.1 contengono molte regolazioni fatte proprio per questi due monitor e le
> loro scale — dimensioni dei menu e di rofi, font della schermata di blocco per ogni monitor, altezze dei pannelli.
> Non so come si comporti su un'altra configurazione: usala come esempio e adattala al tuo hardware. Dalla 2.1 nomi dei
> monitor, scala dell'interfaccia e DPI di rofi stanno in un solo file, `~/.config/yumi/monitors.conf` (un monitor non elencato usa 1.0); valori per monitor restano solo in `yumi-panel/style.css`, `waybar/user-style.css` e nel template della schermata di blocco.
> La versione 1.0 (menu rofi, temi HyDE) resta disponibile: [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0).
>
> **Prossimamente:** continuerò a verificare ottimizzazione e funzionalità e, se serve, farò correzioni. Nei prossimi giorni aggiungerò gli screenshot della schermata di blocco e altre due cose già pronte ma non ancora pubblicate.

Misurato sulla mia macchina (MacBook Pro M1, 8 GB, con Firefox, Telegram e terminali aperti).

**Più semplice**
- **Monitor in un solo file.** `~/.config/yumi/monitors.conf` contiene per ogni uscita scala dell'interfaccia, DPI di
  rofi e nome (più dimensioni e scala per costruire la schermata di blocco quando il monitor è scollegato). Lo leggono i
  menu (`yumipanel.py` tramite `yumimon.py`), `yumi-player`, `yumi-menu-workspaces`, `hyprlock-google-build`, `rofi` e
  `rofi-panel` — prima questi valori erano scritti in sei script. Un monitor non elencato usa 1.0, quindi su un'altra
  macchina funziona senza modifiche. Valori per monitor restano solo nel CSS e nel template della schermata di blocco.
- **Parti pubbliche e private in un solo file.** I blocchi privati sono marcati `yumi:private-begin/-end`, le singole
  righe `yumi:private-line`, le righe solo pubbliche `yumi:public:`. `./rice pull` crea da solo la copia pubblica
  (`tools/publicize`): niente più due versioni da tenere a mano.
- **Rimossi i vecchi menu rofi** — 13 file (restano in [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)); `menu-workflows`, `rofi-panel` e `player-cover`
  restano. `hyde-patches.sh` ha perso due modifiche che ora fa direttamente `hyprland.lua`.
- **Nuovi comandi `rice`:** `./rice check` — sintassi di ogni file, percorsi personali, segreti, marcatori rimasti,
  riferimenti a script non presenti nel repository; `--install-hook` lo esegue prima di ogni commit. `./rice gc` —
  pulizia di `__pycache__` e vecchi backup (prima mostra, cancella con `--apply`). `./rice doctor` ora mostra anche i
  servizi yumi, le unità fallite, il contatore di faillock, gli errori di Waybar e la pressione della memoria.

**Più leggera**

| | 2.0 | 2.1 |
|---|---|---|
| Script lanciati da Waybar | ~100 al minuto, 12,4 % di un core | ~12 al minuto, 1,4 % |
| Pillola Wi-Fi / Bluetooth / VPN dopo una modifica dal menu | fino a 5 s | subito |
| Pillola del mouse | ~1,7 s (Solaar), senza DPI | 40 ms (kernel `hidpp_battery`), con DPI |
| `nm-applet` + icona di blueman | ~48 MB | spenti |

- **Pillole sugli eventi:** il servizio `yumi-bar-events` (~9 MB) ascolta NetworkManager, BlueZ e power-profiles-daemon
  su D-Bus e avvisa Waybar; i timer restano solo di sicurezza (30–120 s).
- **Mouse:** batteria e ricarica arrivano dal kernel; DPI e frequenza da una cache che Solaar aggiorna al massimo ogni
  30 minuti (il menu del mouse la cancella dopo una modifica). `blueman-applet` resta come agente di abbinamento (PIN).
- **Memoria, onestamente:** un menu GTK occupa ~60 MB mentre è aperto (un menu rofi ~12 MB) e li libera alla chiusura;
  in background tutta la shell (Waybar, swaync, tray, Solaar…) occupa ~170 MB — circa il 2 % di 8 GB.

#### Novità della 2.0

- **Menu GTK4 al posto di rofi nella barra (`yumi-panel`):** un unico framework (`~/.local/lib/yumi-panel`) — finestra
  layer-shell con sfocatura, colori dello sfondo, navigazione da tastiera. Menu: Wi-Fi, Bluetooth, audio, VPN
  (ExpressVPN / Tailscale), alimentazione e modalità HyDE, sessione, sistema (aggiornamenti, snapshot btrfs, risorse),
  processi, mouse (DPI, frequenza), calendario con promemoria, appunti, scelta dello sfondo, scrivanie, tray.
  I vecchi menu rofi sono stati rimossi nella 2.1 (si trovano in [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)).
- **Accento dallo sfondo (`yumi-accent`):** un colore d'accento preso dallo sfondo arriva tramite hook a Waybar, swaync,
  rofi, kitty, GTK/Qt, bordi delle finestre, VS Code e Telegram.
- **Nuova schermata di blocco "Yumi Google":** `hyprlock-google-build` la genera da un template per ogni monitor —
  orologio, citazioni, lettore, info di sistema. Il layout precedente (`layout20.conf`) c'è ancora.
- **Pillole e centro di controllo:** Wi-Fi, Bluetooth, "non sospendere" (☕ ferma hypridle), pillola del lettore con
  copertina e popup `yumi-player`; centro di controllo con "Non disturbare", "non sospendere" e mouse.
- **Inoltre:** promemoria del calendario (timer systemd), tray senza applet doppie, tema Telegram nei colori dello
  sfondo, launcher inutili nascosti (`yumi-app-hide`), `SUPER+K` cambia layout su tutte le tastiere insieme e la
  schermata di blocco si apre sempre con il layout inglese. Ogni aggiunta ha il proprio script `*-uninstall`.
</details>

### Funzionalità

- **Barra nello stile “Inchiostro”:** a sinistra il sigillo, gli spazi di lavoro in kanji, CPU e memoria; al centro il
  lettore con la copertina e un equalizzatore cava a quadratini; a destra centro di controllo, layout della tastiera,
  VPN (solo quando è attiva), “resta sveglio”, Wi-Fi con il nome della rete, Bluetooth con il numero di dispositivi,
  audio, orologio, batteria e spegnimento. Le pillole si aggiornano sugli eventi D-Bus (`yumi-bar-events`), non a
  intervalli.
- **Menu in QML:** un unico framework, un menu aperto alla volta, navigazione da tastiera, si chiudono con `Esc` o con
  un clic fuori.
- **Notifiche:** popup e un centro notifiche — un elenco con `↑` `↓`, `Enter`, `Del`, `H` per nascondere un'app, `D`
  per “Non disturbare”, “Cancella” con una seconda pressione.
- **OSD** per volume, microfono, luminosità, retroilluminazione della tastiera, layout e “resta sveglio”.
- **Schermata di blocco “Rotolo”:** `yumi-lock` blocca tramite Quickshell; se non risponde in circa 2 s, subentra
  hyprlock. All'avvio il desktop viene disegnato *sotto* il blocco.
- **Schermata di accesso:** greetd + sway + la stessa schermata QML; una copia del tema vive in `/var/lib/yumi-greeter`
  e segue lo sfondo (`yumi-greeter-sync`).
- **Tutto segue lo sfondo:** `yumi-colors` e gli hook in `~/.config/yumi/accent/hooks.d` ricolorano la shell, kitty,
  GTK/Qt, i bordi delle finestre, VS Code, Zen, Telegram, Vesktop, Obsidian, le icone delle cartelle, la
  retroilluminazione della tastiera e la schermata di accesso.
- **Musica:** `yumi-music` — YouTube Music + SoundCloud con copertine, playlist e testi; `yumi-airpods` mette in pausa
  quando si toglie un auricolare.
- **Vivere con 8 GB:** zram grande quanto la RAM + un file di swap; earlyoom chiude prima le schede del browser e mai
  il desktop; Zen gira in un cgroup suo (`zen.slice`); `lim 1G <comando>` avvia i server di prova in `dev.slice` con un
  limite di memoria.
- **Sistema:** avvio silenzioso, snapshot btrfs con snapper (gruppo facoltativo: snap-pac prima e dopo ogni pacman),
  faillock, BlueZ Experimental per la batteria delle cuffie.
- **Due monitor su un MacBook M1:** lo schermo esterno funziona via USB-C in DisplayPort alt mode grazie a
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Gli spazi 1–5 stanno sul MacBook, 6–10 sul monitor
  esterno; scollegandolo passano al portatile.
- **Logitech senza G HUB** (facoltativo): un menu del mouse con DPI e frequenza di polling (Solaar); la
  retroilluminazione della tastiera segue l'accento della barra tramite un server OpenRGB.
- **Extra per MacBook** (moduli facoltativi): livelli e stili della Touch Bar
  ([touchbard](https://github.com/0800tim/touchbard)), limite di carica, una guardia che riaccende lo schermo integrato
  dopo il coperchio, Touch ID per sudo e la schermata di blocco ([yumi-touchid](https://github.com/sonoyumi/yumi-touchid),
  si installa a parte).
- **Ogni modifica si può annullare:** `./install.sh --uninstall` rimette i backup, `./rice push` conserva la versione
  precedente di ogni file, e le aggiunte si annullano con `yumi-uninstall <modulo>`.

### Screenshot

La galleria completa è [nella sezione inglese](#screenshots): schermata di blocco e di accesso, barra, finestra della
password, centro di controllo, notifiche, Pult, musica, tutti i menu, widget degli sfondi, due monitor.

### Tasti e gesti

| Tasti | Azione |
|---|---|
| `SUPER` + `Space` | Pult: app, comandi, file, calcolatrice, emoji, web |
| `SUPER` + `A` / `SUPER` + `SHIFT` + `E` | App / file |
| `SUPER` + `C` | Centro di controllo — collegamenti a tutti i menu |
| `SUPER` + `CTRL` + `W` / `B` / `V` / `A` | Wi-Fi / Bluetooth / VPN / audio |
| `SUPER` + `CTRL` + `E` / `T` / `Y` | Batteria e alimentazione / processi / tray |
| `SUPER` + `CTRL` + `C` / `N` / `K` | Calendario / centro notifiche / scorciatoie |
| `SUPER` + `Esc`, `SUPER` + `Delete`, `CTRL` + `ALT` + `Del` | Anello della sessione: blocca, sospendi, esci, riavvia, spegni |
| `SUPER` + `N` | Blocca lo schermo |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Lettore / musica |
| `SUPER` + `V` | Appunti |
| `SUPER` + `TAB` | Spazi di lavoro |
| `SUPER` + `` ` `` | Menu di sistema |
| `SUPER` + `,` / `SUPER` + `.` | Emoji / glifi |
| `SUPER` + `SHIFT` + `/` | Ricerca web |
| `SUPER` + `SHIFT` + `W` | Widget degli sfondi |
| `SUPER` + `ALT` + `←` / `→` | Sfondo precedente / successivo |
| `SUPER` + `ALT` + `↑` / `↓` | Modalità di lavoro successiva / precedente |
| `SUPER` + `K` | Layout su tutte le tastiere |
| `SUPER` + `P` / `ALT` + `P` / `SHIFT` + `P`, `Print` | Screenshot: area / schermo congelato / monitor / tutti i monitor |
| `SUPER` + `ALT` + `Space` / `,` / `.` | Play-pausa / brano precedente / successivo |
| `ALT` + `F9`…`F12`, `ALT` + `Print` / `Scroll Lock` / `Pause` | Media e volume sulla tastiera esterna |
| 3 dita ← / → | Cambia spazio di lavoro |
| 3 dita ↓ | Panoramica degli spazi |
| 4 dita | Fuoco sulla finestra nella direzione dello scorrimento |

### Installazione

> [!WARNING]
> **Solo Arch Linux e Arch Linux ARM.** Provato su un MacBook Pro M1 (Asahi); su altro hardware Arch non è ancora stato
> provato: segnala i problemi. I file di sistema in `/etc` (GRUB, zram, earlyoom, Bluetooth) vengono dalla mia
> macchina: l'installer chiede per ognuno, e se non sei sicuro rispondi “no”.

```zsh
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./install.sh --dry-run   # mostra cosa verrebbe fatto, senza cambiare nulla
./install.sh             # installa: una domanda prima di ogni passo, prima un backup
```

L'installer mette i pacchetti di `packages/` (AUR tramite `paru` o `yay`, gruppi facoltativi su richiesta), copia i
file con `./rice push`, configura la schermata di accesso greetd, i servizi utente e la finestra della password. Poi
metti qualche immagine in `~/Pictures/Wallpapers`, riavvia ed esegui `yumi-doctor`. Monitor:
`~/.config/yumi/monitors.conf` (nomi delle uscite da `hyprctl monitors`); avatar della schermata di blocco:
`~/.config/hypr/hyprlock/avatar.jpg`.

Annullare: `./install.sh --uninstall` — rimette i file dai backup, spegne i servizi e greetd e ripristina il gestore di
accesso precedente. I pacchetti si rimuovono solo con un consenso a parte.

Passo per passo, con tutte le domande e i limiti noti: [INSTALL.md](INSTALL.md) (per ora in russo).

### Lo script `rice`

Il repository è la fonte di verità; `rice` lo sincronizza con il sistema.

| Comando | Cosa fa |
|---|---|
| `./rice pull` | Sistema → repository |
| `./rice diff [percorso]` | Cosa differisce tra sistema e repository |
| `./rice push` | Repository → `~` (con backup delle versioni precedenti) |
| `./rice push-system [filtro]` | Repository → `/etc` (diff e conferma per ogni file, prima uno snapshot snapper) |
| `./rice files` | Quali file installa `push` (tiene conto di `RICE_LOCAL` e `RICE_MAC`) |
| `./rice reload` | Ricarica Hyprland, Quickshell, systemd --user |
| `./rice add <percorso>` | Inizia a tracciare un file |
| `./rice doctor` | `yumi-doctor` più i dettagli del repository: servizi, crash, deriva, file fuori dal manifest |
| `./rice check` | Controllo del repository prima del commit: sintassi, dati privati, segreti (`--install-hook` lo esegue a ogni commit) |
| `./rice gc [--apply]` | Pulizia: `__pycache__`, vecchi archivi `rice-bak`, `.bak` e rollback da `~/.local/bin` nell'archivio (senza `--apply` mostra soltanto) |
| `./rice drift [--notify [N]]` | Quanto il sistema si è allontanato dal repository (notifica oltre N blocchi) |

Le modifiche personali stanno fuori dal repository in `~/.config/rice-local/` (stessa struttura di `home/`, più un suo
`manifest.txt`): `./rice` le installa al posto dei file pubblici, così le modifiche private non arrivano mai su GitHub.
I blocchi privati dentro un file condiviso sono marcati `yumi:private-begin/-end` e li toglie `tools/publicize`.
`RICE_LOCAL=off ./rice push` installa la versione pubblica pulita; `RICE_MAC=off` salta il blocco Mac del manifest.

Flusso: modifica in `home/…` → `./rice push` → `./rice reload` → controlla → `git commit`.
Non ti piace — `git checkout -- <file>` e di nuovo `./rice push`.

### Struttura del progetto

```
yumi-rice/
├── install.sh              # installer (Arch / Arch ARM): --dry-run, --uninstall
├── INSTALL.md              # installazione passo per passo
├── packages/               # arch.txt, aur.txt, optional.txt (gruppi), mac.txt
├── home/
│   ├── .config/quickshell/yumi/  # la shell: barra, menu, notifiche, osd, lock, polkit, greeter.qml
│   ├── .config/hypr/       # hyprland.lua + yumi/ (moduli, modalità di lavoro), hypridle, hyprlock di riserva
│   ├── .config/yumi/       # monitors.conf, hook d'accento, modelli dei colori, schermata di accesso (greeter/sway.conf)
│   ├── .config/systemd/    # servizi e timer yumi-*, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # comandi yumi-*: blocco, sfondi, colori, musica, doctor, greeter…
│   ├── .local/lib/yumi/    # qs (backend dei menu), bar (script della barra), colors, tray, calendar, fetch…
│   └── .local/share/       # tema VS Code, aiuti per la musica, icone delle cartelle, dati del picker
├── system/etc/             # greetd + PAM, GRUB, zram, sysctl, earlyoom, BlueZ, faillock
├── patches/                # patch ai sorgenti: Hyprland, awww (vedi patches/README.md)
├── assets/screenshots/
├── manifest.txt            # file tracciati da ~ (la parte Mac tra # @mac e # @end)
├── system-manifest.txt     # file tracciati da /etc
├── rice                    # script di sincronizzazione
├── NOTICE                  # autori e licenze di terze parti
└── tools/                  # publicize (copia pubblica dalla privata), check (controllo pre-commit)
```

### Insidie: Hyprland 0.56 Lua, Quickshell e Asahi

- Le opzioni usano i punti: `hyprctl getoption decoration.rounding`. I dispatcher sono Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` non funziona — usa `hyprctl eval 'hl.config({...})'`.
- La scala deve dividere la risoluzione: `1.666667`, non `1.67`.
- `Hyprland --verify-config` **esegue** i comandi `exec` della configurazione che controlla — controlla solo quella in
  uso, mai una copia.
- Quickshell: fermalo con `systemctl --user stop yumi-quickshell` o `qs kill -c yumi`, mai con `pkill qs` — uccide anche
  le istanze di prova. La sorveglianza dei file è spenta: le modifiche al QML si vedono solo dopo
  `systemctl --user restart yumi-quickshell`.
- Non avviare e chiudere la vera schermata di blocco per provarla: una conversazione PAM interrotta conta come password
  sbagliata per faillock (3 tentativi → 10 minuti, e si blocca anche sudo). Usa l'anteprima:
  `qs -c yumi ipc call lock preview`.
- greetd legge `/etc/greetd/config.toml` solo quando parte; `systemctl restart greetd` chiude la sessione in corso.
- `hypridle.conf` include **ogni** file in `hypridle/` — qualsiasi backup accanto alla configurazione la sovrascrive.
- GRUB non può scrivere `grubenv` su btrfs — niente `GRUB_SAVEDEFAULT`. L'ordine dei parametri conta: `quiet loglevel=3`.
- Asahi non ha MGLRU; power-profiles-daemon offre solo `balanced` e `power-saver`.
- Pagine da 16K: le immagini con jemalloc compilato per 4K vanno in crash — aiuta `muvm`. Quickshell invece funziona
  bene con le pagine da 16K.
- `MemoryHigh` senza swap libero congela il processo invece di chiuderlo — usa `MemoryMax`.
- AirPods con dual boot macOS: `br-connection-key-missing` → rimuovi e abbina di nuovo.
- Solaar riapplica all'avvio le zone LED salvate e può spegnere la retroilluminazione della tastiera: segna
  `led_control` e `led_zone_*` come `ignore` nella sua configurazione.
- La modalità `Direct` di OpenRGB sulla tastiera PRO perde tasti e l'ordine dei LED non corrisponde al layout: `Static`
  è affidabile.
- `openrgb` normale a ogni chiamata riscansiona per qualche secondo tutti i dispositivi USB, e intanto Solaar non
  riesce a leggere il mouse: avvia `openrgb --server` una volta all'accesso e invia i colori con `--client`.
- Un monitor collegato dopo l'accesso riceve uno sfondo nero: ridisegna lo sfondo sull'evento `monitor.added`.
- dp-altmode: dopo aver scollegato il monitor e sospeso il portatile, il collegamento successivo può fallire fino al
  riavvio (bug noto e aperto). Dopo un aggiornamento del kernel la patch va ricompilata.
- atuin: un `sync_address = ""` vuoto lo rompe — per restare in locale imposta `auto_sync = false` e non indicare
  l'indirizzo.

### Ringraziamenti

[Hyprland](https://hyprland.org/) · [Quickshell](https://quickshell.org/) · [Asahi Linux](https://asahilinux.org/) ·
[HyDE](https://github.com/HyDE-Project/HyDE) (la base delle versioni 1.0–2.5; `yumi-colors` è un port del suo wallbash) ·
[greetd](https://git.sr.ht/~kennylevinsen/greetd) · [sway](https://swaywm.org/) (schermata di accesso) ·
[touchbard](https://github.com/0800tim/touchbard) (Touch Bar) · [Zen](https://zen-browser.app/) ·
[starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) ·
[fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[dp-altmode](https://github.com/haripako/dp-altmode) di haripako (DisplayPort via USB-C su M1) ·
[Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/) ·
font Noto Serif, Noto Serif CJK JP, Inter, JetBrains Mono

### Autore

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)), sviluppatore Python: bot Telegram, web scraping, automazione.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Vuoi configurare un desktop Linux o automatizzare un lavoro ripetitivo con degli script? Scrivimi.

### Licenza

GPL-3.0-or-later, vedi [LICENSE](LICENSE). Le parti di terzi sono elencate in [NOTICE](NOTICE): wallbash da HyDE
(GPL-3.0), touchbard (MIT), font (SIL OFL 1.1, installati dai repository, non inclusi).
Le versioni fino alla 3.0 erano rilasciate con licenza MIT.

---

<a name="uk"></a>

## 🇺🇦 Українська

**[🇬🇧 English](#en)** · **[🇮🇹 Italiano](#it)** · **🇺🇦 Українська** · **[🇷🇺 Русский](#ru)**

Мій робочий стіл Hyprland на MacBook Pro M1 з Asahi Linux. Від версії 3.1 уся оболонка — панель, меню, сповіщення,
екранні індикатори, екран блокування, екран входу й вікно пароля — написана на QML у
[Quickshell](https://quickshell.org/), у стилі «Туш»: шрифти із засічками, японські підписи, червона печатка-ханко.
Усе бере кольори з поточних шпалер. А ще встановлювач для Arch Linux / Arch Linux ARM і скрипт, який тримає репозиторій
і систему синхронними та зберігає резервну копію кожного файлу, який змінює.

| | |
|---|---|
| Залізо | MacBook Pro 13" M1 (2020), 8 ГБ RAM, екран 2560×1600, масштаб 1.666667 · другий монітор MSI G27C3F 1920×1080 через USB-C · клавіатура Logitech PRO і миша PRO X 2 |
| ОС | Arch Linux ARM ([Asahi](https://asahilinux.org/)), ядро `linux-asahi`, сторінки пам'яті 16K, btrfs |
| Робочий стіл | Hyprland 0.56 з Lua-конфігом, власна основа `~/.config/hypr/yumi` |
| Панель / сповіщення / меню / OSD | Quickshell (QML) — одна служба, `yumi-quickshell` |
| Блокування / вхід / пароль | екран блокування Quickshell · greetd з екраном входу на Quickshell · агент polkit на Quickshell |
| Простій / шпалери | hypridle · awww |
| Термінал / оболонка / шрифт | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Шрифти оболонки | Noto Serif · Noto Serif CJK JP · JetBrains Mono Nerd Font · Inter |
| Браузер | [Zen](https://zen-browser.app/) (за бажанням) |

### Що нового у 3.1

> [!NOTE]
> **Перевірено на MacBook Pro M1 (Asahi).** Встановлювач написаний для будь-якої машини з Arch Linux / Arch Linux ARM,
> але на іншому залізі ще не випробуваний — це наступна перевірка. Якщо щось не працює, відкрийте issue.

**Стиль «Острів»**
- Суцільні капсули в кольорах шпалер на панелі, в усіх меню, на екрані блокування й на Touch Bar; печатка 弓 як знак
  системи.
- **Dynamic Island** посередині панелі: поточний трек, таймери й Pomodoro, завантаження, увімкнений мікрофон, зміни
  мережі та VPN, AirPods — одне місце для всього, що відбувається просто зараз (`yumi-island`).
- Нові меню: оновлення компактним віконцем, резервні копії (borg), швидкий перегляд, завантаження, YouTube.

**Світло клавіш MacBook** (`yumi-light`)
- Підсвітка клавіш стежить за датчиком освітлення: у темряві вмикається, на світлі гасне. У центрі керування є
  повзунок і перемикач «авто», на Touch Bar — свій повзунок.
- Клавіші «дихають», коли закінчилася фаза Pomodoro або сідає батарея. Ручне налаштування завжди головніше.

**Перевірка здоров'я та патчі**
- `yumi-doctor` тепер перевіряє ще й Touch Bar, Touch ID, закріплені пакети, екран входу, earlyoom і світло клавіш.
- Патчі до вихідного коду, на яких працює стіл (утримання першого кадру й клавіатура на екрані блокування для
  Hyprland, виправлення падіння awww), лежать у [`patches/`](patches/README.md).

**Уся оболонка на Quickshell**
- Панель, усі меню, спливні сповіщення й центр сповіщень, OSD (гучність, яскравість, підсвітка клавіатури, розкладка,
  «не засинати»), екран блокування та вікно пароля polkit / sudo — це QML у `~/.config/quickshell/yumi`, що
  запускається однією службою, `yumi-quickshell`. Логіка лишається в невеликих Python-бекендах
  (`~/.local/lib/yumi/qs`), які спілкуються JSON; QML лише малює.
- **Прибрано:** Waybar, swaync, rofi, GTK-меню та SDDM. hyprlock лишився тільки аварійним запасним — на випадок, якщо
  Quickshell не відповість.
- Кольори: шаблон `quickshell.dcol` → `~/.config/yumi/quickshell/colors.json`; оболонка перечитує його на льоту, тож
  нові шпалери перефарбовують усе без перезапуску.

**Стиль «Туш»**
- Шрифти із засічками (Noto Serif + Noto Serif CJK JP), тонкі риски замість капсул, червона печатка-ханко 弓, анімації
  без пружин.
- На панелі: робочі столи 一 二 三…, підписи 核 (процесор), 憶 (пам'ять), 電 (батарея), 護 (VPN); меню-картки,
  квадратна обкладинка в плеєрі.

**Блокування, вхід, пароль**
- **Екран блокування «Сувій»** з полем пароля **«Риска»**: одна лінія замість рамки.
- **Екран входу на greetd** замість SDDM — той самий вигляд, Quickshell усередині невеликого сеансу sway. Під час
  завантаження автовхід веде одразу в Hyprland і на екран блокування; після «Вийти» з'являється цей екран входу, а не
  чорний екран.
- **Вікно пароля** для polkit / sudo в тому ж стилі: `yumi-polkit-switch on|off|status` (`off` повертає
  hyprpolkitagent).

**Меню та шпалери**
- Меню: Пульт (`SUPER+Space`), Програми й файли, Музика, Система, Wi-Fi, Bluetooth, VPN, Звук, Батарея й режими
  живлення, Буфер обміну, Календар, Робочі столи, Процеси, Трей, Гарячі клавіші, Емодзі й гліфи, Пошук в інтернеті.
  Центр керування (`SUPER+C`) — вузол із посиланнями на всі меню.
- **Кільце сеансу** (`SUPER+Esc`, `SUPER+Delete`): блокування 鍵, сон 眠, вихід 出, перезавантаження 再, вимкнення 終 —
  утримання для підтвердження.
- **Музика** (`yumi-music`): YouTube Music + SoundCloud без облікового запису, плейлисти, черга, синхронний текст пісень.
- **Віджет шпалер** (`SUPER+SHIFT+W`): карусель, стилі (теки) → шпалери, гортання стрілками, попередній перегляд
  акцентного кольору під картинкою. Кольори всього робочого столу беруться зі шпалер (`yumi-colors`).

**Переносність**
- **`./install.sh`** — тільки Arch Linux / Arch Linux ARM: питання перед кожним кроком, спершу резервна копія,
  `--dry-run` і `--uninstall`. Списки пакетів у `packages/`: `arch.txt` (обов'язкові), `aur.txt`, `optional.txt`
  (групи, які можна пропустити), `mac.txt`.
- **Mac-частини — окремі модулі за бажанням** (`RICE_MAC`): Touch Bar, обмеження заряду батареї, захист після кришки,
  режим AirPods, заставка під час завантаження. Встановлюються тільки якщо знайдено MacBook. Touch ID — окремий
  публічний репозиторій: [yumi-touchid](https://github.com/sonoyumi/yumi-touchid).
- **Монітори:** вбудований екран — будь-який вихід з назвою `eDP*`; масштаби й назви — у
  `~/.config/yumi/monitors.conf` (порожній файл — нормально: усе отримує 1.0).
- **Ліцензія:** GPL-3.0-or-later замість MIT — рушій кольорів є портом wallbash із HyDE (GPL-3.0).
  Див. [NOTICE](NOTICE).

<details>
<summary><b>Попередні версії: 3.0 · 2.5 · 2.1 · 2.0</b></summary>

#### 3.0

Перший реліз на повністю власній основі, без HyDE: Hyprland модулями (`~/.config/hypr/yumi`), власний рушій кольорів
`yumi-colors`, Пульт (`SUPER+Space`), `yumi-doctor`, колекції шпалер, тема SDDM, Zen як браузер. Повний опис — на
[сторінці релізу 3.0](https://github.com/sonoyumi/yumi-rice/releases/tag/v3.0).

#### Що нового у 2.5

> [!NOTE]
> **Скоро 3.0 — велике оновлення.** Наступна версія переходить на повністю власну основу: свій конфіг Hyprland,
> юніти systemd, теми й скрипти, **без HyDE в основі**. 2.5 — останній випуск на HyDE.

**Нове**
- **AirPods у Linux** (служба `yumi-airpods`): якщо вийняти навушник — музика на паузі, натискання на ніжку працюють,
  а під час блокування ноутбука навушники повертаються на iPhone. Попіксельно намальовані значки AirPods у Waybar
  (шрифт `YumiIcons`, `build-font.py`).
- **Музика** (`yumi-music`, `SUPER+SHIFT+M`): медіатека YouTube Music + SoundCloud з обкладинками, плейлистами, чергою
  й пошуком. SoundCloud іде через окремий проксі WARP (`yumi-music-proxy`); щотижневі таймери оновлення й синхронізації.
- **Тексти пісень у плеєрі:** під карткою, з підсвічуванням рядків (YouTube Music → LRCLIB) і поправкою на затримку
  Bluetooth (`lyrics.conf`). Еквалайзер у пігулці плеєра — `yumi-eq`, CFFI-модуль Waybar на C.
- **Центр керування на GTK4** (`yumi-menu-control`): плитки, повзунки, картка плеєра, «Не турбувати» та журнал
  сповіщень (`yumi-notify-log`; службовий шум відсікає `ignore.json`).
- **VPN без ExpressVPN** (`yumi-vpn`): локації Cloudflare WARP і Proton Free як WireGuard-підключення NetworkManager —
  меню, пігулка у Waybar і плитка в центрі керування.
- **«Не засинати» всюди** (☕ `yumi-caffeine` + таймер-охоронець), екран блокування гасне, коли ☕ увімкнено
  (`yumi-idle-action`), обмеження заряду батареї (`yumi-battery-limit`).
- **Застосунки в кольорах шпалер** через хуки акценту: Zen, Firefox, Vesktop, вікна hyprtoolkit, Touch Bar; значки
  тек перефарбовуються в палітру (`recolor.py`, `yumi-folders-update`).

**Чистіше**
- `~/.local/bin`: 155 → ~90 файлів. 39 скриптів `*-uninstall`, 27 копій `.bak` і 17 тек бекапів перенесено до
  `~/.local/share/yumi-archive`. Одна команда для всіх відкатів: `yumi-uninstall` (список) і `yumi-uninstall <модуль>` —
  вона повертає бекапи на місце на час відкату, а потім знову архівує.
- Звільнено близько 4 ГБ кешів (збірки AUR, інсталятор HyDE, cargo, pip).
- Виправлення: плитка VPN у центрі керування досі викликала ExpressVPN; перевірка музичного проксі писала в журнал
  двічі на секунду (тепер результат пам'ятається 30 с).

**`rice`**
- `./rice drift` — наскільки система відійшла від репозиторію; щоденний таймер (`yumi-rice-drift`) нагадує, що час
  зробити `pull`.
- `./rice doctor` — усі служби yumi, падіння за добу, файли `.bak` у PATH, файли поза маніфестом.
- `./rice gc` — переносить до архіву також `.bak` і відкати з `~/.local/bin`.
- `./rice push-system` — робить знімок snapper перед першою зміною в `/etc`.

#### Що нового у 2.1

> [!IMPORTANT]
> **Зібрано й перевірено лише на моїй машині:** MacBook Pro M1 (2560×1600, масштаб 1.666667) + MSI G27C3F
> (1920×1080 @ 180 Гц, масштаб 1). У версіях 2.0–2.1 багато підгонки саме під ці два монітори та їхні масштаби — розміри
> меню й rofi, шрифти екрана блокування для кожного монітора, висоти панелей. Я не знаю, як збірка поведеться на
> іншій конфігурації: використовуйте її як приклад і підлаштовуйте під своє залізо. З 2.1 назви моніторів,
> масштаб інтерфейсу й DPI rofi зібрані в одному файлі `~/.config/yumi/monitors.conf` (монітор, якого там немає, отримує 1.0); значення для окремих моніторів лишилися тільки в `yumi-panel/style.css`, `waybar/user-style.css` і шаблоні екрана блокування.
> Версія 1.0 (меню rofi, теми HyDE) лишається доступною: [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0).
>
> **Далі:** я ще перевірятиму оптимізацію та функціональність і за потреби вноситиму правки. Найближчими днями додам скриншоти екрана блокування та ще дві речі, які вже зроблені, але поки не опубліковані.

Виміряно на моїй машині (MacBook Pro M1, 8 ГБ, відкриті Firefox, Telegram і термінали).

**Простіше**
- **Монітори в одному файлі.** `~/.config/yumi/monitors.conf` містить для кожного виходу масштаб інтерфейсу, DPI rofi
  й назву (плюс розмір і масштаб для збирання екрана блокування, коли монітор від'єднано). Його читають меню
  (`yumipanel.py` через `yumimon.py`), `yumi-player`, `yumi-menu-workspaces`, `hyprlock-google-build`, `rofi` і
  `rofi-panel` — раніше ці значення були прописані в шести скриптах. Монітор, якого немає у файлі, отримує 1.0, тож на
  іншій машині все працює без правок. Значення для окремих моніторів лишилися тільки в CSS і шаблоні екрана блокування.
- **Публічне й особисте в одному файлі.** Особисті блоки позначені `yumi:private-begin/-end`, окремі рядки —
  `yumi:private-line`, рядки лише для публічної версії — `yumi:public:`. `./rice pull` сам збирає публічну копію
  (`tools/publicize`): більше не треба тримати дві версії вручну.
- **Старі меню rofi прибрано** — 13 файлів (вони є у [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)); `menu-workflows`, `rofi-panel` і `player-cover`
  лишилися. З `hyde-patches.sh` прибрано дві правки, які тепер робить сам `hyprland.lua`.
- **Нові команди `rice`:** `./rice check` — синтаксис кожного файлу, особисті шляхи, секрети, забуті мітки, посилання на
  скрипти, яких немає в репозиторії; `--install-hook` запускає її перед кожним комітом. `./rice gc` — прибирання
  `__pycache__` і старих бекапів (спершу показує, видаляє з `--apply`). `./rice doctor` тепер показує ще служби yumi,
  збійні юніти, лічильник faillock, помилки Waybar і тиск на пам'ять.

**Легше**

| | 2.0 | 2.1 |
|---|---|---|
| Запуски скриптів Waybar | ~100 за хвилину, 12,4 % ядра | ~12 за хвилину, 1,4 % |
| Пігулка Wi-Fi / Bluetooth / VPN після зміни в меню | до 5 с | одразу |
| Пігулка миші | ~1,7 с (Solaar), без DPI | 40 мс (ядро, `hidpp_battery`), з DPI |
| `nm-applet` + значок blueman | ~48 МБ | вимкнено |

- **Пігулки за подіями:** служба `yumi-bar-events` (~9 МБ) слухає NetworkManager, BlueZ і power-profiles-daemon через
  D-Bus і подає сигнал Waybar; таймери лишилися тільки як страховка (30–120 с).
- **Миша:** заряд і зарядка — з ядра; DPI й частота — з кешу, який Solaar оновлює не частіше ніж раз на 30 хвилин (меню
  миші очищає його після зміни). `blueman-applet` лишається агентом сполучення (вікно PIN).
- **Пам'ять чесно:** GTK-меню займає ~60 МБ, поки відкрите (меню rofi — ~12 МБ), і звільняє їх після закриття; у фоні
  вся оболонка (Waybar, swaync, трей, Solaar…) — ~170 МБ, приблизно 2 % від 8 ГБ.

#### Що нового у 2.0

- **Меню на GTK4 замість rofi на панелі (`yumi-panel`):** один каркас (`~/.local/lib/yumi-panel`) — вікно layer-shell
  з розмиттям, кольорами шпалер і керуванням з клавіатури. Меню: Wi-Fi, Bluetooth, звук, VPN (ExpressVPN / Tailscale),
  живлення й режими HyDE, сеанс, система (оновлення, знімки btrfs, ресурси), процеси, миша (DPI, частота), календар
  з нагадуваннями, буфер обміну, вибір шпалер, робочі столи, трей. Старі меню rofi прибрано у 2.1 (вони є у [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)).
- **Акцент зі шпалер (`yumi-accent`):** один акцентний колір береться зі шпалер і через хуки потрапляє у Waybar,
  swaync, rofi, kitty, GTK/Qt, рамки вікон, VS Code і Telegram.
- **Новий екран блокування «Yumi Google»:** `hyprlock-google-build` збирає його з шаблону для кожного монітора —
  годинник, цитати, плеєр, відомості про систему. Попередня розкладка (`layout20.conf`) теж на місці.
- **Пігулки й центр керування:** Wi-Fi, Bluetooth, «не засинати» (☕ зупиняє hypridle), пігулка плеєра з обкладинкою
  та спливний `yumi-player`; у центрі керування — «Не турбувати», «не засинати» й миша.
- **А ще:** нагадування календаря (таймер systemd), трей без дубльованих аплетів, тема Telegram у кольорах шпалер,
  приховані зайві ярлики (`yumi-app-hide`), `SUPER+K` перемикає розкладку одразу на всіх клавіатурах, а екран
  блокування завжди відкривається з англійською розкладкою. Кожне доповнення має власний скрипт `*-uninstall`.
</details>

### Можливості

- **Панель у стилі «Туш»:** ліворуч — печатка, робочі столи ієрогліфами, процесор і пам'ять; по центру — плеєр з
  обкладинкою та еквалайзер cava з квадратиків; праворуч — центр керування, розкладка, VPN (тільки коли увімкнений),
  «не засинати», Wi-Fi з назвою мережі, Bluetooth із числом пристроїв, звук, годинник, батарея та вимкнення. Пігулки
  оновлюються за подіями D-Bus (`yumi-bar-events`), а не опитуванням.
- **Меню на QML:** одна основа, відкрите лише одне меню, керування з клавіатури, закриваються по `Esc` або кліку поза
  вікном.
- **Сповіщення:** спливні вікна й центр сповіщень — список із `↑` `↓`, `Enter`, `Del`, `H` — сховати програму, `D` —
  «Не турбувати», «Очистити» — другим натисканням.
- **OSD** для гучності, мікрофона, яскравості, підсвітки клавіатури, розкладки й «не засинати».
- **Екран блокування «Сувій»:** `yumi-lock` блокує через Quickshell; якщо той не відповів приблизно за 2 с,
  підхоплює hyprlock. Під час завантаження робочий стіл малюється *під* блокуванням.
- **Екран входу:** greetd + sway + той самий QML-екран; копія теми живе в `/var/lib/yumi-greeter` і йде за шпалерами
  (`yumi-greeter-sync`).
- **Усе йде за шпалерами:** `yumi-colors` і хуки в `~/.config/yumi/accent/hooks.d` перефарбовують оболонку, kitty,
  GTK/Qt, рамки вікон, VS Code, Zen, Telegram, Vesktop, Obsidian, значки тек, підсвітку клавіатури та екран входу.
- **Музика:** `yumi-music` — YouTube Music + SoundCloud з обкладинками, плейлистами й текстами пісень; `yumi-airpods`
  ставить на паузу, коли виймаєш навушник.
- **Життя на 8 ГБ:** zram розміром з RAM + swap-файл; earlyoom першими закриває вкладки браузера і ніколи — робочий
  стіл; Zen працює у власній cgroup (`zen.slice`); `lim 1G <команда>` запускає тестові сервери в `dev.slice` з лімітом
  пам'яті.
- **Система:** тихе завантаження, знімки btrfs через snapper (група за бажанням: snap-pac до і після кожного pacman),
  faillock, BlueZ Experimental для заряду навушників.
- **Два монітори на MacBook M1:** зовнішній екран працює через USB-C у режимі DisplayPort alt mode завдяки
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Столи 1–5 — на MacBook, 6–10 — на зовнішньому
  моніторі; відключиш його — вони переїдуть на ноутбук.
- **Logitech без G HUB** (за бажанням): меню миші з DPI і частотою опитування (Solaar); підсвітка клавіатури йде за
  акцентом панелі через сервер OpenRGB.
- **Додатки для MacBook** (модулі за бажанням): шари й стилі Touch Bar
  ([touchbard](https://github.com/0800tim/touchbard)), обмеження заряду, захист, що повертає вбудований екран після
  кришки, Touch ID для sudo та екрана блокування ([yumi-touchid](https://github.com/sonoyumi/yumi-touchid),
  встановлюється окремо).
- **Будь-яку зміну можна скасувати:** `./install.sh --uninstall` повертає резервні копії, `./rice push` зберігає
  попередню версію кожного файлу, а доповнення відкочуються командою `yumi-uninstall <модуль>`.

### Скриншоти

Уся галерея — [в англійському розділі](#screenshots): екран блокування та входу, панель, вікно пароля, центр
керування, сповіщення, Пульт, музика, усі меню, віджет шпалер, два монітори.

### Клавіші й жести

| Клавіші | Дія |
|---|---|
| `SUPER` + `Space` | Пульт: програми, команди, файли, калькулятор, емодзі, інтернет |
| `SUPER` + `A` / `SUPER` + `SHIFT` + `E` | Програми / файли |
| `SUPER` + `C` | Центр керування — посилання на всі меню |
| `SUPER` + `CTRL` + `W` / `B` / `V` / `A` | Wi-Fi / Bluetooth / VPN / звук |
| `SUPER` + `CTRL` + `E` / `T` / `Y` | Батарея й живлення / процеси / трей |
| `SUPER` + `CTRL` + `C` / `N` / `K` | Календар / центр сповіщень / гарячі клавіші |
| `SUPER` + `Esc`, `SUPER` + `Delete`, `CTRL` + `ALT` + `Del` | Кільце сеансу: блокування, сон, вихід, перезавантаження, вимкнення |
| `SUPER` + `N` | Заблокувати екран |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Плеєр / музика |
| `SUPER` + `V` | Буфер обміну |
| `SUPER` + `TAB` | Робочі столи |
| `SUPER` + `` ` `` | Меню «Система» |
| `SUPER` + `,` / `SUPER` + `.` | Емодзі / гліфи |
| `SUPER` + `SHIFT` + `/` | Пошук в інтернеті |
| `SUPER` + `SHIFT` + `W` | Віджет шпалер |
| `SUPER` + `ALT` + `←` / `→` | Попередні / наступні шпалери |
| `SUPER` + `ALT` + `↑` / `↓` | Наступний / попередній робочий режим |
| `SUPER` + `K` | Розкладка на всіх клавіатурах |
| `SUPER` + `P` / `ALT` + `P` / `SHIFT` + `P`, `Print` | Знімок: область / заморожений екран / монітор / усі монітори |
| `SUPER` + `ALT` + `Space` / `,` / `.` | Пуск-пауза / попередній / наступний трек |
| `ALT` + `F9`…`F12`, `ALT` + `Print` / `Scroll Lock` / `Pause` | Медіа та гучність на зовнішній клавіатурі |
| 3 пальці ← / → | Перемкнути робочий стіл |
| 3 пальці ↓ | Огляд робочих столів |
| 4 пальці | Фокус на вікно в напрямку свайпу |

### Встановлення

> [!WARNING]
> **Тільки Arch Linux і Arch Linux ARM.** Перевірено на MacBook Pro M1 (Asahi); на іншому залізі з Arch ще не
> випробувано — повідомляйте про проблеми. Системні файли в `/etc` (GRUB, zram, earlyoom, Bluetooth) — з моєї машини:
> встановлювач питає про кожен, і якщо не впевнені — відповідайте «ні».

```zsh
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./install.sh --dry-run   # показати, що буде зроблено, нічого не змінюючи
./install.sh             # встановлення: питання перед кожним кроком, спершу резервна копія
```

Встановлювач ставить пакети з `packages/` (AUR через `paru` або `yay`, необов'язкові групи — на запит), копіює файли
через `./rice push`, налаштовує екран входу greetd, служби користувача й вікно пароля. Далі покладіть кілька картинок у
`~/Pictures/Wallpapers`, перезавантажтеся й запустіть `yumi-doctor`. Монітори: `~/.config/yumi/monitors.conf` (назви
виходів — з `hyprctl monitors`); аватар екрана блокування: `~/.config/hypr/hyprlock/avatar.jpg`.

Відкат: `./install.sh --uninstall` — повертає файли з резервних копій, вимикає служби та greetd і повертає попередній
менеджер входу. Пакети видаляються тільки за окремою згодою.

Покроково, з усіма питаннями й відомими обмеженнями: [INSTALL.md](INSTALL.md) (поки що російською).

### Скрипт `rice`

Репозиторій — джерело істини; `rice` синхронізує його із системою.

| Команда | Що робить |
|---|---|
| `./rice pull` | Система → репозиторій |
| `./rice diff [шлях]` | Чим система відрізняється від репозиторію |
| `./rice push` | Репозиторій → `~` (зберігає попередні версії) |
| `./rice push-system [фільтр]` | Репозиторій → `/etc` (diff і підтвердження для кожного файлу, спершу знімок snapper) |
| `./rice files` | Які файли ставить `push` (з урахуванням `RICE_LOCAL` і `RICE_MAC`) |
| `./rice reload` | Перечитати Hyprland, Quickshell, systemd --user |
| `./rice add <шлях>` | Почати відстежувати файл |
| `./rice doctor` | `yumi-doctor` плюс подробиці репозиторію: служби, збої, розбіжності, файли поза маніфестом |
| `./rice check` | Перевірка репозиторію перед комітом: синтаксис, особисті дані, секрети (`--install-hook` — на кожен коміт) |
| `./rice gc [--apply]` | Прибирання: `__pycache__`, старі архіви `rice-bak`, `.bak` і відкати з `~/.local/bin` в архів (без `--apply` лише показує) |
| `./rice drift [--notify [N]]` | Наскільки система відійшла від репозиторію (сповіщення, якщо блоків більше N) |

Особисті правки живуть поза репозиторієм у `~/.config/rice-local/` (та сама структура, що й `home/`, плюс власний
`manifest.txt`): `./rice` ставить їх замість публічних файлів, тож приватні зміни ніколи не потрапляють на GitHub.
Приватні блоки всередині спільного файлу позначені `yumi:private-begin/-end`, їх вирізає `tools/publicize`.
`RICE_LOCAL=off ./rice push` ставить чисту публічну версію; `RICE_MAC=off` пропускає Mac-блок маніфесту.

Порядок роботи: правка в `home/…` → `./rice push` → `./rice reload` → перевірка → `git commit`.
Не сподобалось — `git checkout -- <файл>` і знову `./rice push`.

### Структура проєкту

```
yumi-rice/
├── install.sh              # встановлювач (Arch / Arch ARM): --dry-run, --uninstall
├── INSTALL.md              # встановлення крок за кроком
├── packages/               # arch.txt, aur.txt, optional.txt (групи), mac.txt
├── home/
│   ├── .config/quickshell/yumi/  # оболонка: панель, меню, сповіщення, osd, lock, polkit, greeter.qml
│   ├── .config/hypr/       # hyprland.lua + yumi/ (модулі, робочі режими), hypridle, запасний hyprlock
│   ├── .config/yumi/       # monitors.conf, хуки акценту, шаблони кольорів, екран входу (greeter/sway.conf)
│   ├── .config/systemd/    # служби й таймери yumi-*, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # команди yumi-*: блокування, шпалери, кольори, музика, doctor, greeter…
│   ├── .local/lib/yumi/    # qs (бекенди меню), bar (скрипти панелі), colors, tray, calendar, fetch…
│   └── .local/share/       # тема VS Code, помічники музики, значки тек, дані пікера
├── system/etc/             # greetd + PAM, GRUB, zram, sysctl, earlyoom, BlueZ, faillock
├── patches/                # патчі до вихідного коду: Hyprland, awww (див. patches/README.md)
├── assets/screenshots/
├── manifest.txt            # відстежувані файли з ~ (Mac-частина між # @mac і # @end)
├── system-manifest.txt     # відстежувані файли з /etc
├── rice                    # скрипт синхронізації
├── NOTICE                  # автори й ліцензії сторонніх частин
└── tools/                  # publicize (публічна копія з приватної), check (перевірка перед комітом)
```

### Підводні камені: Hyprland 0.56 Lua, Quickshell та Asahi

- Опції через крапку: `hyprctl getoption decoration.rounding`. Диспетчери — на Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` не працює — використовуйте `hyprctl eval 'hl.config({...})'`.
- Масштаб має ділити роздільність: `1.666667`, а не `1.67`.
- `Hyprland --verify-config` **виконує** команди `exec` з конфігу, який перевіряє, — перевіряйте лише робочий конфіг,
  не копію.
- Quickshell: зупиняйте через `systemctl --user stop yumi-quickshell` або `qs kill -c yumi`, ніколи `pkill qs` — він
  уб'є й тестові екземпляри. Стеження за файлами вимкнене: правки QML видно лише після
  `systemctl --user restart yumi-quickshell`.
- Не запускайте й не закривайте справжній екран блокування для перевірки: перервана розмова PAM для faillock — це
  неправильний пароль (3 спроби → 10 хвилин, і sudo теж блокується). Є попередній перегляд:
  `qs -c yumi ipc call lock preview`.
- greetd читає `/etc/greetd/config.toml` лише під час свого запуску; `systemctl restart greetd` завершує поточний сеанс.
- `hypridle.conf` підключає **кожен** файл у `hypridle/` — будь-яка резервна копія поруч перебиває ваш конфіг.
- GRUB не вміє писати `grubenv` на btrfs — без `GRUB_SAVEDEFAULT`. Порядок параметрів важливий: `quiet loglevel=3`.
- В Asahi немає MGLRU; power-profiles-daemon дає лише `balanced` і `power-saver`.
- Сторінки 16K: образи з jemalloc, зібраним під 4K, падають — допомагає `muvm`. Сам Quickshell на сторінках 16K
  працює нормально.
- `MemoryHigh` без вільного свопу заморожує процес замість того, щоб його закрити, — використовуйте `MemoryMax`.
- AirPods при подвійному завантаженні з macOS: `br-connection-key-missing` → видалити й спарувати знову.
- Solaar під час запуску знову застосовує збережені LED-зони й може вимкнути підсвітку клавіатури: позначте
  `led_control` і `led_zone_*` як `ignore` у його конфігу.
- Режим `Direct` в OpenRGB на клавіатурі PRO губить клавіші, а порядок світлодіодів не збігається з розкладкою:
  надійний `Static`.
- Звичайний `openrgb` за кожного виклику кілька секунд опитує всі USB-пристрої, і в цей час Solaar не може прочитати
  мишу: запускайте `openrgb --server` один раз під час входу, а колір надсилайте через `--client`.
- Монітор, підключений після входу, отримує чорне тло: перемальовуйте шпалери за подією `monitor.added`.
- dp-altmode: якщо відключити монітор і приспати ноутбук, наступне підключення може не спрацювати до перезавантаження
  (відомий відкритий баг). Після оновлення ядра патч треба перезібрати.
- atuin: порожній `sync_address = ""` ламає його — щоб усе було локально, ставте `auto_sync = false` і не вказуйте
  адресу.

### Подяки

[Hyprland](https://hyprland.org/) · [Quickshell](https://quickshell.org/) · [Asahi Linux](https://asahilinux.org/) ·
[HyDE](https://github.com/HyDE-Project/HyDE) (основа версій 1.0–2.5; `yumi-colors` — порт його wallbash) ·
[greetd](https://git.sr.ht/~kennylevinsen/greetd) · [sway](https://swaywm.org/) (екран входу) ·
[touchbard](https://github.com/0800tim/touchbard) (Touch Bar) · [Zen](https://zen-browser.app/) ·
[starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) ·
[fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[dp-altmode](https://github.com/haripako/dp-altmode) від haripako (DisplayPort через USB-C на M1) ·
[Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/) ·
шрифти Noto Serif, Noto Serif CJK JP, Inter, JetBrains Mono

### Автор

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)) — Python-розробник: Telegram-боти, парсинг, автоматизація.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Потрібно налаштувати робочий стіл Linux або автоматизувати рутину скриптами? Напишіть мені.

### Ліцензія

GPL-3.0-or-later — див. [LICENSE](LICENSE). Сторонні частини перелічені в [NOTICE](NOTICE): wallbash із HyDE
(GPL-3.0), touchbard (MIT), шрифти (SIL OFL 1.1, ставляться з репозиторіїв, у комплект не входять).
Версії до 3.0 включно виходили під ліцензією MIT.

---

<a name="ru"></a>

## 🇷🇺 Русский

**[🇬🇧 English](#en)** · **[🇮🇹 Italiano](#it)** · **[🇺🇦 Українська](#uk)** · **🇷🇺 Русский**

Мой рабочий стол Hyprland на MacBook Pro M1 с Asahi Linux. С версии 3.1 вся оболочка — бар, меню, уведомления,
экранные индикаторы, экран блокировки, экран входа и окно пароля — написана на QML в
[Quickshell](https://quickshell.org/), в стиле «Тушь»: шрифты с засечками, японские подписи, красная печать-ханко.
Всё берёт цвета из текущих обоев. А ещё установщик для Arch Linux / Arch Linux ARM и скрипт, который держит
репозиторий и систему синхронными и сохраняет резервную копию каждого файла, который меняет.

| | |
|---|---|
| Железо | MacBook Pro 13" M1 (2020), 8 ГБ RAM, экран 2560×1600, масштаб 1.666667 · второй монитор MSI G27C3F 1920×1080 через USB-C · клавиатура Logitech PRO и мышь PRO X 2 |
| ОС | Arch Linux ARM ([Asahi](https://asahilinux.org/)), ядро `linux-asahi`, страницы памяти 16K, btrfs |
| Рабочий стол | Hyprland 0.56 с Lua-конфигом, своя основа `~/.config/hypr/yumi` |
| Бар / уведомления / меню / OSD | Quickshell (QML) — одна служба, `yumi-quickshell` |
| Блокировка / вход / пароль | экран блокировки Quickshell · greetd с экраном входа на Quickshell · агент polkit на Quickshell |
| Простой / обои | hypridle · awww |
| Терминал / оболочка / шрифт | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Шрифты оболочки | Noto Serif · Noto Serif CJK JP · JetBrains Mono Nerd Font · Inter |
| Браузер | [Zen](https://zen-browser.app/) (по желанию) |

### Что нового в 3.1

> [!NOTE]
> **Проверено на MacBook Pro M1 (Asahi).** Установщик написан для любой машины с Arch Linux / Arch Linux ARM, но на
> другом железе ещё не опробован — это следующая проверка. Если что-то не работает, откройте issue.

**Стиль «Остров»**
- Сплошные капсулы в цветах обоев на баре, во всех меню, на экране блокировки и на Touch Bar; печать 弓 как знак
  системы.
- **Dynamic Island** посередине бара: текущий трек, таймеры и Pomodoro, загрузки, включённый микрофон, смена сети
  и VPN, AirPods — одно место для всего, что происходит прямо сейчас (`yumi-island`).
- Новые меню: обновления компактным окошком, резервные копии (borg), быстрый просмотр, загрузки, YouTube.

**Свет клавиш MacBook** (`yumi-light`)
- Подсветка клавиш следит за датчиком освещённости: в темноте включается, на свету гаснет. В центре управления есть
  ползунок и переключатель «авто», на Touch Bar — свой ползунок.
- Клавиши «дышат», когда закончилась фаза Pomodoro или садится батарея. Ручная настройка всегда главнее.

**Проверка здоровья и патчи**
- `yumi-doctor` теперь проверяет ещё и Touch Bar, Touch ID, закреплённые пакеты, экран входа, earlyoom и свет клавиш.
- Патчи к исходному коду, на которых работает стол (удержание первого кадра и клавиатура на экране блокировки для
  Hyprland, исправление падения awww), лежат в [`patches/`](patches/README.md).

**Вся оболочка на Quickshell**
- Бар, все меню, всплывающие уведомления и центр уведомлений, OSD (громкость, яркость, подсветка клавиатуры,
  раскладка, «не засыпать»), экран блокировки и окно пароля polkit / sudo — это QML в `~/.config/quickshell/yumi`,
  который запускается одной службой, `yumi-quickshell`. Логика остаётся в небольших Python-бэкендах
  (`~/.local/lib/yumi/qs`), которые общаются JSON; QML только рисует.
- **Убраны:** Waybar, swaync, rofi, GTK-меню и SDDM. hyprlock остался только аварийным запасным — на случай, если
  Quickshell не ответит.
- Цвета: шаблон `quickshell.dcol` → `~/.config/yumi/quickshell/colors.json`; оболочка перечитывает его на лету, так что
  новые обои перекрашивают всё без перезапуска.

**Стиль «Тушь»**
- Шрифты с засечками (Noto Serif + Noto Serif CJK JP), тонкие черты вместо капсул, красная печать-ханко 弓, анимации
  без пружин.
- В баре: рабочие столы 一 二 三…, подписи 核 (процессор), 憶 (память), 電 (батарея), 護 (VPN); меню-карточки,
  квадратная обложка в плеере.

**Блокировка, вход, пароль**
- **Экран блокировки «Свиток»** с полем пароля **«Черта»**: одна линия вместо рамки.
- **Экран входа на greetd** вместо SDDM — тот же вид, Quickshell внутри небольшого сеанса sway. При загрузке автовход
  ведёт сразу в Hyprland и на экран блокировки; после «Выйти» появляется этот экран входа, а не чёрный экран.
- **Окно пароля** для polkit / sudo в том же стиле: `yumi-polkit-switch on|off|status` (`off` возвращает
  hyprpolkitagent).

**Меню и обои**
- Меню: Пульт (`SUPER+Space`), Программы и файлы, Музыка, Система, Wi-Fi, Bluetooth, VPN, Звук, Батарея и режимы
  питания, Буфер обмена, Календарь, Рабочие столы, Процессы, Трей, Горячие клавиши, Эмодзи и глифы, Поиск в интернете.
  Центр управления (`SUPER+C`) — узел со ссылками на все меню.
- **Кольцо сеанса** (`SUPER+Esc`, `SUPER+Delete`): блокировка 鍵, сон 眠, выход 出, перезагрузка 再, выключение 終 —
  удержание для подтверждения.
- **Музыка** (`yumi-music`): YouTube Music + SoundCloud без учётной записи, плейлисты, очередь, синхронный текст песен.
- **Виджет обоев** (`SUPER+SHIFT+W`): карусель, стили (папки) → обои, листание стрелками, предпросмотр акцентного
  цвета под картинкой. Цвета всего рабочего стола берутся из обоев (`yumi-colors`).

**Переносимость**
- **`./install.sh`** — только Arch Linux / Arch Linux ARM: вопрос перед каждым шагом, сначала резервная копия,
  `--dry-run` и `--uninstall`. Списки пакетов в `packages/`: `arch.txt` (обязательные), `aur.txt`, `optional.txt`
  (группы, которые можно пропустить), `mac.txt`.
- **Mac-части — отдельные модули по желанию** (`RICE_MAC`): Touch Bar, ограничение заряда батареи, защита после
  крышки, режим AirPods, заставка при загрузке. Ставятся, только если найден MacBook. Touch ID — отдельный публичный
  репозиторий: [yumi-touchid](https://github.com/sonoyumi/yumi-touchid).
- **Мониторы:** встроенный экран — любой выход с именем `eDP*`; масштабы и названия — в `~/.config/yumi/monitors.conf`
  (пустой файл — нормально: всё получает 1.0).
- **Лицензия:** GPL-3.0-or-later вместо MIT — движок цветов является портом wallbash из HyDE (GPL-3.0).
  См. [NOTICE](NOTICE).

<details>
<summary><b>Прошлые версии: 3.0 · 2.5 · 2.1 · 2.0</b></summary>

#### 3.0

Первый релиз на полностью своей основе, без HyDE: Hyprland модулями (`~/.config/hypr/yumi`), свой движок цветов
`yumi-colors`, Пульт (`SUPER+Space`), `yumi-doctor`, коллекции обоев, тема SDDM, Zen как браузер. Полное описание — на
[странице релиза 3.0](https://github.com/sonoyumi/yumi-rice/releases/tag/v3.0).

#### Что нового в 2.5

> [!NOTE]
> **Скоро 3.0 — крупное обновление.** Следующая версия переходит на полностью свою основу: свой конфиг Hyprland,
> юниты systemd, темы и скрипты, **без HyDE в основе**. 2.5 — последний выпуск на HyDE.

**Новое**
- **AirPods в Linux** (служба `yumi-airpods`): вынул наушник — музыка на паузе, нажатия на ножку работают, а при
  блокировке ноутбука наушники уходят обратно на iPhone. Попиксельно нарисованные значки AirPods в Waybar
  (шрифт `YumiIcons`, `build-font.py`).
- **Музыка** (`yumi-music`, `SUPER+SHIFT+M`): медиатека YouTube Music + SoundCloud с обложками, плейлистами, очередью
  и поиском. SoundCloud идёт через отдельный прокси WARP (`yumi-music-proxy`); еженедельные таймеры обновления и синхронизации.
- **Тексты песен в плеере:** под карточкой, с подсветкой строк (YouTube Music → LRCLIB) и поправкой на задержку
  Bluetooth (`lyrics.conf`). Эквалайзер в пилюле плеера — `yumi-eq`, CFFI-модуль Waybar на C.
- **Центр управления на GTK4** (`yumi-menu-control`): плитки, ползунки, карточка плеера, «Не беспокоить» и журнал
  уведомлений (`yumi-notify-log`; служебный шум отсекает `ignore.json`).
- **VPN без ExpressVPN** (`yumi-vpn`): локации Cloudflare WARP и Proton Free как WireGuard-подключения NetworkManager —
  меню, пилюля в Waybar и плитка в центре управления.
- **«Не засыпать» везде** (☕ `yumi-caffeine` + таймер-сторож), экран блокировки гаснет при включённом ☕
  (`yumi-idle-action`), ограничение заряда батареи (`yumi-battery-limit`).
- **Приложения в цветах обоев** через хуки акцента: Zen, Firefox, Vesktop, окна hyprtoolkit, Touch Bar; значки папок
  перекрашиваются в палитру (`recolor.py`, `yumi-folders-update`).

**Чище**
- `~/.local/bin`: 155 → ~90 файлов. 39 скриптов `*-uninstall`, 27 копий `.bak` и 17 папок бэкапов переехали в
  `~/.local/share/yumi-archive`. Одна команда для всех откатов: `yumi-uninstall` (список) и `yumi-uninstall <модуль>` —
  она возвращает бэкапы на место на время отката и потом снова убирает в архив.
- Освобождено около 4 ГБ кэшей (сборки AUR, установщик HyDE, cargo, pip).
- Исправления: плитка VPN в центре управления всё ещё вызывала ExpressVPN; проверка музыкального прокси писала в журнал
  дважды в секунду (теперь результат помнится 30 с).

**`rice`**
- `./rice drift` — насколько система ушла от репозитория; ежедневный таймер (`yumi-rice-drift`) напоминает, что пора
  сделать `pull`.
- `./rice doctor` — все службы yumi, падения за сутки, файлы `.bak` в PATH, файлы вне манифеста.
- `./rice gc` — переносит в архив ещё и `.bak` и откаты из `~/.local/bin`.
- `./rice push-system` — делает снимок snapper перед первой правкой в `/etc`.

#### Что нового в 2.1

> [!IMPORTANT]
> **Собрано и проверено только на моей машине:** MacBook Pro M1 (2560×1600, масштаб 1.666667) + MSI G27C3F
> (1920×1080 @ 180 Гц, масштаб 1). В версиях 2.0–2.1 много подгонки именно под эти два монитора и их масштабы — размеры
> меню и rofi, шрифты экрана блокировки для каждого монитора, высоты панелей. Я не знаю, как сборка поведёт себя на
> другой конфигурации: используйте её как пример и подстраивайте под своё железо. С 2.1 имена мониторов,
> масштаб интерфейса и DPI rofi собраны в одном файле `~/.config/yumi/monitors.conf` (монитор, которого там нет, получает 1.0); значения для отдельных мониторов остались только в `yumi-panel/style.css`, `waybar/user-style.css` и шаблоне экрана блокировки.
> Версия 1.0 (меню rofi, темы HyDE) остаётся доступной: [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0).
>
> **Дальше:** я ещё проверю оптимизацию и функциональность и при необходимости внесу правки. В ближайшие дни добавлю скриншоты экрана блокировки и ещё две вещи, которые уже сделал, но пока не опубликовал.

Замерено на моей машине (MacBook Pro M1, 8 ГБ, открыты Firefox, Telegram и терминалы).

**Проще**
- **Мониторы в одном файле.** `~/.config/yumi/monitors.conf` хранит для каждого выхода масштаб интерфейса, DPI rofi и
  название (плюс размер и масштаб для сборки экрана блокировки, когда монитор отключён). Его читают меню
  (`yumipanel.py` через `yumimon.py`), `yumi-player`, `yumi-menu-workspaces`, `hyprlock-google-build`, `rofi` и
  `rofi-panel` — раньше эти значения были прописаны в шести скриптах. Монитор, которого нет в файле, получает 1.0, так
  что на другой машине всё работает без правок. Значения для отдельных мониторов остались только в CSS и шаблоне экрана
  блокировки.
- **Публичное и личное в одном файле.** Личные блоки помечены `yumi:private-begin/-end`, отдельные строки —
  `yumi:private-line`, строки только для публичной версии — `yumi:public:`. `./rice pull` сам собирает публичную копию
  (`tools/publicize`): больше не нужно вести две версии вручную.
- **Старые меню rofi убраны** — 13 файлов (они есть в [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)); `menu-workflows`, `rofi-panel` и `player-cover`
  остались. Из `hyde-patches.sh` убраны две правки, которые теперь делает сам `hyprland.lua`.
- **Новые команды `rice`:** `./rice check` — синтаксис каждого файла, личные пути, секреты, забытые метки, ссылки на
  скрипты, которых нет в репозитории; `--install-hook` запускает её перед каждым коммитом. `./rice gc` — уборка
  `__pycache__` и старых бэкапов (сначала показывает, удаляет с `--apply`). `./rice doctor` теперь показывает ещё службы
  yumi, упавшие юниты, счётчик faillock, ошибки Waybar и давление на память.

**Легче**

| | 2.0 | 2.1 |
|---|---|---|
| Запуски скриптов Waybar | ~100 в минуту, 12,4 % ядра | ~12 в минуту, 1,4 % |
| Пилюля Wi-Fi / Bluetooth / VPN после изменения в меню | до 5 с | сразу |
| Пилюля мыши | ~1,7 с (Solaar), без DPI | 40 мс (ядро, `hidpp_battery`), с DPI |
| `nm-applet` + значок blueman | ~48 МБ | отключены |

- **Пилюли по событиям:** служба `yumi-bar-events` (~9 МБ) слушает NetworkManager, BlueZ и power-profiles-daemon через
  D-Bus и подаёт сигнал Waybar; таймеры остались только как страховка (30–120 с).
- **Мышь:** заряд и зарядка — из ядра; DPI и частота — из кеша, который Solaar обновляет не чаще раза в 30 минут (меню
  мыши очищает его после изменения). `blueman-applet` остаётся агентом сопряжения (окно PIN).
- **Память честно:** GTK-меню занимает ~60 МБ, пока открыто (меню rofi — ~12 МБ), и освобождает их при закрытии; в фоне
  вся оболочка (Waybar, swaync, трей, Solaar…) — ~170 МБ, примерно 2 % от 8 ГБ.

#### Что нового в 2.0

- **Меню на GTK4 вместо rofi на панели (`yumi-panel`):** один каркас (`~/.local/lib/yumi-panel`) — окно layer-shell
  с размытием, цветами обоев и управлением с клавиатуры. Меню: Wi-Fi, Bluetooth, звук, VPN (ExpressVPN / Tailscale),
  питание и режимы HyDE, сеанс, система (обновления, снимки btrfs, ресурсы), процессы, мышь (DPI, частота), календарь
  с напоминаниями, буфер обмена, выбор обоев, рабочие столы, трей. Старые меню rofi убраны в 2.1 (они есть в [`v1.0`](https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0)).
- **Акцент из обоев (`yumi-accent`):** один акцентный цвет берётся из обоев и через хуки попадает в Waybar, swaync,
  rofi, kitty, GTK/Qt, рамки окон, VS Code и Telegram.
- **Новый экран блокировки «Yumi Google»:** `hyprlock-google-build` собирает его из шаблона для каждого монитора —
  часы, цитаты, плеер, сведения о системе. Прежняя раскладка (`layout20.conf`) тоже на месте.
- **Пилюли и центр управления:** Wi-Fi, Bluetooth, «не засыпать» (☕ останавливает hypridle), пилюля плеера с обложкой
  и всплывающий `yumi-player`; в центре управления — «Не беспокоить», «не засыпать» и мышь.
- **А ещё:** напоминания календаря (таймер systemd), трей без дублирующихся апплетов, тема Telegram в цветах обоев,
  скрытие лишних ярлыков (`yumi-app-hide`), `SUPER+K` переключает раскладку сразу на всех клавиатурах, а экран
  блокировки всегда открывается с английской раскладкой. У каждой доработки свой скрипт `*-uninstall`.
</details>

### Возможности

- **Бар в стиле «Тушь»:** слева — печать, рабочие столы иероглифами, процессор и память; в центре — плеер с обложкой
  и эквалайзер cava из квадратиков; справа — центр управления, раскладка, VPN (только когда включён), «не засыпать»,
  Wi-Fi с именем сети, Bluetooth с числом устройств, звук, часы, батарея и выключение. Пилюли обновляются по событиям
  D-Bus (`yumi-bar-events`), а не опросом.
- **Меню на QML:** одна основа, открыто только одно меню, управление с клавиатуры, закрываются по `Esc` или щелчку
  вне окна.
- **Уведомления:** всплывающие окна и центр уведомлений — список с `↑` `↓`, `Enter`, `Del`, `H` — скрыть программу,
  `D` — «Не беспокоить», «Очистить» — вторым нажатием.
- **OSD** для громкости, микрофона, яркости, подсветки клавиатуры, раскладки и «не засыпать».
- **Экран блокировки «Свиток»:** `yumi-lock` блокирует через Quickshell; если тот не ответил примерно за 2 с,
  подхватывает hyprlock. При загрузке рабочий стол рисуется *под* блокировкой.
- **Экран входа:** greetd + sway + тот же QML-экран; копия темы живёт в `/var/lib/yumi-greeter` и следует за обоями
  (`yumi-greeter-sync`).
- **Всё следует за обоями:** `yumi-colors` и хуки в `~/.config/yumi/accent/hooks.d` перекрашивают оболочку, kitty,
  GTK/Qt, рамки окон, VS Code, Zen, Telegram, Vesktop, Obsidian, значки папок, подсветку клавиатуры и экран входа.
- **Музыка:** `yumi-music` — YouTube Music + SoundCloud с обложками, плейлистами и текстами песен; `yumi-airpods`
  ставит на паузу, когда вынимаешь наушник.
- **Жизнь на 8 ГБ:** zram размером с RAM + swap-файл; earlyoom первыми закрывает вкладки браузера и никогда — рабочий
  стол; Zen работает в своей cgroup (`zen.slice`); `lim 1G <команда>` запускает тестовые серверы в `dev.slice` с
  лимитом памяти.
- **Система:** тихая загрузка, снимки btrfs через snapper (группа по желанию: snap-pac до и после каждого pacman),
  faillock, BlueZ Experimental для заряда наушников.
- **Два монитора на MacBook M1:** внешний экран работает через USB-C в режиме DisplayPort alt mode благодаря
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Столы 1–5 — на MacBook, 6–10 — на внешнем мониторе;
  отключишь его — они переедут на ноутбук.
- **Logitech без G HUB** (по желанию): меню мыши с DPI и частотой опроса (Solaar); подсветка клавиатуры следует за
  акцентом бара через сервер OpenRGB.
- **Дополнения для MacBook** (модули по желанию): слои и стили Touch Bar
  ([touchbard](https://github.com/0800tim/touchbard)), ограничение заряда, защита, которая возвращает встроенный экран
  после крышки, Touch ID для sudo и экрана блокировки ([yumi-touchid](https://github.com/sonoyumi/yumi-touchid),
  ставится отдельно).
- **Любое изменение можно отменить:** `./install.sh --uninstall` возвращает резервные копии, `./rice push` хранит
  прежнюю версию каждого файла, а дополнения откатываются командой `yumi-uninstall <модуль>`.

### Скриншоты

Вся галерея — [в английском разделе](#screenshots): экран блокировки и входа, бар, окно пароля, центр управления,
уведомления, Пульт, музыка, все меню, виджет обоев, два монитора.

### Клавиши и жесты

| Клавиши | Действие |
|---|---|
| `SUPER` + `Space` | Пульт: программы, команды, файлы, калькулятор, эмодзи, интернет |
| `SUPER` + `A` / `SUPER` + `SHIFT` + `E` | Программы / файлы |
| `SUPER` + `C` | Центр управления — ссылки на все меню |
| `SUPER` + `CTRL` + `W` / `B` / `V` / `A` | Wi-Fi / Bluetooth / VPN / звук |
| `SUPER` + `CTRL` + `E` / `T` / `Y` | Батарея и питание / процессы / трей |
| `SUPER` + `CTRL` + `C` / `N` / `K` | Календарь / центр уведомлений / горячие клавиши |
| `SUPER` + `Esc`, `SUPER` + `Delete`, `CTRL` + `ALT` + `Del` | Кольцо сеанса: блокировка, сон, выход, перезагрузка, выключение |
| `SUPER` + `N` | Заблокировать экран |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Плеер / музыка |
| `SUPER` + `V` | Буфер обмена |
| `SUPER` + `TAB` | Рабочие столы |
| `SUPER` + `` ` `` | Меню «Система» |
| `SUPER` + `,` / `SUPER` + `.` | Эмодзи / глифы |
| `SUPER` + `SHIFT` + `/` | Поиск в интернете |
| `SUPER` + `SHIFT` + `W` | Виджет обоев |
| `SUPER` + `ALT` + `←` / `→` | Предыдущие / следующие обои |
| `SUPER` + `ALT` + `↑` / `↓` | Следующий / предыдущий рабочий режим |
| `SUPER` + `K` | Раскладка на всех клавиатурах |
| `SUPER` + `P` / `ALT` + `P` / `SHIFT` + `P`, `Print` | Снимок: область / замороженный экран / монитор / все мониторы |
| `SUPER` + `ALT` + `Space` / `,` / `.` | Пуск-пауза / предыдущий / следующий трек |
| `ALT` + `F9`…`F12`, `ALT` + `Print` / `Scroll Lock` / `Pause` | Медиа и громкость на внешней клавиатуре |
| 3 пальца ← / → | Переключить рабочий стол |
| 3 пальца ↓ | Обзор рабочих столов |
| 4 пальца | Фокус на окно в сторону свайпа |

### Установка

> [!WARNING]
> **Только Arch Linux и Arch Linux ARM.** Проверено на MacBook Pro M1 (Asahi); на другом железе с Arch ещё не
> опробовано — сообщайте о проблемах. Системные файлы в `/etc` (GRUB, zram, earlyoom, Bluetooth) — с моей машины:
> установщик спрашивает про каждый, и если не уверены — отвечайте «нет».

```zsh
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./install.sh --dry-run   # показать, что будет сделано, ничего не меняя
./install.sh             # установка: вопрос перед каждым шагом, сначала резервная копия
```

Установщик ставит пакеты из `packages/` (AUR через `paru` или `yay`, необязательные группы — по запросу), копирует
файлы через `./rice push`, настраивает экран входа greetd, службы пользователя и окно пароля. Дальше положите
несколько картинок в `~/Pictures/Wallpapers`, перезагрузитесь и запустите `yumi-doctor`. Мониторы:
`~/.config/yumi/monitors.conf` (имена выходов — из `hyprctl monitors`); аватар экрана блокировки:
`~/.config/hypr/hyprlock/avatar.jpg`.

Откат: `./install.sh --uninstall` — возвращает файлы из резервных копий, выключает службы и greetd и возвращает
прежний менеджер входа. Пакеты удаляются только по отдельному согласию.

По шагам, со всеми вопросами и известными ограничениями: [INSTALL.md](INSTALL.md).

### Скрипт `rice`

Репозиторий — источник истины; `rice` синхронизирует его с системой.

| Команда | Что делает |
|---|---|
| `./rice pull` | Система → репозиторий |
| `./rice diff [путь]` | Чем система отличается от репозитория |
| `./rice push` | Репозиторий → `~` (сохраняет прежние версии) |
| `./rice push-system [фильтр]` | Репозиторий → `/etc` (diff и подтверждение для каждого файла, сначала снимок snapper) |
| `./rice files` | Какие файлы ставит `push` (с учётом `RICE_LOCAL` и `RICE_MAC`) |
| `./rice reload` | Перечитать Hyprland, Quickshell, systemd --user |
| `./rice add <путь>` | Начать отслеживать файл |
| `./rice doctor` | `yumi-doctor` плюс подробности репозитория: службы, сбои, расхождения, файлы вне манифеста |
| `./rice check` | Проверка репозитория перед коммитом: синтаксис, личные данные, секреты (`--install-hook` — на каждый коммит) |
| `./rice gc [--apply]` | Уборка: `__pycache__`, старые архивы `rice-bak`, `.bak` и откаты из `~/.local/bin` в архив (без `--apply` только показывает) |
| `./rice drift [--notify [N]]` | Насколько система ушла от репозитория (уведомление, если блоков больше N) |

Личные правки живут вне репозитория в `~/.config/rice-local/` (та же структура, что и `home/`, плюс свой
`manifest.txt`): `./rice` ставит их вместо публичных файлов, так что приватные изменения никогда не попадают на GitHub.
Приватные блоки внутри общего файла помечены `yumi:private-begin/-end`, их вырезает `tools/publicize`.
`RICE_LOCAL=off ./rice push` ставит чистую публичную версию; `RICE_MAC=off` пропускает Mac-блок манифеста.

Порядок работы: правка в `home/…` → `./rice push` → `./rice reload` → проверка → `git commit`.
Не понравилось — `git checkout -- <файл>` и снова `./rice push`.

### Структура проекта

```
yumi-rice/
├── install.sh              # установщик (Arch / Arch ARM): --dry-run, --uninstall
├── INSTALL.md              # установка по шагам
├── packages/               # arch.txt, aur.txt, optional.txt (группы), mac.txt
├── home/
│   ├── .config/quickshell/yumi/  # оболочка: бар, меню, уведомления, osd, lock, polkit, greeter.qml
│   ├── .config/hypr/       # hyprland.lua + yumi/ (модули, рабочие режимы), hypridle, запасной hyprlock
│   ├── .config/yumi/       # monitors.conf, хуки акцента, шаблоны цветов, экран входа (greeter/sway.conf)
│   ├── .config/systemd/    # службы и таймеры yumi-*, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # команды yumi-*: блокировка, обои, цвета, музыка, doctor, greeter…
│   ├── .local/lib/yumi/    # qs (бэкенды меню), bar (скрипты бара), colors, tray, calendar, fetch…
│   └── .local/share/       # тема VS Code, помощники музыки, значки папок, данные пикера
├── system/etc/             # greetd + PAM, GRUB, zram, sysctl, earlyoom, BlueZ, faillock
├── patches/                # патчи к исходному коду: Hyprland, awww (см. patches/README.md)
├── assets/screenshots/
├── manifest.txt            # отслеживаемые файлы из ~ (Mac-часть между # @mac и # @end)
├── system-manifest.txt     # отслеживаемые файлы из /etc
├── rice                    # скрипт синхронизации
├── NOTICE                  # авторы и лицензии сторонних частей
└── tools/                  # publicize (публичная копия из личной), check (проверка перед коммитом)
```

### Грабли: Hyprland 0.56 Lua, Quickshell и Asahi

- Опции через точку: `hyprctl getoption decoration.rounding`. Диспетчеры — на Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` не работает — используйте `hyprctl eval 'hl.config({...})'`.
- Масштаб должен делить разрешение: `1.666667`, а не `1.67`.
- `Hyprland --verify-config` **выполняет** команды `exec` из проверяемого конфига — проверяйте только живой конфиг,
  не копию.
- Quickshell: останавливайте через `systemctl --user stop yumi-quickshell` или `qs kill -c yumi`, никогда `pkill qs` —
  он убьёт и тестовые экземпляры. Слежение за файлами выключено: правки QML видны только после
  `systemctl --user restart yumi-quickshell`.
- Не запускайте и не закрывайте настоящий экран блокировки для проверки: прерванный разговор PAM для faillock — это
  неверный пароль (3 попытки → 10 минут, и sudo тоже блокируется). Есть предпросмотр:
  `qs -c yumi ipc call lock preview`.
- greetd читает `/etc/greetd/config.toml` только при своём запуске; `systemctl restart greetd` завершает текущий сеанс.
- `hypridle.conf` подключает **каждый** файл в `hypridle/` — любая резервная копия рядом перебивает ваш конфиг.
- GRUB не умеет писать `grubenv` на btrfs — без `GRUB_SAVEDEFAULT`. Порядок параметров важен: `quiet loglevel=3`.
- В Asahi нет MGLRU; power-profiles-daemon даёт только `balanced` и `power-saver`.
- Страницы 16K: образы с jemalloc, собранным под 4K, падают — помогает `muvm`. Сам Quickshell на страницах 16K
  работает нормально.
- `MemoryHigh` без свободного свопа замораживает процесс вместо того, чтобы его закрыть, — используйте `MemoryMax`.
- AirPods при двойной загрузке с macOS: `br-connection-key-missing` → удалить и сопрячь заново.
- Solaar при запуске заново применяет сохранённые LED-зоны и может выключить подсветку клавиатуры: пометьте
  `led_control` и `led_zone_*` как `ignore` в его конфиге.
- Режим `Direct` в OpenRGB на клавиатуре PRO теряет клавиши, а порядок светодиодов не совпадает с раскладкой:
  надёжен `Static`.
- Обычный `openrgb` при каждом вызове несколько секунд опрашивает все USB-устройства, и в это время Solaar не может
  прочитать мышь: запускайте `openrgb --server` один раз при входе, а цвет отправляйте через `--client`.
- Монитор, подключённый после входа, получает чёрный фон: перерисовывайте обои по событию `monitor.added`.
- dp-altmode: если отключить монитор и усыпить ноутбук, следующее подключение может не сработать до перезагрузки
  (известный открытый баг). После обновления ядра патч нужно пересобрать.
- atuin: пустой `sync_address = ""` ломает его — чтобы всё было локально, ставьте `auto_sync = false` и не указывайте
  адрес.

### Благодарности

[Hyprland](https://hyprland.org/) · [Quickshell](https://quickshell.org/) · [Asahi Linux](https://asahilinux.org/) ·
[HyDE](https://github.com/HyDE-Project/HyDE) (основа версий 1.0–2.5; `yumi-colors` — порт его wallbash) ·
[greetd](https://git.sr.ht/~kennylevinsen/greetd) · [sway](https://swaywm.org/) (экран входа) ·
[touchbard](https://github.com/0800tim/touchbard) (Touch Bar) · [Zen](https://zen-browser.app/) ·
[starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) ·
[fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[dp-altmode](https://github.com/haripako/dp-altmode) от haripako (DisplayPort по USB-C на M1) ·
[Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/) ·
шрифты Noto Serif, Noto Serif CJK JP, Inter, JetBrains Mono

### Автор

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)) — Python-разработчик: Telegram-боты, парсинг, автоматизация.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Нужно настроить рабочий стол Linux или автоматизировать рутину скриптами? Напишите мне.

### Лицензия

GPL-3.0-or-later — см. [LICENSE](LICENSE). Сторонние части перечислены в [NOTICE](NOTICE): wallbash из HyDE
(GPL-3.0), touchbard (MIT), шрифты (SIL OFL 1.1, ставятся из репозиториев, в комплект не входят).
Версии до 3.0 включительно выходили под лицензией MIT.
