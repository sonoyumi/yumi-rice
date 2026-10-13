#  Startup 
# Commands to execute on startup (before the prompt is shown)
# Check if the interactive shell option is set
if [[ $- == *i* ]]; then
    # This is a good place to load graphic/ascii art, display system information, etc.
    if command -v pokego >/dev/null; then
        pokego --no-title -r 1,3,6
    elif command -v pokemon-colorscripts >/dev/null; then
        pokemon-colorscripts --no-title -r 1,3,6
    elif command -v fastfetch >/dev/null; then
        fastfetch      # значок Yumi-Rice — текст (~/.config/fastfetch/yumi-logo.txt), рисуется в любом терминале
    fi
fi

#   Overrides 
# YUMI_ZSH_NO_PLUGINS=1 # без плагинов oh-my-zsh — для своей системы плагинов (plugin.zsh)
# unset YUMI_ZSH_PROMPT # без приглашения из conf.d/yumi/prompt.zsh — для своего
# YUMI_ZSH_COMPINIT_CHECK=1 # полная проверка compinit раз в N часов (24 — быстрее запуск)
# YUMI_ZSH_OMZ_DEFER=1 # отложить плагины oh-my-zsh, ТОЛЬКО если приглашение уже загружено

if [[ ${YUMI_ZSH_NO_PLUGINS} != "1" ]]; then
    #  OMZ Plugins 
    # manually add your oh-my-zsh plugins here
    plugins=(
        "sudo"
    )
fi
# ExpressVPN: vpn — вкл/выкл (по умолчанию США), vpn <локация> — другая страна, vpn s — статус
VPN_REGION="usa-new-york"   # <-- впиши сюда точное имя из шага 1

vpn() {
  local state region ip
  state=$(expressvpnctl get connectionstate 2>/dev/null)

  if [[ "$1" == "s" || "$1" == "status" ]]; then
    echo "VPN: $state"
    return
  fi

  # без аргумента и уже подключён -> отключаем
  if [[ -z "$1" && "$state" == "Connected" ]]; then
    expressvpnctl disconnect
    notify-send -i network-vpn-disconnected "VPN отключён" "Трафик идёт напрямую"
    echo "VPN отключён"
    return
  fi

  region="${1:-$VPN_REGION}"
  notify-send -i network-vpn-acquiring "VPN" "Подключаюсь: $region…"

  if ! expressvpnctl connect "$region"; then
    notify-send -u critical -i network-vpn-disconnected "VPN: ошибка" "Не удалось подключиться к $region"
    return 1
  fi

  # ждём подключения до 20 секунд
  for i in {1..20}; do
    [[ "$(expressvpnctl get connectionstate 2>/dev/null)" == "Connected" ]] && break
    sleep 1
  done

  if [[ "$(expressvpnctl get connectionstate 2>/dev/null)" == "Connected" ]]; then
    ip=$(curl -s --max-time 5 ifconfig.me)
    notify-send -i network-vpn "VPN подключён ✅" "Локация: $region\nIP: ${ip:-не удалось получить}"
    echo "VPN подключён: $region ($ip)"
  else
    notify-send -u critical -i network-vpn-disconnected "VPN: ошибка" "Не подключился за 20 секунд"
    return 1
  fi
}
