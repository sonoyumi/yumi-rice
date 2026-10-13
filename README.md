# 🍚 yumi-rice

<p>
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-0.56%20Lua-58E1FF?logo=hyprland&logoColor=white">
  <img alt="Asahi Linux" src="https://img.shields.io/badge/Asahi-Arch%20Linux%20ARM-1793D1?logo=archlinux&logoColor=white">
  <img alt="ARM64" src="https://img.shields.io/badge/aarch64-16K%20pages-f5a97f">
  <img alt="Version" src="https://img.shields.io/badge/version-3.0-ed8796">
  <img alt="Waybar" src="https://img.shields.io/badge/Waybar-swaync%20·%20GTK4-a6da95">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

**🇬🇧 [English](#en)** · **🇮🇹 [Italiano](#it)** · **🇺🇦 [Українська](#uk)** · **🇷🇺 [Русский](#ru)**

![Desktop](assets/screenshots/v3/desktop.jpg)

<p align="center"><b>3.0</b> — entirely my own base, without HyDE: pult, doctor, wallpaper collections, SDDM theme<br><a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v2.5">2.5</a> — AirPods, music with lyrics, GTK4 control center · <a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v2.1">2.1</a> — lighter: events instead of polling, monitors in one file · <a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v2.0">2.0</a> — GTK4 menus, accent from the wallpaper, new lock screen · <a href="https://github.com/sonoyumi/yumi-rice/releases/tag/v1.0">1.0</a> — rofi menus, HyDE themes</p>

---

<a name="en"></a>

## 🇬🇧 English

My Hyprland desktop on a MacBook Pro M1 running Asahi Linux: Waybar made of "pills", menus on GTK4
with blur and wallpaper colors, a macOS-like control center, a Spotlight-style launcher, a lock screen with a music
player — and all of it recolors itself to match the current wallpaper. Since 3.0 it all runs on a base of my own,
without HyDE. Plus a sync script that keeps the repository and the system in step, with a backup of every file it touches.

| | |
|---|---|
| Hardware | MacBook Pro 13" M1 (2020), 8 GB RAM, 2560×1600 display, scale 1.666667 · second monitor MSI G27C3F 1920×1080 @ 180 Hz over USB-C · Logitech PRO keyboard and PRO X 2 mouse |
| OS | Arch Linux ARM ([Asahi](https://asahilinux.org/)), `linux-asahi` kernel, 16K memory pages, btrfs |
| Desktop | Hyprland 0.56 with the Lua config, my own base `~/.config/hypr/yumi` (no HyDE), started via uwsm |
| Bar / notifications / menus | Waybar · swaync · GTK4 (yumi-panel) |
| Lock / idle / wallpaper / login | hyprlock · hypridle · awww · SDDM with its own theme |
| Terminal / shell / font | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Browser | [Zen](https://zen-browser.app/) |

### What's new in 3.0

> [!NOTE]
> **No more HyDE.** 3.0 is the first release on a base that is entirely my own: everything HyDE used to do is now
> done by my own configs and scripts, and HyDE is uninstalled. It is still built for my machine — portability
> (other distros, ordinary x86 hardware, a one-command installer) is planned for **3.1**.

**My own base instead of HyDE**
- **Hyprland in modules:** `hyprland.lua` loads `~/.config/hypr/yumi/` — `env`, `look`, `layout`, `binds`, `rules`,
  `autostart`, `events` — plus work modes in `workflows/` (default, editing, gaming, powersaver, snappy) switched
  by `yumi-workflow`.
- **My own color engine** `yumi-colors`: templates in `~/.config/yumi/colors/templates` for Waybar, swaync, kitty,
  GTK, Qt/Kvantum, VS Code, Discord, cava, Obsidian, the keyboard backlight and the volume icons.
- **Waybar straight from the package** with my layout (a systemd drop-in), my own zsh setup (`conf.d/yumi`),
  my own package-manager wrapper for the `in` / `un` / `up` aliases.
- **One naming scheme:** every command is `yumi-*`, libraries live in `~/.local/lib/yumi/`, settings in
  `~/.config/yumi/`. `cc` is the C compiler again — the control center is now `yumi-cc`.

**New**
- **Pult** (`yumi-pult`, `SUPER+Space`) — a Spotlight/Raycast-style window: apps, Yumi commands, files (`fd`), a
  calculator, emoji and web search in one list with a preview on the right. It also finds words typed in the wrong
  keyboard layout.
- **Doctor** (`yumi-doctor`): 13 checks — services, timers, Hyprland config, broken links, wallpaper colors, Waybar
  memory, disk, updates, snapper snapshots, pacman lock — in plain words, with `--fix` and `--json`. Also a "Doctor"
  row in the System menu.
- **Wallpaper collections:** subfolders of `~/Pictures/Wallpapers` become collections with a preview, buttons in the
  wallpaper menu and `yumi-wallpaper collection NAME|off|get`. Copies are pre-scaled per monitor, the transition runs
  at each monitor's refresh rate, and Waybar recolors right before the transition, not after it.
- **Login screen:** my own SDDM theme `yumi`; its background follows the wallpaper (`yumi-sddm-sync`).
- **Terminal:** kitty with CaskaydiaCove Nerd Font Mono, a two-line starship prompt in the terminal palette, zoxide
  (`z` / `zi`), atuin on `Ctrl+R` (local only, no sync), eza aliases. fastfetch with a text logo (a bow and arrow),
  framed sections and a Japanese quote of the day with a translation.
- **Zen** is the default browser (Firefox removed), colored from the wallpaper (`yumi-zen-theme`), including its settings pages.
- **Also:** a fullscreen player (`yumi-player-full`) and a queue in the player, a devices page inside the control
  center, mouse and AirPods battery notifications, `yumi-update` with a 30-minute cache (Waybar no longer runs
  `checkupdates` every time), the Yumi-Folders icon theme, the VS Code theme as its own extension.

**`rice`**
- `./rice hyde-patches` and `hyde-patches.sh` are gone; `./rice reload` restarts Waybar through systemd;
  `./rice doctor` starts with `yumi-doctor`.
- The manifest is rebuilt for the new paths (~300 files); `./rice check` also checks `system/`.
- `system-manifest.txt`: the SDDM theme setting, the login-screen pointer and the Touch Bar icons (tiny-dfr).
- The 2.x rollback scripts are not part of 3.0 — they stay in [`v2.5`](https://github.com/sonoyumi/yumi-rice/releases/tag/v2.5).

<details>
<summary><b>Earlier versions: 2.5 · 2.1 · 2.0</b></summary>

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
- `ai` — a small local code helper (Qwen2.5-Coder 1.5B via Ollama).

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

- **Waybar of pills:** my own `yumi` layout, every group of modules is a separate rounded pill. Left: logo,
  workspaces, CPU / RAM. Center: the player with cover art and an equalizer. Right: control center and clipboard ·
  keyboard layout, VPN, keep-awake, Wi-Fi, Bluetooth, sound (with AirPods icons) · clock, battery, power profile and
  work mode · power button. Pills update on D-Bus events (`yumi-bar-events`), not by polling.
- **GTK4 menus (`yumi-panel`):** one framework — a layer-shell window with blur, wallpaper colors and keyboard
  navigation. Wi-Fi, Bluetooth, sound, VPN, power and work modes, session, system (updates, snapshots, resources,
  Doctor), processes, mouse, calendar with reminders, clipboard, wallpapers, workspaces, tray, music, apps, emoji and
  glyphs, web search.
- **Control center** (`yumi-menu-control`, GTK4): tiles, sliders, player card, devices, "Do not disturb" and notification
  history. swaync draws the popups.
- **Everything follows the wallpaper:** `yumi-colors` and the `yumi-accent` hooks recolor Waybar, the menus, swaync,
  kitty, GTK/Qt, window borders, VS Code, Telegram, Vesktop, Zen, the Touch Bar, folder icons, the lock screen and SDDM.
- **Lock screen "Yumi Google":** `yumi-hyprlock-build` builds it from a template for each monitor — clock, quotes,
  player, system info. SDDM autologin → Hyprland → hyprlock at once; the desktop is drawn *under* the lock.
- **Music:** `yumi-music` — YouTube Music + SoundCloud with covers, playlists and lyrics; the `yumi-airpods` service
  pauses when a bud comes out and hands the buds back to the iPhone on lock.
- **Living on 8 GB:** zram the size of RAM + a swap file; earlyoom closes browser tabs first and never the desktop;
  Zen runs in its own cgroup (`zen.slice`); `lim 1G <command>` runs test servers in `dev.slice` with a memory cap.
- **System:** silent boot (hidden GRUB menu, `quiet loglevel=3`), btrfs snapshots with snapper (snap-pac before and
  after every pacman run, `/home` every hour), faillock, BlueZ Experimental for headphone battery.
- **Two monitors on an M1 MacBook:** the external display runs over USB-C DisplayPort alt mode thanks to
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Workspaces 1–5 live on the MacBook, 6–10 on the
  external monitor; unplug it and they move to the laptop. Scales and names of the monitors are in one file,
  `~/.config/yumi/monitors.conf`.
- **Logitech without G HUB:** a mouse menu with DPI and polling rate (Solaar); the keyboard backlight follows the
  wallpaper through an OpenRGB server; Win and Alt are swapped only on the external keyboard; media keys on `ALT+F9–F12`.
- **Every change can be undone:** `./rice push` keeps the previous version of each file, `./rice push-system` applies
  `/etc` one file at a time after a snapper snapshot, and add-ons are rolled back with `yumi-uninstall <module>`.

### Screenshots

![Wallpaper change](assets/screenshots/v3/wallpaper-change.gif)
<p align="center">One new wallpaper — and everything recolors: Waybar, the terminal, VS Code, Telegram, window borders</p>

| | |
|:---:|:---:|
| ![Pult (SUPER+Space)](assets/screenshots/v3/pult.png) | ![Pult: commands, files, web](assets/screenshots/v3/pult-search.png) |
| Pult (SUPER+Space) | Pult: commands, files, web |
| ![Control center](assets/screenshots/v3/menu-control.png) | ![System menu with Doctor](assets/screenshots/v3/menu-system.png) |
| Control center | System menu with Doctor |
| ![Sound](assets/screenshots/v3/menu-sound.png) | ![Bluetooth](assets/screenshots/v3/menu-bluetooth.png) |
| Sound | Bluetooth |
| ![Wi-Fi](assets/screenshots/v3/menu-wifi.png) | ![VPN: WARP / Proton + Tailscale](assets/screenshots/v3/menu-vpn.png) |
| Wi-Fi | VPN: WARP / Proton + Tailscale |
| ![Calendar](assets/screenshots/v3/menu-calendar.png) | ![Clipboard](assets/screenshots/v3/menu-clipboard.png) |
| Calendar | Clipboard |
| ![Power and work modes](assets/screenshots/v3/menu-power.png) | ![Session](assets/screenshots/v3/menu-session.png) |
| Power and work modes | Session |
| ![Mouse](assets/screenshots/v3/menu-mouse.png) | ![Workspaces](assets/screenshots/v3/menu-workspaces.png) |
| Mouse | Workspaces |
| ![Apps](assets/screenshots/v3/menu-launcher.png) | ![Emoji and glyphs](assets/screenshots/v3/menu-picker.png) |
| Apps | Emoji and glyphs |
| ![Web search](assets/screenshots/v3/menu-websearch.png) | ![Tray](assets/screenshots/v3/menu-tray.png) |
| Web search | Tray |

![Wallpapers and collections](assets/screenshots/v3/menu-wallpaper.png)
<p align="center">Wallpaper picker with collections</p>

![Two monitors](assets/screenshots/v3/two-monitors.jpg)
<p align="center">MacBook (2560×1600) and MSI (1920×1080 @ 165 Hz) side by side</p>

![Login screen](assets/screenshots/v3/sddm.jpg)
<p align="center">Login screen: my own SDDM theme</p>

> Private data in the screenshots is blurred; VPN and clipboard show demo data.

<details>
<summary><b>2.5 and earlier</b></summary>
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
| `SUPER` + `Esc`, `CTRL` + `ALT` + `Del` | Session: lock, sleep, logout, reboot, power off |
| `SUPER` + `N` | Lock the screen |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Player / music library |
| `SUPER` + `V` | Clipboard |
| `SUPER` + `TAB` | Workspaces |
| `SUPER` + `` ` `` | System menu |
| `SUPER` + `A` | Apps |
| `SUPER` + `,` / `SUPER` + `.` | Emoji / glyphs |
| `SUPER` + `SHIFT` + `W` | Wallpaper picker |
| `SUPER` + `ALT` + `←` / `→` | Previous / next wallpaper |
| `SUPER` + `/` | Power and work modes |
| `SUPER` + `ALT` + `↑` / `↓` | Next / previous work mode |
| `SUPER` + `K` | Keyboard layout on all keyboards |
| `SUPER` + `F10` / `F11` / `F12`, `Print` | Screenshot: area / frozen screen / monitor / all monitors |
| `ALT` + `F9`…`F12`, `ALT` + `Print` / `Scroll Lock` / `Pause` | Media and volume on the external keyboard |
| 3 fingers ← / → | Switch workspaces |
| 3 fingers ↓ | Workspace overview |

### Quick start

> [!WARNING]
> These are the configs of **one specific machine**: MacBook M1, Asahi, a 2560×1600 display. HyDE is no longer
> needed. On other hardware use them as a base and borrow parts; an installer for other distros and ordinary hardware
> is planned for 3.1. Apply the system files (`system/`) only on purpose.

Hyprland ≥ 0.56 (Lua config) and the packages:

```bash
sudo pacman -S --needed hyprland hypridle hyprlock hyprsunset hyprpolkitagent hyprpicker uwsm \
    waybar swaync awww kitty zsh starship fastfetch zoxide atuin eza fd jq cliphist wl-clipboard \
    playerctl imagemagick inotify-tools bluez-utils power-profiles-daemon libnotify brightnessctl btop \
    gtk4 gtk4-layer-shell python-gobject python-dbus python-requests pacman-contrib yt-dlp mpv cava \
    grim slurp satty tesseract udiskie snapper snap-pac earlyoom zram-generator kvantum qt6ct \
    ttf-cascadia-code-nerd ttf-jetbrains-mono-nerd noto-fonts-cjk solaar openrgb python-ytmusicapi wireproxy
```

From the AUR: `zen-browser-bin`. zsh plugins: oh-my-zsh with
`zsh-autosuggestions` and `zsh-syntax-highlighting`.

```bash
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./rice diff            # see what will change
./rice push            # copy the files into ~ (old versions go to ~/.local/state/rice-bak/)
systemctl --user daemon-reload
systemctl --user enable --now yumi-awww.service yumi-wallpaper.service yumi-bar-events.service \
    yumi-tray.service yumi-notify-log.service yumi-hyprlock-bg.service yumi-calendar-remind.timer
$EDITOR ~/.config/yumi/monitors.conf   # your monitors: interface scale, name
yumi-wallpaper random  # pictures from ~/Pictures/Wallpapers (subfolders = collections); colors follow
yumi-hyprlock-build    # build the lock screen for the monitors from monitors.conf
yumi-doctor            # check that everything is in place
./rice reload
./rice push-system     # optional: /etc, one file at a time with confirmation
~/.local/share/yumi-sddm/install.sh   # optional: the SDDM theme (rollback: uninstall.sh next to it)
```

The repository stores `@HOME@` instead of the home path and `@USER@` in the autologin file — `./rice push`
fills in yours. Put your own avatar into `~/.config/hypr/hyprlock/avatar.jpg`.

### The `rice` script

The repository is the source of truth; `rice` syncs it with the system.

| Command | What it does |
|---|---|
| `./rice pull` | System → repository |
| `./rice diff [path]` | What differs between the system and the repository |
| `./rice push` | Repository → `~` (backs up the previous versions) |
| `./rice push-system` | Repository → `/etc` (diff and confirmation for every file, snapper snapshot first) |
| `./rice reload` | Reload Hyprland, Waybar, swaync, systemd --user |
| `./rice add <path>` | Start tracking a file |
| `./rice doctor` | `yumi-doctor` plus repository details: services, crashes, drift, files outside the manifest |
| `./rice check` | Repository check before a commit: syntax, private data, secrets (`--install-hook` runs it on every commit) |
| `./rice gc [--apply]` | Clean-up: `__pycache__`, old `rice-bak` archives, `.bak` and rollbacks from `~/.local/bin` into the archive (without `--apply` it only shows) |
| `./rice drift [--notify [N]]` | How far the system drifted from the repository (notification above N blocks) |

Personal tweaks live outside the repository in `~/.config/rice-local/` (same layout as `home/`, plus its own
`manifest.txt`): `./rice` installs them instead of the public files, so private changes never reach GitHub.
Private blocks inside a shared file are marked `yumi:private-begin/-end` and cut out by `tools/publicize`.
`RICE_LOCAL=off ./rice push` installs the clean public version.

Workflow: edit in `home/…` → `./rice push` → `./rice reload` → check → `git commit`.
Didn't like it — `git checkout -- <file>` and `./rice push` again.

### Project structure

```
yumi-rice/
├── home/
│   ├── .config/hypr/       # hyprland.lua + yumi/ (modules, work modes), hyprlock, hypridle
│   ├── .config/yumi/       # monitors.conf, accent hooks, color templates, menu and player styles
│   ├── .config/waybar/     # yumi.jsonc layout, modules and styles
│   ├── .config/swaync/     # control center layouts and popup style
│   ├── .config/systemd/    # yumi-* services and timers, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # yumi-* commands: menus, pult, doctor, wallpaper, colors, player…
│   ├── .local/lib/yumi/    # panel (GTK4 menus), bar (Waybar modules), colors, tray, calendar, fetch…
│   ├── .local/src/yumi-eq/ # Waybar CFFI equalizer (C)
│   └── .local/share/       # SDDM theme, VS Code theme, music helpers, picker data
├── system/etc/             # GRUB, SDDM, zram, sysctl, earlyoom, BlueZ, faillock, X11 pointer, tiny-dfr
├── assets/screenshots/
├── manifest.txt            # tracked files from ~
├── system-manifest.txt     # tracked files from /etc
├── rice                    # sync script
└── tools/                  # publicize (public copy from private), check (pre-commit check)
```

### Gotchas: Hyprland 0.56 Lua and Asahi

- Options use dots: `hyprctl getoption decoration.rounding`. Dispatchers are Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` doesn't work — use `hyprctl eval 'hl.config({...})'`.
- The scale must divide the resolution: `1.666667`, not `1.67`.
- Waybar's built-in `hyprland/language` doesn't work with Lua Hyprland — a custom module is needed.
- swaync runs commands without `XDG_RUNTIME_DIR` — `wpctl` returns 0; sliders need explicit `min_limit/max_limit`.
- hyprlock: `$BACKGROUND_PATH` is unreliable (use an absolute path), `onclick` only works with `hide_cursor = false`,
  `fadeOut, 0` removes the grey frame after boot.
- `hypridle.conf` sources **every** file in `hypridle/` — any backup next to your config overrides it.
- Some packages put an empty `[Autologin]` into `/etc/sddm.conf.d/` — name yours so it sorts last (`zz-…`).
- GRUB can't write `grubenv` on btrfs — no `GRUB_SAVEDEFAULT`. Parameter order matters: `quiet loglevel=3`.
- Asahi has no MGLRU; power-profiles-daemon offers only `balanced` and `power-saver`.
- 16K pages: images with jemalloc built for 4K crash — `muvm` helps.
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
- `Hyprland --verify-config` **runs** the `exec` commands of the config it checks — check only the live config, never a copy.
- atuin: an empty `sync_address = ""` breaks it — to stay local, set `auto_sync = false` and leave the address out.

### Credits

[HyDE](https://github.com/HyDE-Project/HyDE) (the base of versions 1.0–2.5; the wallbash color templates grew out of it) ·
[Hyprland](https://hyprland.org/) · [Asahi Linux](https://asahilinux.org/) ·
[Hyprlock-Dots](https://github.com/mahaveergurjar/Hyprlock-Dots) (lock screen layout) ·
[swaync](https://github.com/ErikReider/SwayNotificationCenter) · [Waybar](https://github.com/Alexays/Waybar) ·
[Zen](https://zen-browser.app/) · [starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) · [fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[rofi](https://github.com/davatorium/rofi) ·
[dp-altmode](https://github.com/haripako/dp-altmode) by haripako (USB-C DisplayPort on M1) · [Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/)

### Author

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)), Python developer: Telegram bots, web scraping, automation.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Need a Linux desktop set up or a routine automated with scripts? Get in touch.

### License

MIT, see [LICENSE](LICENSE).

---

<a name="it"></a>

## 🇮🇹 Italiano

**[🇬🇧 English](#en)** · **🇮🇹 Italiano** · **[🇺🇦 Українська](#uk)** · **[🇷🇺 Русский](#ru)**

Il mio desktop Hyprland su un MacBook Pro M1 con Asahi Linux: una Waybar fatta di "pillole", i menu in GTK4
con sfocatura e i colori dello sfondo, un centro di controllo in stile macOS, un launcher alla Spotlight, una schermata
di blocco con il lettore musicale — e tutto si ricolora in base allo sfondo attuale. Dalla 3.0 gira tutto su una base
mia, senza HyDE. In più, uno script che tiene allineati repository e sistema, con un backup di ogni file che tocca.

| | |
|---|---|
| Hardware | MacBook Pro 13" M1 (2020), 8 GB di RAM, schermo 2560×1600, scala 1.666667 · secondo monitor MSI G27C3F 1920×1080 @ 180 Hz via USB-C · tastiera Logitech PRO e mouse PRO X 2 |
| Sistema | Arch Linux ARM ([Asahi](https://asahilinux.org/)), kernel `linux-asahi`, pagine di memoria da 16K, btrfs |
| Desktop | Hyprland 0.56 con configurazione Lua, base mia `~/.config/hypr/yumi` (senza HyDE), avviato tramite uwsm |
| Barra / notifiche / menu | Waybar · swaync · GTK4 (yumi-panel) |
| Blocco / inattività / sfondo / accesso | hyprlock · hypridle · awww · SDDM con un tema mio |
| Terminale / shell / font | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Browser | [Zen](https://zen-browser.app/) |

### Novità della 3.0

> [!NOTE]
> **Niente più HyDE.** La 3.0 è la prima versione su una base interamente mia: tutto ciò che faceva HyDE ora lo fanno
> le mie configurazioni e i miei script, e HyDE è stato disinstallato. È ancora pensata per la mia macchina — la
> portabilità (altre distribuzioni, hardware x86 comune, installazione con un solo comando) è prevista per la **3.1**.

**Una base mia al posto di HyDE**
- **Hyprland a moduli:** `hyprland.lua` carica `~/.config/hypr/yumi/` — `env`, `look`, `layout`, `binds`, `rules`,
  `autostart`, `events` — più le modalità di lavoro in `workflows/` (default, editing, gaming, powersaver, snappy),
  cambiate da `yumi-workflow`.
- **Un motore dei colori mio,** `yumi-colors`: template in `~/.config/yumi/colors/templates` per Waybar, swaync, kitty,
  GTK, Qt/Kvantum, VS Code, Discord, cava, Obsidian, la retroilluminazione della tastiera e le icone del volume.
- **Waybar direttamente dal pacchetto** con il mio layout (un drop-in di systemd), una configurazione di zsh mia
  (`conf.d/yumi`), un wrapper mio del gestore pacchetti per gli alias `in` / `un` / `up`.
- **Un solo schema di nomi:** ogni comando è `yumi-*`, le librerie stanno in `~/.local/lib/yumi/`, le impostazioni in
  `~/.config/yumi/`. `cc` è di nuovo il compilatore C — il centro di controllo ora è `yumi-cc`.

**Novità**
- **Pult** (`yumi-pult`, `SUPER+Space`) — una finestra alla Spotlight/Raycast: app, comandi Yumi, file (`fd`),
  calcolatrice, emoji e ricerca web in un'unica lista, con l'anteprima a destra. Trova anche le parole scritte con il
  layout di tastiera sbagliato.
- **Dottore** (`yumi-doctor`): 13 controlli — servizi, timer, configurazione di Hyprland, link rotti, colori dello
  sfondo, memoria di Waybar, disco, aggiornamenti, snapshot di snapper, blocco di pacman — spiegati in parole semplici,
  con `--fix` e `--json`. E una voce "Dottore" nel menu Sistema.
- **Collezioni di sfondi:** le sottocartelle di `~/Pictures/Wallpapers` diventano collezioni con anteprima, pulsanti
  nel menu degli sfondi e il comando `yumi-wallpaper collection NOME|off|get`. Le copie sono già ridimensionate per
  ogni schermo, la transizione gira alla frequenza di ciascun monitor e Waybar si ricolora subito prima della
  transizione, non dopo.
- **Schermata di accesso:** un tema SDDM mio, `yumi`, con lo sfondo che segue quello del desktop (`yumi-sddm-sync`).
- **Terminale:** kitty con CaskaydiaCove Nerd Font Mono, un prompt starship su due righe nei colori della palette del
  terminale, zoxide (`z` / `zi`), atuin su `Ctrl+R` (solo locale, senza sincronizzazione), alias di eza. fastfetch con
  un logo di testo (arco e freccia), sezioni incorniciate e una citazione giapponese del giorno con traduzione.
- **Zen** è il browser predefinito (Firefox rimosso), con i colori dello sfondo (`yumi-zen-theme`), comprese le pagine delle impostazioni.
- **E inoltre:** un lettore a schermo intero (`yumi-player-full`) e una coda nel lettore, una pagina dei dispositivi
  dentro il centro di controllo, notifiche della batteria del mouse e degli AirPods, `yumi-update` con una cache di 30
  minuti (Waybar non lancia più `checkupdates` ogni volta), il tema di icone delle cartelle Yumi-Folders, il tema di
  VS Code come estensione a sé.

**`rice`**
- Rimossi `./rice hyde-patches` e `hyde-patches.sh`; `./rice reload` riavvia Waybar tramite systemd;
  `./rice doctor` comincia con `yumi-doctor`.
- Il manifest è stato rifatto per i nuovi percorsi (~300 file); `./rice check` controlla anche `system/`.
- `system-manifest.txt`: l'impostazione del tema SDDM, il puntatore nella schermata di accesso e le icone della Touch Bar (tiny-dfr).
- Gli script di ripristino della 2.x non fanno parte della 3.0 — restano nella [`v2.5`](https://github.com/sonoyumi/yumi-rice/releases/tag/v2.5).

<details>
<summary><b>Versioni precedenti: 2.5 · 2.1 · 2.0</b></summary>

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
- `ai` — piccolo assistente locale per il codice (Qwen2.5-Coder 1.5B tramite Ollama).

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

- **Waybar a pillole:** il mio layout `yumi`, ogni gruppo di moduli è una pillola arrotondata a sé. A sinistra: logo,
  spazi di lavoro, CPU / RAM. Al centro: il lettore con copertina ed equalizzatore. A destra: centro di controllo e
  appunti · layout di tastiera, VPN, "non sospendere", Wi-Fi, Bluetooth, audio (con le icone degli AirPods) · orologio,
  batteria, profilo energetico e modalità di lavoro · pulsante di spegnimento. Le pillole si aggiornano sugli eventi
  D-Bus (`yumi-bar-events`), non con il polling.
- **Menu in GTK4 (`yumi-panel`):** un unico framework — una finestra layer-shell con sfocatura, i colori dello sfondo
  e la navigazione da tastiera. Wi-Fi, Bluetooth, audio, VPN, energia e modalità, sessione, sistema (aggiornamenti,
  snapshot, risorse, Dottore), processi, mouse, calendario con promemoria, appunti, sfondi, spazi di lavoro, tray,
  musica, app, emoji e glifi, ricerca web.
- **Centro di controllo** (`yumi-menu-control`, GTK4): riquadri, cursori, scheda del lettore, dispositivi, "Non
  disturbare" e cronologia delle notifiche. I popup li disegna swaync.
- **Tutto segue lo sfondo:** `yumi-colors` e gli hook di `yumi-accent` ricolorano Waybar, i menu, swaync, kitty,
  GTK/Qt, i bordi delle finestre, VS Code, Telegram, Vesktop, Zen, la Touch Bar, le icone delle cartelle, la schermata
  di blocco e SDDM.
- **Schermata di blocco "Yumi Google":** `yumi-hyprlock-build` la costruisce da un template per ogni monitor —
  orologio, citazioni, lettore, informazioni di sistema. Accesso automatico SDDM → Hyprland → subito hyprlock; il
  desktop viene disegnato *sotto* il blocco.
- **Musica:** `yumi-music` — YouTube Music + SoundCloud con copertine, playlist e testi; il servizio `yumi-airpods`
  mette in pausa quando togli un auricolare e restituisce gli auricolari all'iPhone quando il portatile si blocca.
- **Vivere con 8 GB:** zram grande quanto la RAM + un file di swap; earlyoom chiude prima le schede del browser e mai
  il desktop; Zen gira nel suo cgroup (`zen.slice`); `lim 1G <comando>` avvia i server di prova in `dev.slice` con un
  tetto di memoria.
- **Sistema:** avvio silenzioso (menu di GRUB nascosto, `quiet loglevel=3`), snapshot btrfs con snapper (snap-pac
  prima e dopo ogni pacman, `/home` ogni ora), faillock, BlueZ Experimental per la batteria delle cuffie.
- **Due monitor su un MacBook M1:** lo schermo esterno funziona tramite DisplayPort alt mode su USB-C grazie a
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Gli spazi 1–5 stanno sul MacBook, 6–10 sul monitor
  esterno; scollegandolo passano al portatile. Scale e nomi dei monitor sono in un solo file, `~/.config/yumi/monitors.conf`.
- **Logitech senza G HUB:** un menu del mouse con DPI e frequenza di polling (Solaar); la retroilluminazione della
  tastiera segue lo sfondo tramite un server OpenRGB; Win e Alt sono scambiati solo sulla tastiera esterna; tasti
  multimediali su `ALT+F9–F12`.
- **Ogni modifica si può annullare:** `./rice push` conserva la versione precedente di ogni file, `./rice push-system`
  applica `/etc` un file alla volta dopo uno snapshot di snapper, e le aggiunte si annullano con `yumi-uninstall <modulo>`.

### Screenshot

Vedi la [galleria nella sezione inglese](#screenshots): prima la 3.0 (con la GIF del cambio di sfondo), poi le versioni precedenti.

### Tasti e gesti

| Tasti | Azione |
|---|---|
| `SUPER` + `Space` | Pult: app, comandi, file, calcolatrice, emoji, web |
| `SUPER` + `Esc`, `CTRL` + `ALT` + `Canc` | Sessione: blocco, sospensione, uscita, riavvio, spegnimento |
| `SUPER` + `N` | Blocca lo schermo |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Lettore / libreria musicale |
| `SUPER` + `V` | Appunti |
| `SUPER` + `TAB` | Spazi di lavoro |
| `SUPER` + `` ` `` | Menu di sistema |
| `SUPER` + `A` | App |
| `SUPER` + `,` / `SUPER` + `.` | Emoji / glifi |
| `SUPER` + `SHIFT` + `W` | Scelta dello sfondo |
| `SUPER` + `ALT` + `←` / `→` | Sfondo precedente / successivo |
| `SUPER` + `/` | Energia e modalità di lavoro |
| `SUPER` + `ALT` + `↑` / `↓` | Modalità di lavoro successiva / precedente |
| `SUPER` + `K` | Layout su tutte le tastiere |
| `SUPER` + `F10` / `F11` / `F12`, `Stamp` | Screenshot: area / schermo congelato / monitor / tutti i monitor |
| `ALT` + `F9`…`F12`, `ALT` + `Stamp` / `Bloc Scorr` / `Pausa` | Musica e volume dalla tastiera esterna |
| 3 dita ← / → | Cambio di spazio di lavoro |
| 3 dita ↓ | Panoramica degli spazi di lavoro |

### Avvio rapido

> [!WARNING]
> Queste sono le configurazioni di **una macchina specifica**: MacBook M1, Asahi, schermo 2560×1600. HyDE non serve
> più. Su altro hardware usatele come base e prendetene delle parti; un installer per altre distribuzioni e hardware
> comune è previsto per la 3.1. Applicate i file di sistema (`system/`) solo consapevolmente.

Serve Hyprland ≥ 0.56 (configurazione Lua) e i pacchetti:

```bash
sudo pacman -S --needed hyprland hypridle hyprlock hyprsunset hyprpolkitagent hyprpicker uwsm \
    waybar swaync awww kitty zsh starship fastfetch zoxide atuin eza fd jq cliphist wl-clipboard \
    playerctl imagemagick inotify-tools bluez-utils power-profiles-daemon libnotify brightnessctl btop \
    gtk4 gtk4-layer-shell python-gobject python-dbus python-requests pacman-contrib yt-dlp mpv cava \
    grim slurp satty tesseract udiskie snapper snap-pac earlyoom zram-generator kvantum qt6ct \
    ttf-cascadia-code-nerd ttf-jetbrains-mono-nerd noto-fonts-cjk solaar openrgb python-ytmusicapi wireproxy
```

Da AUR: `zen-browser-bin`. Plugin di zsh: oh-my-zsh con `zsh-autosuggestions` e `zsh-syntax-highlighting`.

```bash
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./rice diff            # cosa cambierà
./rice push            # copia i file in ~ (le vecchie versioni vanno in ~/.local/state/rice-bak/)
systemctl --user daemon-reload
systemctl --user enable --now yumi-awww.service yumi-wallpaper.service yumi-bar-events.service \
    yumi-tray.service yumi-notify-log.service yumi-hyprlock-bg.service yumi-calendar-remind.timer
$EDITOR ~/.config/yumi/monitors.conf   # i vostri monitor: scala dell'interfaccia, nome
yumi-wallpaper random  # immagini da ~/Pictures/Wallpapers (sottocartelle = collezioni); i colori seguono
yumi-hyprlock-build    # costruisce la schermata di blocco per i monitor di monitors.conf
yumi-doctor            # controlla che sia tutto a posto
./rice reload
./rice push-system     # facoltativo: /etc, un file alla volta con conferma
~/.local/share/yumi-sddm/install.sh   # facoltativo: il tema SDDM (ripristino: uninstall.sh accanto)
```

Nel repository al posto del percorso della home c'è `@HOME@`, e nel file di accesso automatico `@USER@`:
`./rice push` inserisce i vostri valori. Mettete il vostro avatar in `~/.config/hypr/hyprlock/avatar.jpg`.

### Lo script `rice`

Il repository è la fonte di verità; `rice` lo sincronizza con il sistema.

| Comando | Cosa fa |
|---|---|
| `./rice pull` | Sistema → repository |
| `./rice diff [percorso]` | Cosa differisce tra sistema e repository |
| `./rice push` | Repository → `~` (con backup delle versioni precedenti) |
| `./rice push-system` | Repository → `/etc` (diff e conferma per ogni file, prima uno snapshot di snapper) |
| `./rice reload` | Ricarica Hyprland, Waybar, swaync, systemd --user |
| `./rice add <percorso>` | Inizia a tracciare un file |
| `./rice doctor` | `yumi-doctor` più i dettagli del repository: servizi, crash, differenze, file fuori dal manifest |
| `./rice check` | Controllo del repository prima di un commit: sintassi, dati personali, segreti (`--install-hook` lo esegue a ogni commit) |
| `./rice gc [--apply]` | Pulizia: `__pycache__`, vecchi archivi `rice-bak`, `.bak` e ripristini da `~/.local/bin` nell'archivio (senza `--apply` mostra soltanto) |
| `./rice drift [--notify [N]]` | Quanto il sistema si è allontanato dal repository (notifica oltre N blocchi) |

Le modifiche personali stanno fuori dal repository, in `~/.config/rice-local/` (stessa struttura di `home/`, più un
suo `manifest.txt`): `./rice` le installa al posto dei file pubblici, così le modifiche private non arrivano mai su
GitHub. I blocchi privati dentro un file condiviso sono marcati `yumi:private-begin/-end` e tagliati da `tools/publicize`.
`RICE_LOCAL=off ./rice push` installa la versione pubblica pulita.

Flusso di lavoro: modifica in `home/…` → `./rice push` → `./rice reload` → verifica → `git commit`.
Non piace — `git checkout -- <file>` e di nuovo `./rice push`.

### Struttura del progetto

```
yumi-rice/
├── home/
│   ├── .config/hypr/       # hyprland.lua + yumi/ (moduli, modalità di lavoro), hyprlock, hypridle
│   ├── .config/yumi/       # monitors.conf, hook dell'accento, template dei colori, stili di menu e lettore
│   ├── .config/waybar/     # layout yumi.jsonc, moduli e stili
│   ├── .config/swaync/     # layout del centro di controllo e stile dei popup
│   ├── .config/systemd/    # servizi e timer yumi-*, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # comandi yumi-*: menu, pult, dottore, sfondi, colori, lettore…
│   ├── .local/lib/yumi/    # panel (menu GTK4), bar (moduli Waybar), colors, tray, calendar, fetch…
│   ├── .local/src/yumi-eq/ # equalizzatore CFFI per Waybar (C)
│   └── .local/share/       # tema SDDM, tema VS Code, aiuti per la musica, dati del picker
├── system/etc/             # GRUB, SDDM, zram, sysctl, earlyoom, BlueZ, faillock, puntatore X11, tiny-dfr
├── assets/screenshots/
├── manifest.txt            # file tracciati da ~
├── system-manifest.txt     # file tracciati da /etc
├── rice                    # script di sincronizzazione
└── tools/                  # publicize (copia pubblica da quella privata), check (controllo prima del commit)
```

### Insidie: Hyprland 0.56 Lua e Asahi

- Le opzioni usano il punto: `hyprctl getoption decoration.rounding`. I dispatcher sono Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` non funziona — usa `hyprctl eval 'hl.config({...})'`.
- La scala deve dividere la risoluzione: `1.666667`, non `1.67`.
- Il modulo integrato `hyprland/language` di Waybar non funziona con Hyprland Lua — serve un modulo proprio.
- swaync esegue i comandi senza `XDG_RUNTIME_DIR` — `wpctl` restituisce 0; i cursori vogliono `min_limit/max_limit` espliciti.
- hyprlock: `$BACKGROUND_PATH` è inaffidabile (meglio un percorso assoluto), `onclick` funziona solo con `hide_cursor = false`,
  `fadeOut, 0` elimina il fotogramma grigio dopo l'avvio.
- `hypridle.conf` include **tutti** i file di `hypridle/` — qualsiasi backup accanto alla vostra configurazione la sovrascrive.
- Alcuni pacchetti mettono un `[Autologin]` vuoto in `/etc/sddm.conf.d/` — date al vostro file un nome che venga per ultimo in ordine alfabetico (`zz-…`).
- GRUB non scrive `grubenv` su btrfs — niente `GRUB_SAVEDEFAULT`. L'ordine dei parametri conta: `quiet loglevel=3`.
- Asahi non ha MGLRU; power-profiles-daemon offre solo `balanced` e `power-saver`.
- Pagine da 16K: le immagini con jemalloc compilato per 4K si bloccano — aiuta `muvm`.
- `MemoryHigh` senza swap libero congela il processo invece di chiuderlo — usa `MemoryMax`.
- AirPods con dual boot macOS: `br-connection-key-missing` → rimuovi e abbina di nuovo.
- Solaar all'avvio riapplica le zone LED salvate e può spegnere la retroilluminazione della tastiera: segna `led_control`
  e `led_zone_*` come `ignore` nella sua configurazione.
- La modalità `Direct` di OpenRGB sulla tastiera PRO salta dei tasti e l'ordine dei LED non corrisponde al layout:
  `Static` è affidabile.
- Ogni chiamata a `openrgb` riscansiona tutti i dispositivi USB per qualche secondo e intanto Solaar non riesce a
  leggere il mouse: avviare `openrgb --server` una volta all'accesso e inviare i colori con `--client`.
- Un monitor collegato dopo il login ha lo sfondo nero: ridisegna lo sfondo su `monitor.added`.
- dp-altmode: dopo aver scollegato il monitor e sospeso il portatile, il collegamento successivo può fallire fino al
  riavvio (bug noto e aperto). Dopo un aggiornamento del kernel la patch va ricompilata.
- `Hyprland --verify-config` **esegue** i comandi `exec` della configurazione che controlla — verificate solo quella in uso, mai una copia.
- atuin: un `sync_address = ""` vuoto lo rompe — per restare in locale impostate `auto_sync = false` e omettete l'indirizzo.

### Ringraziamenti

[HyDE](https://github.com/HyDE-Project/HyDE) (la base delle versioni 1.0–2.5; da lì vengono i template dei colori wallbash) ·
[Hyprland](https://hyprland.org/) · [Asahi Linux](https://asahilinux.org/) ·
[Hyprlock-Dots](https://github.com/mahaveergurjar/Hyprlock-Dots) (layout della schermata di blocco) ·
[swaync](https://github.com/ErikReider/SwayNotificationCenter) · [Waybar](https://github.com/Alexays/Waybar) ·
[Zen](https://zen-browser.app/) · [starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) · [fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[rofi](https://github.com/davatorium/rofi) ·
[dp-altmode](https://github.com/haripako/dp-altmode) di haripako (DisplayPort via USB-C su M1) · [Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/)

### Autore

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)), sviluppatore Python: bot Telegram, web scraping, automazione.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Vuoi configurare un desktop Linux o automatizzare un lavoro ripetitivo con degli script? Scrivimi.

### Licenza

MIT, vedi [LICENSE](LICENSE).

---

<a name="uk"></a>

## 🇺🇦 Українська

**[🇬🇧 English](#en)** · **[🇮🇹 Italiano](#it)** · **🇺🇦 Українська** · **[🇷🇺 Русский](#ru)**

Мій робочий стіл Hyprland на MacBook Pro M1 з Asahi Linux: Waybar із «пігулок», меню на GTK4
з розмиттям і кольорами шпалер, центр керування в стилі macOS, пульт у дусі Spotlight, екран блокування з плеєром —
і все це перефарбовується під поточні шпалери. Від версії 3.0 усе працює на власній основі, без HyDE. А ще скрипт,
який тримає репозиторій і систему синхронними та зберігає резервну копію кожного файлу, який змінює.

| | |
|---|---|
| Залізо | MacBook Pro 13" M1 (2020), 8 ГБ RAM, екран 2560×1600, масштаб 1.666667 · другий монітор MSI G27C3F 1920×1080 @ 180 Гц через USB-C · клавіатура Logitech PRO і миша PRO X 2 |
| ОС | Arch Linux ARM ([Asahi](https://asahilinux.org/)), ядро `linux-asahi`, сторінки пам'яті 16K, btrfs |
| Робочий стіл | Hyprland 0.56 з Lua-конфігом, власна основа `~/.config/hypr/yumi` (без HyDE), запуск через uwsm |
| Панель / сповіщення / меню | Waybar · swaync · GTK4 (yumi-panel) |
| Блокування / простій / шпалери / вхід | hyprlock · hypridle · awww · SDDM із власною темою |
| Термінал / оболонка / шрифт | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Браузер | [Zen](https://zen-browser.app/) |

### Що нового у 3.0

> [!NOTE]
> **HyDE більше немає.** 3.0 — перший випуск на повністю власній основі: усе, що робив HyDE, тепер роблять мої
> конфіги та скрипти, а сам HyDE видалено. Збірка, як і раніше, розрахована на мою машину — переносимість (інші
> дистрибутиви, звичайне залізо x86, встановлення однією командою) заплановано на **3.1**.

**Власна основа замість HyDE**
- **Hyprland за модулями:** `hyprland.lua` підключає `~/.config/hypr/yumi/` — `env`, `look`, `layout`, `binds`, `rules`,
  `autostart`, `events` — і режими роботи у `workflows/` (default, editing, gaming, powersaver, snappy), які
  перемикає `yumi-workflow`.
- **Власний рушій кольорів** `yumi-colors`: шаблони в `~/.config/yumi/colors/templates` для Waybar, swaync, kitty, GTK,
  Qt/Kvantum, VS Code, Discord, cava, Obsidian, підсвічування клавіатури та значків гучності.
- **Waybar просто з пакета** з власним лейаутом (drop-in для systemd), власне налаштування zsh (`conf.d/yumi`),
  власна обгортка над пакетним менеджером для аліасів `in` / `un` / `up`.
- **Одна схема назв:** усі команди — `yumi-*`, бібліотеки — у `~/.local/lib/yumi/`, налаштування — у `~/.config/yumi/`.
  `cc` знову компілятор C, а центр керування тепер `yumi-cc`.

**Нове**
- **Пульт** (`yumi-pult`, `SUPER+Space`) — вікно в дусі Spotlight/Raycast: програми, команди Yumi, файли (`fd`),
  калькулятор, емодзі та пошук в інтернеті в одному списку, праворуч — попередній перегляд. Знаходить і слова,
  набрані не в тій розкладці.
- **Лікар** (`yumi-doctor`): 13 перевірок — служби, таймери, конфіг Hyprland, биті посилання, кольори шпалер, пам'ять
  Waybar, диск, оновлення, знімки snapper, блокування pacman — людською мовою, з `--fix` і `--json`. І рядок
  «Лікар» у меню «Система».
- **Колекції шпалер:** підпапки `~/Pictures/Wallpapers` стають колекціями з прев'ю, кнопками в меню шпалер і
  командою `yumi-wallpaper collection НАЗВА|off|get`. Копії заздалегідь підігнані під кожен екран, перехід іде з
  частотою кожного монітора, а Waybar перефарбовується одразу перед переходом, а не після.
- **Екран входу:** власна тема SDDM `yumi`, тло якої слідує за шпалерами (`yumi-sddm-sync`).
- **Термінал:** kitty з CaskaydiaCove Nerd Font Mono, дворядкове запрошення starship у кольорах палітри терміналу,
  zoxide (`z` / `zi`), atuin на `Ctrl+R` (лише локально, без синхронізації), аліаси eza. fastfetch з текстовим
  значком (лук і стріла), розділами в рамках і японською цитатою дня з перекладом.
- **Zen** — браузер за замовчуванням (Firefox видалено), у кольорах шпалер (`yumi-zen-theme`), включно зі сторінками налаштувань.
- **А також:** повноекранний плеєр (`yumi-player-full`) і черга в плеєрі, сторінка пристроїв усередині центру
  керування, сповіщення про заряд миші та AirPods, `yumi-update` з кешем на 30 хвилин (Waybar більше не запускає
  `checkupdates` щоразу), тема значків тек Yumi-Folders, тема VS Code як окреме розширення.

**`rice`**
- Прибрано `./rice hyde-patches` і `hyde-patches.sh`; `./rice reload` перезапускає Waybar через systemd;
  `./rice doctor` починається з `yumi-doctor`.
- Маніфест зібрано заново під нові шляхи (~300 файлів); `./rice check` перевіряє й `system/`.
- `system-manifest.txt`: налаштування теми SDDM, курсор на екрані входу та значки Touch Bar (tiny-dfr).
- Скрипти відкату 2.x до 3.0 не входять — вони лишилися у [`v2.5`](https://github.com/sonoyumi/yumi-rice/releases/tag/v2.5).

<details>
<summary><b>Попередні версії: 2.5 · 2.1 · 2.0</b></summary>

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
- `ai` — невеликий локальний помічник для коду (Qwen2.5-Coder 1.5B через Ollama).

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

- **Waybar із пігулок:** власний лейаут `yumi`, кожна група модулів — окрема заокруглена пігулка. Ліворуч: логотип,
  робочі столи, ЦП / ОЗП. У центрі: плеєр з обкладинкою та еквалайзером. Праворуч: центр керування й буфер обміну ·
  розкладка, VPN, «не засинати», Wi-Fi, Bluetooth, звук (зі значками AirPods) · годинник, батарея, профіль живлення
  й режим роботи · кнопка живлення. Пігулки оновлюються за подіями D-Bus (`yumi-bar-events`), а не опитуванням.
- **Меню на GTK4 (`yumi-panel`):** один каркас — вікно layer-shell з розмиттям, кольорами шпалер і керуванням
  з клавіатури. Wi-Fi, Bluetooth, звук, VPN, живлення й режими, сеанс, система (оновлення, знімки, ресурси, лікар),
  процеси, миша, календар з нагадуваннями, буфер обміну, шпалери, робочі столи, трей, музика, програми, емодзі та
  символи, пошук в інтернеті.
- **Центр керування** (`yumi-menu-control`, GTK4): плитки, повзунки, картка плеєра, пристрої, «Не турбувати»
  і журнал сповіщень. Спливні сповіщення малює swaync.
- **Усе під колір шпалер:** `yumi-colors` і хуки `yumi-accent` перефарбовують Waybar, меню, swaync, kitty, GTK/Qt,
  рамки вікон, VS Code, Telegram, Vesktop, Zen, Touch Bar, значки тек, екран блокування та SDDM.
- **Екран блокування «Yumi Google»:** `yumi-hyprlock-build` збирає його із шаблону під кожен монітор — годинник,
  цитати, плеєр, відомості про систему. Автовхід SDDM → Hyprland → одразу hyprlock; робочий стіл малюється *під* блокуванням.
- **Музика:** `yumi-music` — YouTube Music + SoundCloud з обкладинками, плейлистами й текстами пісень; служба
  `yumi-airpods` ставить паузу, коли виймаєш навушник, і віддає навушники айфону під час блокування.
- **Життя на 8 ГБ:** zram розміром з ОЗП + файл підкачки; earlyoom закриває спершу вкладки браузера і ніколи —
  робочий стіл; Zen живе у власній cgroup (`zen.slice`); `lim 1G <команда>` запускає тестові сервери в `dev.slice`
  зі стелею пам'яті.
- **Система:** тихе завантаження (приховане меню GRUB, `quiet loglevel=3`), знімки btrfs через snapper (snap-pac до й
  після кожного pacman, `/home` щогодини), faillock, BlueZ Experimental для заряду навушників.
- **Два монітори на M1:** зовнішній екран працює через DisplayPort alt mode по USB-C завдяки
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Столи 1–5 — на MacBook, 6–10 — на зовнішньому моніторі;
  відключили монітор — вони переїжджають на ноутбук. Масштаби й назви моніторів — в одному файлі `~/.config/yumi/monitors.conf`.
- **Logitech без G HUB:** меню миші з DPI та частотою опитування (Solaar); підсвічування клавіатури слідує за
  шпалерами через сервер OpenRGB; Win і Alt поміняні лише на зовнішній клавіатурі; медіаклавіші — на `ALT+F9–F12`.
- **Будь-яку зміну можна скасувати:** `./rice push` зберігає попередню версію кожного файлу, `./rice push-system`
  застосовує `/etc` по одному файлу після знімка snapper, а доповнення відкочуються через `yumi-uninstall <модуль>`.

### Скриншоти

Див. [галерею в англійському розділі](#screenshots): спершу 3.0 (з GIF зміни шпалер), далі попередні версії.

### Клавіші й жести

| Клавіші | Дія |
|---|---|
| `SUPER` + `Space` | Пульт: програми, команди, файли, калькулятор, емодзі, інтернет |
| `SUPER` + `Esc`, `CTRL` + `ALT` + `Del` | Сеанс: блокування, сон, вихід, перезавантаження, вимкнення |
| `SUPER` + `N` | Заблокувати екран |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Плеєр / медіатека |
| `SUPER` + `V` | Буфер обміну |
| `SUPER` + `TAB` | Робочі столи |
| `SUPER` + `` ` `` | Меню системи |
| `SUPER` + `A` | Програми |
| `SUPER` + `,` / `SUPER` + `.` | Емодзі / символи |
| `SUPER` + `SHIFT` + `W` | Вибір шпалер |
| `SUPER` + `ALT` + `←` / `→` | Попередні / наступні шпалери |
| `SUPER` + `/` | Живлення й режими роботи |
| `SUPER` + `ALT` + `↑` / `↓` | Наступний / попередній режим роботи |
| `SUPER` + `K` | Розкладка на всіх клавіатурах |
| `SUPER` + `F10` / `F11` / `F12`, `Print` | Скриншот: область / заморожений екран / монітор / усі монітори |
| `ALT` + `F9`…`F12`, `ALT` + `Print` / `Scroll Lock` / `Pause` | Музика й гучність із зовнішньої клавіатури |
| 3 пальці ← / → | Перемикання столів |
| 3 пальці ↓ | Огляд робочих столів |

### Швидкий старт

> [!WARNING]
> Це конфіги **конкретної машини**: MacBook M1, Asahi, екран 2560×1600. HyDE більше не потрібен. На іншому залізі
> беріть їх за основу й запозичуйте окремі частини; інсталятор для інших дистрибутивів і звичайного заліза
> заплановано на 3.1. Системні файли (`system/`) застосовуйте лише свідомо.

Потрібен Hyprland ≥ 0.56 (Lua-конфіг) і пакети:

```bash
sudo pacman -S --needed hyprland hypridle hyprlock hyprsunset hyprpolkitagent hyprpicker uwsm \
    waybar swaync awww kitty zsh starship fastfetch zoxide atuin eza fd jq cliphist wl-clipboard \
    playerctl imagemagick inotify-tools bluez-utils power-profiles-daemon libnotify brightnessctl btop \
    gtk4 gtk4-layer-shell python-gobject python-dbus python-requests pacman-contrib yt-dlp mpv cava \
    grim slurp satty tesseract udiskie snapper snap-pac earlyoom zram-generator kvantum qt6ct \
    ttf-cascadia-code-nerd ttf-jetbrains-mono-nerd noto-fonts-cjk solaar openrgb python-ytmusicapi wireproxy
```

З AUR: `zen-browser-bin`. Плагіни zsh: oh-my-zsh з `zsh-autosuggestions` і `zsh-syntax-highlighting`.

```bash
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./rice diff            # що зміниться
./rice push            # розкласти файли по ~ (старі версії — у ~/.local/state/rice-bak/)
systemctl --user daemon-reload
systemctl --user enable --now yumi-awww.service yumi-wallpaper.service yumi-bar-events.service \
    yumi-tray.service yumi-notify-log.service yumi-hyprlock-bg.service yumi-calendar-remind.timer
$EDITOR ~/.config/yumi/monitors.conf   # ваші монітори: масштаб інтерфейсу, назва
yumi-wallpaper random  # картинки з ~/Pictures/Wallpapers (підпапки — колекції); кольори підтягнуться самі
yumi-hyprlock-build    # зібрати екран блокування для моніторів з monitors.conf
yumi-doctor            # перевірити, що все на місці
./rice reload
./rice push-system     # за бажанням: /etc, по одному файлу з підтвердженням
~/.local/share/yumi-sddm/install.sh   # за бажанням: тема SDDM (відкат — uninstall.sh поруч)
```

У репозиторії замість домашнього шляху стоїть мітка `@HOME@`, а в автовході — `@USER@`: `./rice push` підставить
ваші значення. Свій аватар покладіть у `~/.config/hypr/hyprlock/avatar.jpg`.

### Скрипт `rice`

Репозиторій — джерело істини, `rice` синхронізує його із системою.

| Команда | Що робить |
|---|---|
| `./rice pull` | Система → репозиторій |
| `./rice diff [шлях]` | Чим система відрізняється від репозиторію |
| `./rice push` | Репозиторій → `~` (з резервною копією попередніх версій) |
| `./rice push-system` | Репозиторій → `/etc` (diff і підтвердження для кожного файлу, спершу знімок snapper) |
| `./rice reload` | Перечитати Hyprland, Waybar, swaync, systemd --user |
| `./rice add <шлях>` | Почати відстежувати файл |
| `./rice doctor` | `yumi-doctor` і подробиці для репозиторію: служби, падіння, розбіжності, файли поза маніфестом |
| `./rice check` | Перевірка репозиторію перед комітом: синтаксис, особисте, секрети (`--install-hook` — на кожен коміт) |
| `./rice gc [--apply]` | Прибирання: `__pycache__`, старі архіви `rice-bak`, `.bak` і відкати з `~/.local/bin` в архів (без `--apply` лише показує) |
| `./rice drift [--notify [N]]` | Наскільки система відійшла від репозиторію (сповіщення понад N блоків) |

Особисті правки лежать поза репозиторієм, у `~/.config/rice-local/` (та сама структура, що в `home/`, плюс власний
`manifest.txt`): `./rice` ставить їх замість публічних файлів, тож особисті зміни не потрапляють на GitHub.
Особисті блоки всередині спільного файлу позначаються `yumi:private-begin/-end` і вирізаються `tools/publicize`.
`RICE_LOCAL=off ./rice push` ставить чисту публічну версію.

Робота: правка в `home/…` → `./rice push` → `./rice reload` → перевірити → `git commit`.
Не сподобалося — `git checkout -- <файл>` і знову `./rice push`.

### Структура проєкту

```
yumi-rice/
├── home/
│   ├── .config/hypr/       # hyprland.lua + yumi/ (модулі, режими роботи), hyprlock, hypridle
│   ├── .config/yumi/       # monitors.conf, хуки акценту, шаблони кольорів, стилі меню й плеєра
│   ├── .config/waybar/     # лейаут yumi.jsonc, модулі та стилі
│   ├── .config/swaync/     # розкладки центру керування й стиль спливних сповіщень
│   ├── .config/systemd/    # служби й таймери yumi-*, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # команди yumi-*: меню, пульт, лікар, шпалери, кольори, плеєр…
│   ├── .local/lib/yumi/    # panel (меню GTK4), bar (модулі Waybar), colors, tray, calendar, fetch…
│   ├── .local/src/yumi-eq/ # CFFI-еквалайзер для Waybar (C)
│   └── .local/share/       # тема SDDM, тема VS Code, помічники музики, дані пікера
├── system/etc/             # GRUB, SDDM, zram, sysctl, earlyoom, BlueZ, faillock, курсор X11, tiny-dfr
├── assets/screenshots/
├── manifest.txt            # які файли з ~ відстежуються
├── system-manifest.txt     # які файли з /etc відстежуються
├── rice                    # скрипт синхронізації
└── tools/                  # publicize (публічна копія з особистої), check (перевірка перед комітом)
```

### Підводні камені: Hyprland 0.56 Lua та Asahi

- Опції через крапку: `hyprctl getoption decoration.rounding`. Диспетчери — Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` не працює — `hyprctl eval 'hl.config({...})'`.
- Масштаб має ділити роздільну здатність: `1.666667`, а не `1.67`.
- Вбудований модуль Waybar `hyprland/language` не працює з Lua-Hyprland — потрібен власний.
- swaync запускає команди без `XDG_RUNTIME_DIR` — `wpctl` повертає 0; повзункам потрібні явні `min_limit/max_limit`.
- hyprlock: `$BACKGROUND_PATH` ненадійний (краще абсолютний шлях), `onclick` працює лише з `hide_cursor = false`,
  `fadeOut, 0` прибирає сірий кадр після завантаження.
- `hypridle.conf` підключає **всі** файли з `hypridle/` — будь-який бекап поруч перебиває ваш конфіг.
- Деякі пакети кладуть у `/etc/sddm.conf.d/` порожній `[Autologin]` — називайте свій файл так, щоб він був останнім за абеткою (`zz-…`).
- GRUB не пише `grubenv` на btrfs — без `GRUB_SAVEDEFAULT`. Порядок параметрів важливий: `quiet loglevel=3`.
- На Asahi немає MGLRU; power-profiles-daemon має лише `balanced` і `power-saver`.
- Сторінки 16K: образи з jemalloc, зібраним під 4K, падають — рятує `muvm`.
- `MemoryHigh` без вільного свопу заморожує процес замість того, щоб закрити його, — використовуйте `MemoryMax`.
- AirPods при подвійному завантаженні з macOS: `br-connection-key-missing` → видалити й спарити знову.
- Solaar під час запуску застосовує збережені зони підсвітки і може вимкнути підсвітку клавіатури: позначте `led_control`
  і `led_zone_*` як `ignore` у його конфігурації.
- Режим `Direct` в OpenRGB на клавіатурі PRO пропускає клавіші, а порядок світлодіодів не збігається з розкладкою:
  надійний `Static`.
- Звичайний `openrgb` за кожного виклику кілька секунд заново опитує всі USB-пристрої, і Solaar тим часом не може
  прочитати мишу: запускати `openrgb --server` один раз під час входу, а колір надсилати через `--client`.
- Монітор, під'єднаний після входу, отримує чорне тло: перемальовуйте шпалери за подією `monitor.added`.
- dp-altmode: якщо від'єднати монітор і приспати ноутбук, наступне під'єднання може не спрацювати до перезавантаження
  (відомий відкритий баг). Після оновлення ядра патч треба перезібрати.
- `Hyprland --verify-config` **виконує** команди `exec` з конфігу, який перевіряє, — перевіряйте лише живий конфіг, не копію.
- atuin: порожній `sync_address = ""` ламає його — щоб усе було локально, ставте `auto_sync = false` і не вказуйте адресу.

### Подяки

[HyDE](https://github.com/HyDE-Project/HyDE) (основа версій 1.0–2.5; з нього виросли шаблони кольорів wallbash) ·
[Hyprland](https://hyprland.org/) · [Asahi Linux](https://asahilinux.org/) ·
[Hyprlock-Dots](https://github.com/mahaveergurjar/Hyprlock-Dots) (розкладка екрана блокування) ·
[swaync](https://github.com/ErikReider/SwayNotificationCenter) · [Waybar](https://github.com/Alexays/Waybar) ·
[Zen](https://zen-browser.app/) · [starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) · [fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[rofi](https://github.com/davatorium/rofi) ·
[dp-altmode](https://github.com/haripako/dp-altmode) від haripako (DisplayPort по USB-C на M1) · [Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/)

### Автор

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)) — Python-розробник: Telegram-боти, парсинг, автоматизація.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Потрібно налаштувати робочий стіл Linux або автоматизувати рутину скриптами? Напишіть мені.

### Ліцензія

MIT — див. [LICENSE](LICENSE).

---

<a name="ru"></a>

## 🇷🇺 Русский

**[🇬🇧 English](#en)** · **[🇮🇹 Italiano](#it)** · **[🇺🇦 Українська](#uk)** · **🇷🇺 Русский**

Мой рабочий стол Hyprland на MacBook Pro M1 с Asahi Linux: Waybar из «пилюль», меню на GTK4
с размытием и цветами обоев, центр управления в стиле macOS, пульт в духе Spotlight, экран блокировки с плеером —
и всё это перекрашивается под текущие обои. С версии 3.0 всё работает на своей основе, без HyDE. А ещё скрипт,
который держит репозиторий и систему синхронными и сохраняет резервную копию каждого файла, который меняет.

| | |
|---|---|
| Железо | MacBook Pro 13" M1 (2020), 8 ГБ RAM, экран 2560×1600, масштаб 1.666667 · второй монитор MSI G27C3F 1920×1080 @ 180 Гц через USB-C · клавиатура Logitech PRO и мышь PRO X 2 |
| ОС | Arch Linux ARM ([Asahi](https://asahilinux.org/)), ядро `linux-asahi`, страницы памяти 16K, btrfs |
| Рабочий стол | Hyprland 0.56 с Lua-конфигом, своя основа `~/.config/hypr/yumi` (без HyDE), запуск через uwsm |
| Бар / уведомления / меню | Waybar · swaync · GTK4 (yumi-panel) |
| Блокировка / простой / обои / вход | hyprlock · hypridle · awww · SDDM со своей темой |
| Терминал / оболочка / шрифт | kitty · zsh + starship · CaskaydiaCove Nerd Font Mono |
| Браузер | [Zen](https://zen-browser.app/) |

### Что нового в 3.0

> [!NOTE]
> **HyDE больше нет.** 3.0 — первый выпуск на полностью своей основе: всё, что делал HyDE, теперь делают мои
> конфиги и скрипты, а сам HyDE удалён. Сборка по-прежнему рассчитана на мою машину — переносимость (другие
> дистрибутивы, обычное железо x86, установка одной командой) запланирована на **3.1**.

**Своя основа вместо HyDE**
- **Hyprland по модулям:** `hyprland.lua` подключает `~/.config/hypr/yumi/` — `env`, `look`, `layout`, `binds`, `rules`,
  `autostart`, `events` — и режимы работы в `workflows/` (default, editing, gaming, powersaver, snappy), которые
  переключает `yumi-workflow`.
- **Свой движок цветов** `yumi-colors`: шаблоны в `~/.config/yumi/colors/templates` для Waybar, swaync, kitty, GTK,
  Qt/Kvantum, VS Code, Discord, cava, Obsidian, подсветки клавиатуры и значков громкости.
- **Waybar прямо из пакета** со своим лейаутом (drop-in для systemd), своя настройка zsh (`conf.d/yumi`), своя обёртка
  над пакетным менеджером для алиасов `in` / `un` / `up`.
- **Одна схема имён:** все команды — `yumi-*`, библиотеки — в `~/.local/lib/yumi/`, настройки — в `~/.config/yumi/`.
  `cc` снова компилятор C, а центр управления теперь `yumi-cc`.

**Новое**
- **Пульт** (`yumi-pult`, `SUPER+Space`) — окно в духе Spotlight/Raycast: программы, команды Yumi, файлы (`fd`),
  калькулятор, эмодзи и поиск в интернете в одном списке, справа — предпросмотр. Находит и слова, набранные не в той раскладке.
- **Доктор** (`yumi-doctor`): 13 проверок — службы, таймеры, конфиг Hyprland, битые ссылки, цвета обоев, память
  Waybar, диск, обновления, снимки snapper, блокировка pacman — человеческим языком, с `--fix` и `--json`. И строка
  «Доктор» в меню «Система».
- **Коллекции обоев:** подпапки `~/Pictures/Wallpapers` становятся коллекциями с превью, кнопками в меню обоев и
  командой `yumi-wallpaper collection ИМЯ|off|get`. Копии заранее подогнаны под каждый экран, переход идёт с частотой
  каждого монитора, а Waybar перекрашивается прямо перед переходом, а не после.
- **Экран входа:** своя тема SDDM `yumi`, фон которой следует за обоями (`yumi-sddm-sync`).
- **Терминал:** kitty с CaskaydiaCove Nerd Font Mono, двухстрочное приглашение starship в цветах палитры терминала,
  zoxide (`z` / `zi`), atuin на `Ctrl+R` (только локально, без синхронизации), алиасы eza. fastfetch с текстовым
  значком (лук и стрела), разделами в рамках и японской цитатой дня с переводом.
- **Zen** — браузер по умолчанию (Firefox удалён), в цветах обоев (`yumi-zen-theme`), включая страницы настроек.
- **А также:** полноэкранный плеер (`yumi-player-full`) и очередь в плеере, страница устройств внутри центра
  управления, уведомления о заряде мыши и AirPods, `yumi-update` с кэшем на 30 минут (Waybar больше не гоняет
  `checkupdates` каждый раз), тема значков папок Yumi-Folders, тема VS Code как отдельное расширение.

**`rice`**
- Убраны `./rice hyde-patches` и `hyde-patches.sh`; `./rice reload` перезапускает Waybar через systemd;
  `./rice doctor` начинается с `yumi-doctor`.
- Манифест собран заново под новые пути (~300 файлов); `./rice check` проверяет и `system/`.
- `system-manifest.txt`: настройка темы SDDM, курсор на экране входа и значки Touch Bar (tiny-dfr).
- Скрипты откатов 2.x в 3.0 не входят — они остались в [`v2.5`](https://github.com/sonoyumi/yumi-rice/releases/tag/v2.5).

<details>
<summary><b>Прошлые версии: 2.5 · 2.1 · 2.0</b></summary>

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
- `ai` — маленький локальный помощник по коду (Qwen2.5-Coder 1.5B через Ollama).

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

- **Waybar из пилюль:** свой лейаут `yumi`, каждая группа модулей — отдельная скруглённая пилюля. Слева: логотип,
  рабочие столы, ЦП / ОЗУ. В центре: плеер с обложкой и эквалайзером. Справа: центр управления и буфер обмена ·
  раскладка, VPN, «не засыпать», Wi-Fi, Bluetooth, звук (со значками AirPods) · часы, батарея, профиль питания и режим
  работы · кнопка питания. Пилюли обновляются по событиям D-Bus (`yumi-bar-events`), а не опросом.
- **Меню на GTK4 (`yumi-panel`):** один каркас — окно layer-shell с размытием, цветами обоев и управлением
  с клавиатуры. Wi-Fi, Bluetooth, звук, VPN, питание и режимы, сеанс, система (обновления, снимки, ресурсы, доктор),
  процессы, мышь, календарь с напоминаниями, буфер обмена, обои, рабочие столы, трей, музыка, программы, эмодзи и
  символы, поиск в интернете.
- **Центр управления** (`yumi-menu-control`, GTK4): плитки, ползунки, карточка плеера, устройства, «Не беспокоить»
  и журнал уведомлений. Всплывающие уведомления рисует swaync.
- **Всё под цвет обоев:** `yumi-colors` и хуки `yumi-accent` перекрашивают Waybar, меню, swaync, kitty, GTK/Qt,
  рамки окон, VS Code, Telegram, Vesktop, Zen, Touch Bar, значки папок, экран блокировки и SDDM.
- **Экран блокировки «Yumi Google»:** `yumi-hyprlock-build` собирает его из шаблона под каждый монитор — часы,
  цитаты, плеер, сведения о системе. Автовход SDDM → Hyprland → сразу hyprlock; рабочий стол рисуется *под* блокировкой.
- **Музыка:** `yumi-music` — YouTube Music + SoundCloud с обложками, плейлистами и текстами песен; служба
  `yumi-airpods` ставит паузу, когда вынимаешь наушник, и отдаёт наушники айфону при блокировке.
- **Жизнь на 8 ГБ:** zram размером с ОЗУ + файл подкачки; earlyoom закрывает сначала вкладки браузера и никогда —
  рабочий стол; Zen живёт в своей cgroup (`zen.slice`); `lim 1G <команда>` запускает тестовые серверы в `dev.slice`
  с потолком памяти.
- **Система:** тихая загрузка (скрытое меню GRUB, `quiet loglevel=3`), снимки btrfs через snapper (snap-pac до и
  после каждого pacman, `/home` каждый час), faillock, BlueZ Experimental для заряда наушников.
- **Два монитора на M1:** внешний экран работает через DisplayPort alt mode по USB-C благодаря
  [haripako/dp-altmode](https://github.com/haripako/dp-altmode). Столы 1–5 — на MacBook, 6–10 — на внешнем мониторе;
  отключили монитор — они переезжают на ноутбук. Масштабы и имена мониторов — в одном файле `~/.config/yumi/monitors.conf`.
- **Logitech без G HUB:** меню мыши с DPI и частотой опроса (Solaar); подсветка клавиатуры следует за обоями через
  сервер OpenRGB; Win и Alt поменяны только на внешней клавиатуре; медиаклавиши — на `ALT+F9–F12`.
- **Любую правку можно откатить:** `./rice push` хранит прежнюю версию каждого файла, `./rice push-system`
  применяет `/etc` по одному файлу после снимка snapper, а доработки откатываются через `yumi-uninstall <модуль>`.

### Скриншоты

См. [галерею в английском разделе](#screenshots): сначала 3.0 (с GIF смены обоев), потом прошлые версии.

### Клавиши и жесты

| Клавиши | Действие |
|---|---|
| `SUPER` + `Space` | Пульт: программы, команды, файлы, калькулятор, эмодзи, интернет |
| `SUPER` + `Esc`, `CTRL` + `ALT` + `Del` | Сеанс: блокировка, сон, выход, перезагрузка, выключение |
| `SUPER` + `N` | Заблокировать экран |
| `SUPER` + `M` / `SUPER` + `SHIFT` + `M` | Плеер / медиатека |
| `SUPER` + `V` | Буфер обмена |
| `SUPER` + `TAB` | Рабочие столы |
| `SUPER` + `` ` `` | Меню системы |
| `SUPER` + `A` | Программы |
| `SUPER` + `,` / `SUPER` + `.` | Эмодзи / символы |
| `SUPER` + `SHIFT` + `W` | Выбор обоев |
| `SUPER` + `ALT` + `←` / `→` | Предыдущие / следующие обои |
| `SUPER` + `/` | Питание и режимы работы |
| `SUPER` + `ALT` + `↑` / `↓` | Следующий / предыдущий режим работы |
| `SUPER` + `K` | Раскладка на всех клавиатурах |
| `SUPER` + `F10` / `F11` / `F12`, `Print` | Скриншот: область / замороженный экран / монитор / все мониторы |
| `ALT` + `F9`…`F12`, `ALT` + `Print` / `Scroll Lock` / `Pause` | Музыка и громкость с внешней клавиатуры |
| 3 пальца ← / → | Переключение столов |
| 3 пальца ↓ | Обзор рабочих столов |

### Быстрый старт

> [!WARNING]
> Это конфиги **конкретной машины**: MacBook M1, Asahi, экран 2560×1600. HyDE больше не нужен. На другом железе
> берите их за основу и заимствуйте отдельные части; установщик для других дистрибутивов и обычного железа
> запланирован на 3.1. Системные файлы (`system/`) применяйте только осознанно.

Нужен Hyprland ≥ 0.56 (Lua-конфиг) и пакеты:

```bash
sudo pacman -S --needed hyprland hypridle hyprlock hyprsunset hyprpolkitagent hyprpicker uwsm \
    waybar swaync awww kitty zsh starship fastfetch zoxide atuin eza fd jq cliphist wl-clipboard \
    playerctl imagemagick inotify-tools bluez-utils power-profiles-daemon libnotify brightnessctl btop \
    gtk4 gtk4-layer-shell python-gobject python-dbus python-requests pacman-contrib yt-dlp mpv cava \
    grim slurp satty tesseract udiskie snapper snap-pac earlyoom zram-generator kvantum qt6ct \
    ttf-cascadia-code-nerd ttf-jetbrains-mono-nerd noto-fonts-cjk solaar openrgb python-ytmusicapi wireproxy
```

Из AUR: `zen-browser-bin`. Плагины zsh: oh-my-zsh с `zsh-autosuggestions` и `zsh-syntax-highlighting`.

```bash
git clone https://github.com/sonoyumi/yumi-rice.git ~/Projects/yumi-rice
cd ~/Projects/yumi-rice
./rice diff            # что изменится
./rice push            # разложить файлы по ~ (старые версии — в ~/.local/state/rice-bak/)
systemctl --user daemon-reload
systemctl --user enable --now yumi-awww.service yumi-wallpaper.service yumi-bar-events.service \
    yumi-tray.service yumi-notify-log.service yumi-hyprlock-bg.service yumi-calendar-remind.timer
$EDITOR ~/.config/yumi/monitors.conf   # ваши мониторы: масштаб интерфейса, название
yumi-wallpaper random  # картинки из ~/Pictures/Wallpapers (подпапки — коллекции); цвета подтянутся сами
yumi-hyprlock-build    # собрать экран блокировки для мониторов из monitors.conf
yumi-doctor            # проверить, что всё на месте
./rice reload
./rice push-system     # по желанию: /etc, по одному файлу с подтверждением
~/.local/share/yumi-sddm/install.sh   # по желанию: тема SDDM (откат — uninstall.sh рядом)
```

В репозитории вместо домашнего пути стоит метка `@HOME@`, а в автовходе — `@USER@`: `./rice push` подставит
ваши значения. Свой аватар положите в `~/.config/hypr/hyprlock/avatar.jpg`.

### Скрипт `rice`

Репозиторий — источник истины, `rice` синхронизирует его с системой.

| Команда | Что делает |
|---|---|
| `./rice pull` | Система → репозиторий |
| `./rice diff [путь]` | Чем система отличается от репозитория |
| `./rice push` | Репозиторий → `~` (с резервной копией прежних версий) |
| `./rice push-system` | Репозиторий → `/etc` (diff и подтверждение для каждого файла, сначала снимок snapper) |
| `./rice reload` | Перечитать Hyprland, Waybar, swaync, systemd --user |
| `./rice add <путь>` | Начать отслеживать файл |
| `./rice doctor` | `yumi-doctor` и подробности для репозитория: службы, падения, расхождения, файлы вне манифеста |
| `./rice check` | Проверка репозитория перед коммитом: синтаксис, личное, секреты (`--install-hook` — на каждый коммит) |
| `./rice gc [--apply]` | Уборка: `__pycache__`, старые архивы `rice-bak`, `.bak` и откаты из `~/.local/bin` в архив (без `--apply` только показывает) |
| `./rice drift [--notify [N]]` | Насколько система ушла от репозитория (уведомление больше N блоков) |

Личные правки лежат вне репозитория, в `~/.config/rice-local/` (та же структура, что у `home/`, плюс свой
`manifest.txt`): `./rice` ставит их вместо публичных файлов, поэтому личные изменения не попадают на GitHub.
Личные блоки внутри общего файла помечаются `yumi:private-begin/-end` и вырезаются `tools/publicize`.
`RICE_LOCAL=off ./rice push` ставит чистую публичную версию.

Работа: правка в `home/…` → `./rice push` → `./rice reload` → проверить → `git commit`.
Не понравилось — `git checkout -- <файл>` и снова `./rice push`.

### Структура проекта

```
yumi-rice/
├── home/
│   ├── .config/hypr/       # hyprland.lua + yumi/ (модули, режимы работы), hyprlock, hypridle
│   ├── .config/yumi/       # monitors.conf, хуки акцента, шаблоны цветов, стили меню и плеера
│   ├── .config/waybar/     # лейаут yumi.jsonc, модули и стили
│   ├── .config/swaync/     # раскладки центра управления и стиль всплывашек
│   ├── .config/systemd/    # службы и таймеры yumi-*, dev.slice, zen.slice
│   ├── .config/…           # kitty, zsh, starship, atuin, fastfetch, VS Code
│   ├── .local/bin/         # команды yumi-*: меню, пульт, доктор, обои, цвета, плеер…
│   ├── .local/lib/yumi/    # panel (меню GTK4), bar (модули Waybar), colors, tray, calendar, fetch…
│   ├── .local/src/yumi-eq/ # CFFI-эквалайзер для Waybar (C)
│   └── .local/share/       # тема SDDM, тема VS Code, помощники музыки, данные пикера
├── system/etc/             # GRUB, SDDM, zram, sysctl, earlyoom, BlueZ, faillock, курсор X11, tiny-dfr
├── assets/screenshots/
├── manifest.txt            # какие файлы из ~ отслеживаются
├── system-manifest.txt     # какие файлы из /etc отслеживаются
├── rice                    # скрипт синхронизации
└── tools/                  # publicize (публичная копия из личной), check (проверка перед коммитом)
```

### Грабли: Hyprland 0.56 Lua и Asahi

- Опции через точку: `hyprctl getoption decoration.rounding`. Диспатчеры — Lua:
  `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. `hyprctl keyword` не работает — `hyprctl eval 'hl.config({...})'`.
- Масштаб должен делить разрешение: `1.666667`, а не `1.67`.
- Встроенный модуль Waybar `hyprland/language` не работает с Lua-Hyprland — нужен свой.
- swaync запускает команды без `XDG_RUNTIME_DIR` — `wpctl` возвращает 0; ползункам нужны явные `min_limit/max_limit`.
- hyprlock: `$BACKGROUND_PATH` ненадёжен (лучше абсолютный путь), `onclick` работает только с `hide_cursor = false`,
  `fadeOut, 0` убирает серый кадр после загрузки.
- `hypridle.conf` подключает **все** файлы из `hypridle/` — любой бэкап рядом перебивает ваш конфиг.
- Некоторые пакеты кладут в `/etc/sddm.conf.d/` пустой `[Autologin]` — называйте свой файл так, чтобы он был последним по алфавиту (`zz-…`).
- GRUB не пишет `grubenv` на btrfs — без `GRUB_SAVEDEFAULT`. Порядок параметров важен: `quiet loglevel=3`.
- На Asahi нет MGLRU; у power-profiles-daemon только `balanced` и `power-saver`.
- Страницы 16K: образы с jemalloc, собранным под 4K, падают — выручает `muvm`.
- `MemoryHigh` без свободного свопа замораживает процесс вместо того, чтобы закрыть, — используйте `MemoryMax`.
- AirPods при двойной загрузке с macOS: `br-connection-key-missing` → удалить и сопрячь заново.
- Solaar при запуске применяет сохранённые зоны подсветки и может погасить клавиатуру: пометьте `led_control` и
  `led_zone_*` как `ignore` в его конфиге.
- Режим `Direct` в OpenRGB на клавиатуре PRO пропускает клавиши, а порядок светодиодов не совпадает с раскладкой:
  надёжен `Static`.
- Обычный `openrgb` при каждом вызове несколько секунд заново опрашивает все USB-устройства, и Solaar в это время не
  может прочитать мышь: запускать `openrgb --server` один раз при входе, а цвет отправлять через `--client`.
- Монитор, подключённый после входа, получает чёрный фон: перерисовывайте обои по событию `monitor.added`.
- dp-altmode: если отключить монитор и усыпить ноутбук, следующее подключение может не сработать до перезагрузки
  (известный открытый баг). После обновления ядра патч нужно пересобрать.
- `Hyprland --verify-config` **выполняет** команды `exec` из проверяемого конфига — проверяйте только живой конфиг, не копию.
- atuin: пустой `sync_address = ""` ломает его — чтобы всё было локально, ставьте `auto_sync = false` и не указывайте адрес.

### Благодарности

[HyDE](https://github.com/HyDE-Project/HyDE) (основа версий 1.0–2.5; из него выросли шаблоны цветов wallbash) ·
[Hyprland](https://hyprland.org/) · [Asahi Linux](https://asahilinux.org/) ·
[Hyprlock-Dots](https://github.com/mahaveergurjar/Hyprlock-Dots) (раскладка экрана блокировки) ·
[swaync](https://github.com/ErikReider/SwayNotificationCenter) · [Waybar](https://github.com/Alexays/Waybar) ·
[Zen](https://zen-browser.app/) · [starship](https://starship.rs/) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [atuin](https://atuin.sh/) · [fastfetch](https://github.com/fastfetch-cli/fastfetch) ·
[rofi](https://github.com/davatorium/rofi) ·
[dp-altmode](https://github.com/haripako/dp-altmode) от haripako (DisplayPort по USB-C на M1) · [Solaar](https://github.com/pwr-Solaar/Solaar) · [OpenRGB](https://openrgb.org/)

### Автор

**Vladyslav Shokun** ([@sonoyumi](https://github.com/sonoyumi)) — Python-разработчик: Telegram-боты, парсинг, автоматизация.

[![Telegram](https://img.shields.io/badge/Telegram-write%20me-2CA5E0?logo=telegram&logoColor=white)](https://t.me/sonoyumiii)
[![Email](https://img.shields.io/badge/Email-contact-EA4335?logo=gmail&logoColor=white)](mailto:sonoyumiii@gmail.com)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-profile-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/vladyslav-shokun/)

> 💼 Нужно настроить рабочий стол Linux или автоматизировать рутину скриптами? Напишите мне.

### Лицензия

MIT — см. [LICENSE](LICENSE).
