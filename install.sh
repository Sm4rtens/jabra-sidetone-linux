#!/usr/bin/env bash
# Install jabra-sidetone-linux for the current user.
# The udev rule needs root; everything else is per-user.

set -euo pipefail
cd "$(dirname "$0")"

BIN="$HOME/.local/bin"
UNIT="$HOME/.config/systemd/user"
RULE=/etc/udev/rules.d/70-jabra-hid.rules

for dep in pactl jq od awk; do
  command -v "$dep" >/dev/null || { echo "missing dependency: $dep" >&2; exit 1; }
done

mkdir -p "$BIN" "$UNIT"
install -m 755 bin/jabra-call bin/jabra-call-daemon "$BIN/"
install -m 644 systemd/jabra-call.service "$UNIT/"
echo "installed jabra-call, jabra-call-daemon -> $BIN"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "warning: $BIN is not on your PATH" >&2 ;;
esac

if [[ ! -f $RULE ]]; then
  echo "installing udev rule (needs sudo)"
  sudo install -m 644 udev/70-jabra-hid.rules "$RULE"
  sudo udevadm control --reload
  # uaccess is applied on device add, so a plain reload is not enough.
  sudo udevadm trigger --action=add --subsystem-match=hidraw
else
  echo "udev rule already present at $RULE"
fi

systemctl --user daemon-reload
systemctl --user enable --now jabra-call.service
echo
echo "done. verify with:"
echo "  jabra-call status         # should print a /dev/hidrawN device"
echo "  jabra-call start          # busylight should turn red"
echo "  jabra-call stop"
echo
echo "if the device shows as not writable, replug the headset or dongle."
