#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$PROJECT_DIR/src"
LOG_DIR="$PROJECT_DIR/evidence"
LOG_FILE="$LOG_DIR/auto_destroy.log"
DONE_FILE="$LOG_DIR/auto_destroy.done"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"

mkdir -p "$LOG_DIR"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" | tee -a "$LOG_FILE"
}

if [[ -f "$DONE_FILE" ]]; then
  log "destroy already marked as done, skip"
  exit 0
fi

if [[ ! -f "$SRC_DIR/backend.hcl" ]]; then
  log "skip: $SRC_DIR/backend.hcl not found"
  exit 0
fi

if [[ ! -f "$SRC_DIR/personal.auto.tfvars" ]]; then
  log "skip: $SRC_DIR/personal.auto.tfvars not found"
  exit 0
fi

log "terraform init"
"$TERRAFORM_BIN" -chdir="$SRC_DIR" init -backend-config=backend.hcl >> "$LOG_FILE" 2>&1

log "terraform destroy"
"$TERRAFORM_BIN" -chdir="$SRC_DIR" destroy -auto-approve >> "$LOG_FILE" 2>&1

date '+%Y-%m-%d %H:%M:%S %Z' > "$DONE_FILE"
log "destroy completed"
