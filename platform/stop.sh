#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Stopping all environments..."
for f in "$ROOT_DIR/envs/"*.json; do
  [ -f "$f" ] || continue
  ENV_ID=$(python3 -c "import json; print(json.load(open('$f'))['id'])")
  bash "$SCRIPT_DIR/destroy_env.sh" "$ENV_ID"
done

echo "Stopping all sandbox containers..."
docker ps -q --filter "name=app-env-" | xargs -r docker rm -f
docker network ls --filter "name=net-env-" -q | xargs -r docker network rm

echo "Stopping Nginx..."
docker compose -f "$ROOT_DIR/docker-compose.yml" down

echo "Killing daemon and API..."
pkill -f cleanup_daemon.sh || true
pkill -f api.py || true

echo "Cleaning up configs..."
rm -f "$ROOT_DIR/nginx/conf.d/"*.conf
rm -f "$ROOT_DIR/envs/"*.json

echo "All done. Everything stopped."
