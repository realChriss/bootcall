#!/bin/bash

CONFIG="/etc/bootcall.conf"

if [ ! -r "$CONFIG" ]; then
  echo "bootcall: cannot read $CONFIG, run install.sh first" >&2
  exit 1
fi
. "$CONFIG"

HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')
TIMESTAMP=$(date "+%d.%m.%Y %H:%M:%S %Z")

MESSAGE="🟢 *Server started*

🖥 *Host:* \`${HOSTNAME}\`
🕐 *Time:* ${TIMESTAMP}
🔒 *IP:* \`${IP}\`"

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
