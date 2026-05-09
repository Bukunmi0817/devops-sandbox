#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$ROOT_DIR/.env"

# ── Arguments ────────────────────────────────────────────
ENV_ID=""
MODE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV_ID="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

[[ -z "$ENV_ID" ]] && echo "ERROR: --env required" && exit 1
[[ -z "$MODE" ]] && echo "ERROR: --mode required" && exit 1

# ── Load state ───────────────────────────────────────────
STATE_FILE="$ROOT_DIR/envs/$ENV_ID.json"
[[ ! -f "$STATE_FILE" ]] && echo "ERROR: Environment $ENV_ID not found" && exit 1

CONTAINER=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['container'])")
NETWORK=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['network'])")

# ── Safety guard ─────────────────────────────────────────
if [[ "$CONTAINER" == "$NGINX_CONTAINER" ]] || [[ "$CONTAINER" == *"daemon"* ]]; then
  echo "ERROR: Cannot simulate outage on Nginx or daemon container."
  exit 1
fi

echo "[$ENV_ID] Running outage simulation: $MODE"

case $MODE in
  crash)
    docker kill "$CONTAINER"
    echo "[$ENV_ID] Container killed. Health monitor should detect within 90s."
    ;;
  pause)
    docker pause "$CONTAINER"
    echo "[$ENV_ID] Container paused. Run --mode recover to unpause."
    ;;
  network)
    docker network disconnect "$NETWORK" "$CONTAINER"
    echo "[$ENV_ID] Container disconnected from network."
    ;;
  recover)
    # Try all recovery methods silently
    docker unpause "$CONTAINER" 2>/dev/null || true
    docker start "$CONTAINER" 2>/dev/null || true
    docker network connect "$NETWORK" "$CONTAINER" 2>/dev/null || true
    echo "[$ENV_ID] Recovery attempted."
    ;;
  *)
    echo "ERROR: Unknown mode '$MODE'. Use: crash, pause, network, recover"
    exit 1
    ;;
esac
