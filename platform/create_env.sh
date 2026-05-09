#!/usr/bin/env bash
set -euo pipefail

# ── Load config ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$ROOT_DIR/.env"

# ── Arguments ────────────────────────────────────────────
ENV_NAME="${1:?Usage: create_env.sh <name> [ttl_minutes]}"
TTL_MINUTES="${2:-30}"
TTL_SECONDS=$((TTL_MINUTES * 60))

# ── Generate unique ID ───────────────────────────────────
ENV_ID="env-$(openssl rand -hex 4)"

# ── Paths ────────────────────────────────────────────────
STATE_FILE="$ROOT_DIR/envs/$ENV_ID.json"
LOG_DIR="$ROOT_DIR/logs/$ENV_ID"
NGINX_CONF="$ROOT_DIR/nginx/conf.d/$ENV_ID.conf"

mkdir -p "$LOG_DIR"

echo "[$ENV_ID] Creating environment '$ENV_NAME' (TTL: ${TTL_MINUTES}m)..."

# ── 1. Create Docker network ─────────────────────────────
NETWORK_NAME="net-$ENV_ID"
docker network create "$NETWORK_NAME"
echo "[$ENV_ID] Network created."

# ── 2. Build image if needed ─────────────────────────────
if ! docker image inspect sandbox-demo-app &>/dev/null; then
  echo "[$ENV_ID] Building demo app image..."
  docker build -t sandbox-demo-app "$ROOT_DIR/demo-app"
fi

# ── 3. Start app container ───────────────────────────────
CONTAINER_NAME="app-$ENV_ID"
docker run -d \
  --name "$CONTAINER_NAME" \
  --network "$NETWORK_NAME" \
  --label "sandbox.env=$ENV_ID" \
  -e ENV_ID="$ENV_ID" \
  -e ENV_NAME="$ENV_NAME" \
  sandbox-demo-app

echo "[$ENV_ID] Container started."

# ── 4. Connect Nginx to env network ──────────────────────
docker network connect "$NETWORK_NAME" "$NGINX_CONTAINER" 2>/dev/null || true

# ── 5. Write Nginx config ────────────────────────────────
cat > "$NGINX_CONF" << NGINX
server {
    listen 80;
    server_name $ENV_ID.$BASE_DOMAIN;

    location / {
        proxy_pass http://$CONTAINER_NAME:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINX

docker exec "$NGINX_CONTAINER" nginx -s reload
echo "[$ENV_ID] Nginx route registered."

# ── 6. Start log shipping ────────────────────────────────
docker logs -f "$CONTAINER_NAME" >> "$LOG_DIR/app.log" 2>&1 &
echo $! > "$LOG_DIR/log_shipper.pid"
echo "[$ENV_ID] Log shipper started."

# ── 7. Write state file atomically ───────────────────────
CREATED_AT=$(date +%s)
EXPIRES_AT=$((CREATED_AT + TTL_SECONDS))

TEMP_STATE=$(mktemp)
cat > "$TEMP_STATE" << JSON
{
  "id": "$ENV_ID",
  "name": "$ENV_NAME",
  "container": "$CONTAINER_NAME",
  "network": "$NETWORK_NAME",
  "created_at": $CREATED_AT,
  "ttl_seconds": $TTL_SECONDS,
  "expires_at": $EXPIRES_AT,
  "status": "running"
}
JSON
mv "$TEMP_STATE" "$STATE_FILE"
echo "[$ENV_ID] State file written."

# ── Done ─────────────────────────────────────────────────
echo ""
echo "✅ Environment ready!"
echo "   ID:  $ENV_ID"
echo "   URL: http://$ENV_ID.$BASE_DOMAIN"
echo "   TTL: ${TTL_MINUTES} minutes"
