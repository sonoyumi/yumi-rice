//@ pragma UseQApplication
import Quickshell
import qs.menus.youtube

// YumiTube — отдельный экземпляр (не в основном баре: падение клиента не роняет шелл). Запуск: ~/.local/bin/yumi-youtube
// Тест только на макбуке: YUMI_YT_PANEL=1 YUMI_QS_SCREEN=eDP-1 setsid qs -p ~/.config/quickshell/yumi/app-youtube.qml
ShellRoot {
    settings.watchFiles: false
    YouTube {}
}
