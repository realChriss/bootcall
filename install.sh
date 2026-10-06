#!/bin/bash
set -euo pipefail

REPO_URL="${BOOTCALL_REPO_URL:-https://raw.githubusercontent.com/realChriss/bootcall/main}"
INSTALL_DIR="/opt/bootcall"
CONFIG="/etc/bootcall.conf"
SERVICE="/etc/systemd/system/bootcall.service"

if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
  FANCY=true
  C_RESET=$'\033[0m'; C_B=$'\033[1m'; C_DIM=$'\033[2m'
  C_BLUE=$'\033[38;5;39m'; C_GREEN=$'\033[38;5;78m'; C_RED=$'\033[38;5;203m'; C_RAIL=$'\033[38;5;240m'
  C_BADGE=$'\033[1;38;5;16;48;5;39m'
else
  FANCY=false
  C_RESET=""; C_B=""; C_DIM=""; C_BLUE=""; C_GREEN=""; C_RED=""; C_RAIL=""; C_BADGE=""
fi

if [[ "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" == *[Uu][Tt][Ff]* ]]; then
  S_TOP="┌"; S_BAR="│"; S_END="└"; S_ASK="◆"; S_DONE="◇"; S_STEP="●"; S_ERR="■"; S_ELLIPSIS="…"
else
  S_TOP="+"; S_BAR="|"; S_END="+"; S_ASK="?"; S_DONE="+"; S_STEP="*"; S_ERR="x"; S_ELLIPSIS="..."
fi

rail()  { printf '  %s%s%s\n' "$C_RAIL" "$S_BAR" "$C_RESET"; }
step()  { printf '  %s%s%s  %s\n' "$C_GREEN" "$S_STEP" "$C_RESET" "$*"; }

intro() {
  printf '\n  %s%s%s  %s bootcall %s  %stelegram ping on every boot%s\n' \
    "$C_RAIL" "$S_TOP" "$C_RESET" "$C_BADGE" "$C_RESET" "$C_DIM" "$C_RESET"
  rail
}

field() {
  printf '  %s%s%s  %s\n' "$C_GREEN" "$S_DONE" "$C_RESET" "$1"
  printf '  %s%s%s  %s%s%s\n' "$C_RAIL" "$S_BAR" "$C_RESET" "$C_DIM" "$2" "$C_RESET"
  rail
}

die() {
  printf '  %s%s  %s%s\n\n' "$C_RED" "$S_ERR" "$*" "$C_RESET" >&2
  exit 1
}

mask() {
  if [ "${#1}" -gt 12 ]; then printf '%s%s%s' "${1:0:6}" "$S_ELLIPSIS" "${1: -4}"; else printf '%s' "$1"; fi
}

ask() {
  local label="$1" flag="$2" shown="$3" reply=""
  ( : </dev/tty ) 2>/dev/null || die "no terminal to ask for the $label, pass $flag"
  printf '  %s%s%s  %s\n' "$C_BLUE" "$S_ASK" "$C_RESET" "$label" >&2
  while [ -z "$reply" ]; do
    read -r -p "$(printf '  %s%s%s  ' "$C_BLUE" "$S_BAR" "$C_RESET")" reply </dev/tty
    if [ -z "$reply" ] && [ "$FANCY" = true ]; then printf '\033[1A\033[2K' >&2; fi
  done
  if [ "$FANCY" = true ]; then
    printf '\033[2A\r\033[2K  %s%s%s  %s\n\r\033[2K  %s%s%s  %s%s%s\n' \
      "$C_GREEN" "$S_DONE" "$C_RESET" "$label" "$C_RAIL" "$S_BAR" "$C_RESET" "$C_DIM" "$($shown "$reply")" "$C_RESET" >&2
  fi
  rail >&2
  printf '%s' "$reply"
}

usage() {
  cat <<EOF
usage: install.sh [--token <bot token>] [--chat-id <chat id>]

  -t, --token     Telegram bot token
  -c, --chat-id   Telegram chat id to notify
  -h, --help      show this help
EOF
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

intro

[ "$(id -u)" -eq 0 ] || die "must run as root (run it with 'sudo bash -c')"
command -v systemctl >/dev/null || die "systemd is required"
command -v curl >/dev/null || die "curl is required"

if [ -r "$CONFIG" ]; then
  TELEGRAM_TOKEN="" CHAT_ID=""
  . "$CONFIG"
  TOKEN="${TOKEN:-$TELEGRAM_TOKEN}"
  CHAT_ID_ARG="${CHAT_ID_ARG:-$CHAT_ID}"
fi

if [ -n "$TOKEN" ]; then field "bot token" "$(mask "$TOKEN")"; else TOKEN=$(ask "bot token" "--token" mask); fi
if [ -n "$CHAT_ID_ARG" ]; then field "chat id" "$CHAT_ID_ARG"; else CHAT_ID_ARG=$(ask "chat id" "--chat-id" echo); fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$REPO_URL/bootcall.sh" -o "$tmp/bootcall.sh" || die "could not download bootcall.sh from $REPO_URL"
curl -fsSL "$REPO_URL/VERSION" -o "$tmp/VERSION" || die "could not download VERSION from $REPO_URL"
VERSION=$(tr -d '[:space:]' < "$tmp/VERSION")
step "downloaded bootcall $C_B$VERSION$C_RESET"

mkdir -p "$INSTALL_DIR"
install -m 755 "$tmp/bootcall.sh" "$INSTALL_DIR/bootcall.sh"
install -m 644 "$tmp/VERSION" "$INSTALL_DIR/VERSION"
step "installed to $INSTALL_DIR"

( umask 077; printf 'TELEGRAM_TOKEN=%q\nCHAT_ID=%q\n' "$TOKEN" "$CHAT_ID_ARG" > "$CONFIG" )
step "saved settings to $CONFIG"

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
step "enabled on boot"

rail
printf '  %s%s%s  %sall set, you will get a message on the next boot%s\n' "$C_RAIL" "$S_END" "$C_RESET" "$C_GREEN" "$C_RESET"
printf '     %stest it now:%s sudo systemctl start bootcall\n\n' "$C_DIM" "$C_RESET"
