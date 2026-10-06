#!/bin/bash

CONFIG="/etc/bootcall.conf"
REPO_URL="https://raw.githubusercontent.com/realChriss/bootcall/main"
VERSION_FILE="$(dirname "$(readlink -f "$0")")/VERSION"

if [ ! -r "$CONFIG" ]; then
  echo "bootcall: cannot read $CONFIG, run install.sh first" >&2
  exit 1
fi
. "$CONFIG"

update_hint() {
  local current latest
  current=$(tr -d '[:space:]' 2>/dev/null < "$VERSION_FILE")
  latest=$(curl -sf --max-time 5 "$REPO_URL/VERSION" | tr -d '[:space:]')
  [[ "$latest" =~ ^[0-9]+(\.[0-9]+)*$ ]] || return 0
  [ -n "$current" ] && [ "$latest" != "$current" ] || return 0
  [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n1)" = "$latest" ] || return 0
  printf '\n\n⬆️ _Update available:_ `%s` → `%s`' "$current" "$latest"
}

HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')
TIMESTAMP=$(date "+%d.%m.%Y %H:%M:%S %Z")

MESSAGE="🟢 *Server started*

🖥 *Host:* \`${HOSTNAME}\`
🕐 *Time:* ${TIMESTAMP}
🔒 *IP:* \`${IP}\`"
MESSAGE+=$(update_hint)

for attempt in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf --max-time 10 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}" \
    --data-urlencode "parse_mode=Markdown" \
    > /dev/null && exit 0
  sleep 6
done

echo "bootcall: could not send the notification" >&2
exit 1
