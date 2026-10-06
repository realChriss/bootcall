#!/bin/bash
set -euo pipefail

REPO_URL="${BOOTCALL_REPO_URL:-https://raw.githubusercontent.com/realChriss/bootcall/main}"
INSTALL_DIR="/opt/bootcall"
CONFIG="/etc/bootcall.conf"
SERVICE="/etc/systemd/system/bootcall.service"

die() { echo "bootcall: $*" >&2; exit 1; }

usage() {
  cat <<EOF
usage: install.sh [--token <bot token>] [--chat-id <chat id>]

  -t, --token     Telegram bot token
  -c, --chat-id   Telegram chat id to notify
  -h, --help      show this help
EOF
}

ask() {
  local reply=""
  ( : </dev/tty ) 2>/dev/null || die "no terminal to ask for $2, pass it as an argument"
  while [ -z "$reply" ]; do
    read -r -p "$1" reply </dev/tty
  done
  printf '%s' "$reply"
}

TOKEN=""
CHAT_ID_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--token)   [ $# -ge 2 ] || die "$1 needs a value"; TOKEN="$2"; shift 2 ;;
    -c|--chat-id) [ $# -ge 2 ] || die "$1 needs a value"; CHAT_ID_ARG="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            usage >&2; die "unknown argument: $1" ;;
  esac
done

[ "$(id -u)" -eq 0 ] || die "must run as root (pipe into 'sudo bash')"
command -v systemctl >/dev/null || die "systemd is required"
command -v curl >/dev/null || die "curl is required"

if [ -r "$CONFIG" ]; then
  TELEGRAM_TOKEN="" CHAT_ID=""
  . "$CONFIG"
  TOKEN="${TOKEN:-$TELEGRAM_TOKEN}"
  CHAT_ID_ARG="${CHAT_ID_ARG:-$CHAT_ID}"
fi
[ -n "$TOKEN" ] || TOKEN=$(ask "Telegram bot token: " "the bot token")
[ -n "$CHAT_ID_ARG" ] || CHAT_ID_ARG=$(ask "Telegram chat id: " "the chat id")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "downloading bootcall from $REPO_URL"
curl -fsSL "$REPO_URL/bootcall.sh" -o "$tmp/bootcall.sh" || die "could not download bootcall.sh"
curl -fsSL "$REPO_URL/VERSION" -o "$tmp/VERSION" || die "could not download VERSION"
VERSION=$(tr -d '[:space:]' < "$tmp/VERSION")

mkdir -p "$INSTALL_DIR"
install -m 755 "$tmp/bootcall.sh" "$INSTALL_DIR/bootcall.sh"
install -m 644 "$tmp/VERSION" "$INSTALL_DIR/VERSION"

( umask 077; printf 'TELEGRAM_TOKEN=%q\nCHAT_ID=%q\n' "$TOKEN" "$CHAT_ID_ARG" > "$CONFIG" )

cat > "$SERVICE" <<EOF
[Unit]
Description=bootcall: Telegram notification on server boot
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/bootcall.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bootcall.service >/dev/null || die "could not enable bootcall.service"

echo "bootcall $VERSION installed, you will be notified on the next boot"
echo "send a test message now with: systemctl start bootcall"
