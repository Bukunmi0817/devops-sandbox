#!/usr/bin/env bash
set -euo pipefail

# ── Load config ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$ROOT_DIR/.env"

# ── Arguments ────────────────────────────────────────────
ENV_ID="${1:?Usage: destroy_env.sh <env_id>}"

# ── Paths ────────────────────────────────────────────────
STATE_FILE="$ROOT_DIR/envs/$ENV_ID.json"
LOG_DIR="$ROOT_DIR/logs/$ENV_ID"
ARCHIVE_DIR="$ROOT_DIR/logs/archived/$ENV_ID"
NGINX_CONF="$ROOT_DIR/nginx/conf.d/$ENV_ID.conf"

# ── Validate ─────────────────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
  echo "[$ENV_ID] ERROR: State file not found. Already destroyed?"
  exit 1
fi

echo "[$ENV_ID] Destroying environment..."

# Read container and network names from state file
CONTAINER=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['container'])")
NETWORK=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['network'])")

# ── 1. Kill log shipper ───────────────────────────────────
PID_FILE="$LOG_DIR/log_shipper.pid"
if [[ -f "$PID_FILE" ]]; then
  kill "$(cat $PID_FILE)" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "[$ENV_ID] Log shipper stopped."
fi

# ── 2. Stop and remove containers ────────────────────────
docker ps -q --filter "label=sandbox.env=$ENV_ID" | xargs -r docker stop
docker ps -aq --filter "label=sandbox.env=$ENV_ID" | xargs -r docker rm
echo "[$ENV_ID] Containers removed."

# ── 3. Remove network ────────────────────────────────────
docker network disconnect "$NETWORK" "$NGINX_CONTAINER" 2>/dev/null || true
docker network rm "$NETWORK" 2>/dev/null || true
echo "[$ENV_ID] Network removed."

# ── 4. Remove Nginx config and reload ────────────────────
rm -f "$NGINX_CONF"
docker exec "$NGINX_CONTAINER" nginx -s reload 2>/dev/null || true
echo "[$ENV_ID] Nginx route removed."

# ── 5. Archive logs ───────────────────────────────────────
if [[ -d "$LOG_DIR" ]]; then
  mkdir -p "$ARCHIVE_DIR"
  cp -r "$LOG_DIR/." "$ARCHIVE_DIR/"
  rm -rf "$LOG_DIR"
  echo "[$ENV_ID] Logs archived."
fi

# ── 6. Delete state file ──────────────────────────────────
rm -f "$STATE_FILE"

echo ""
echo "🗑️  Environment $ENV_ID destroyed."
