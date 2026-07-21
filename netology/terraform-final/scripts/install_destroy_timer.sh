#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTROY_SCRIPT="$PROJECT_DIR/scripts/destroy_stack.sh"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"
RUN_DATE="${1:-$(date -d '+7 days' '+%Y-%m-%d')}"
RUN_TIME="${2:-10:00}"
LOG_FILE="$PROJECT_DIR/evidence/auto_destroy.log"

chmod +x "$DESTROY_SCRIPT"
mkdir -p "$PROJECT_DIR/evidence"

if command -v crontab >/dev/null 2>&1; then
  CRON_TAG="# netology terraform-final auto destroy"
  CRON_LINE="$(date -d "$RUN_DATE $RUN_TIME" '+%M %H %d %m *') TERRAFORM_BIN=$TERRAFORM_BIN $DESTROY_SCRIPT >> $LOG_FILE 2>&1 $CRON_TAG"

  (crontab -l 2>/dev/null | grep -v "$CRON_TAG"; echo "$CRON_LINE") | crontab -
  echo "cron installed: $CRON_LINE"
  exit 0
fi

if command -v systemctl >/dev/null 2>&1; then
  UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$UNIT_DIR"

  cat > "$UNIT_DIR/netology-terraform-final-destroy.service" <<SERVICE
[Unit]
Description=Destroy Netology Terraform final project

[Service]
Type=oneshot
Environment=TERRAFORM_BIN=$TERRAFORM_BIN
ExecStart=$DESTROY_SCRIPT
SERVICE

  cat > "$UNIT_DIR/netology-terraform-final-destroy.timer" <<TIMER
[Unit]
Description=Run Netology Terraform final destroy once

[Timer]
OnCalendar=$RUN_DATE $RUN_TIME
Persistent=true
Unit=netology-terraform-final-destroy.service

[Install]
WantedBy=timers.target
TIMER

  systemctl --user daemon-reload
  systemctl --user enable --now netology-terraform-final-destroy.timer
  systemctl --user list-timers netology-terraform-final-destroy.timer
  exit 0
fi

echo "Neither crontab nor systemd is available. Run manually:"
echo "  TERRAFORM_BIN=$TERRAFORM_BIN $DESTROY_SCRIPT"
exit 1
