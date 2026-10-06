# 🔔 bootcall

Get a Telegram message every time your server boots.

```
🟢 Server started

🖥 Host: my-vps
🕐 Time: 06.10.2026 10:30:00 CEST
🔒 IP: 203.0.113.10
```

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/realChriss/bootcall/main/install.sh | sudo bash
```

The installer asks for your bot token and chat id.

The boot time is shown in the server's timezone.

To get a token, create a bot with [@BotFather](https://t.me/BotFather). To get your chat id, message [@userinfobot](https://t.me/userinfobot) and it replies with your id. Also send `/start` to your own bot once, otherwise it isn't allowed to message you.

Send a test message:

```sh
sudo systemctl start bootcall
```

## Update

Run the install command again. The token and chat id you set before are kept.

## Uninstall

```sh
sudo systemctl disable bootcall
sudo rm -rf /opt/bootcall /etc/bootcall.conf /etc/systemd/system/bootcall.service
sudo systemctl daemon-reload
```

## Files

| Path | Contents |
| --- | --- |
| `/opt/bootcall/` | the script and its `VERSION` |
| `/etc/bootcall.conf` | token and chat id, readable by root only |
| `/etc/systemd/system/bootcall.service` | runs the script once per boot |

Requires a Linux server with systemd and curl.

## Install with arguments

You can also pass the token and chat id directly, so the installer doesn't ask:

```sh
curl -fsSL https://raw.githubusercontent.com/realChriss/bootcall/main/install.sh \
  | sudo bash -s -- --token <bot token> --chat-id <chat id>
```

## License

[Apache 2.0](LICENSE)
