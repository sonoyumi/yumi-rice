# Yumi Wallbash

Тема VS Code в цветах обоев для сборки Yumi-Rice. Расширение не содержит кода: это только файл темы
`themes/wallbash.json`, который при смене обоев переписывает `yumi-colors` (шаблон `code-wallbash.dcol`
и скрипт `code-colors.py`). Метка `_watch` в описании темы заставляет VS Code перечитывать файл при изменении.

Сборка и установка: `./build.sh` (создаёт `yumi.wallbash-theme-1.0.0.vsix` и ставит его через `code --install-extension`).
Версия намеренно не меняется: путь `~/.vscode/extensions/yumi.wallbash-theme-1.0.0/themes/wallbash.json` должен быть постоянным.
