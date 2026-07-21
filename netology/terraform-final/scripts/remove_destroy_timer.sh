#!/usr/bin/env bash
set -euo pipefail

if command -v crontab >/dev/null 2>&1; then
  crontab -l 2>/dev/null | grep -v "# netology terraform-final auto destroy" | crontab -
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now netology-terraform-final-destroy.timer 2>/dev/null || true
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/netology-terraform-final-destroy.timer"
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/netology-terraform-final-destroy.service"
  systemctl --user daemon-reload 2>/dev/null || true
fi

echo "auto destroy timer removed"
