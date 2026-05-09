#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$ROOT_DIR/.env"

LOG_FILE="$ROOT_DIR/logs/cleanup.log"
ENVS_DIR="$ROOT_DIR/envs"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Cleanup daemon started."

while true; do
  shopt -s nullglob
  STATE_FILES=("$ENVS_DIR"/*.json)
  shopt -u nullglob

  for STATE_FILE in "${STATE_FILES[@]}"; do
    [[ -f "$STATE_FILE" ]] || continue

    ENV_ID=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['id'])")
    EXPIRES_AT=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['expires_at'])")
    NOW=$(date +%s)

    if [[ "$NOW" -ge "$EXPIRES_AT" ]]; then
      log "Environment $ENV_ID has expired. Destroying..."
      bash "$SCRIPT_DIR/destroy_env.sh" "$ENV_ID" >> "$LOG_FILE" 2>&1
      log "Environment $ENV_ID destroyed."
    fi
  done

  sleep 60
done
