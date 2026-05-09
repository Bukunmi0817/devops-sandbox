#!/usr/bin/env python3
import json
import os
import subprocess
from pathlib import Path
from flask import Flask, jsonify, request

app = Flask(__name__)

ROOT_DIR = Path(__file__).parent.parent
ENVS_DIR = ROOT_DIR / "envs"
LOGS_DIR = ROOT_DIR / "logs"
PLATFORM_DIR = ROOT_DIR / "platform"

def load_state(env_id):
    sf = ENVS_DIR / f"{env_id}.json"
    if not sf.exists():
        return None
    with open(sf) as f:
        return json.load(f)

def all_envs():
    return [json.load(open(f)) for f in ENVS_DIR.glob("*.json")]

# ── POST /envs — create environment ──────────────────────
@app.route("/envs", methods=["POST"])
def create_env():
    body = request.json or {}
    name = body.get("name")
    ttl = body.get("ttl", 30)
    if not name:
        return jsonify({"error": "name is required"}), 400
    result = subprocess.run(
        ["bash", str(PLATFORM_DIR / "create_env.sh"), name, str(ttl)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    return jsonify({"message": result.stdout}), 201

# ── GET /envs — list all environments ────────────────────
@app.route("/envs", methods=["GET"])
def list_envs():
    import time
    envs = []
    for data in all_envs():
        ttl_remaining = max(0, data["expires_at"] - int(time.time()))
        envs.append({
            "id": data["id"],
            "name": data["name"],
            "status": data["status"],
            "ttl_remaining_seconds": ttl_remaining
        })
    return jsonify(envs)

# ── DELETE /envs/:id — destroy environment ────────────────
@app.route("/envs/<env_id>", methods=["DELETE"])
def destroy_env(env_id):
    if not load_state(env_id):
        return jsonify({"error": "Environment not found"}), 404
    result = subprocess.run(
        ["bash", str(PLATFORM_DIR / "destroy_env.sh"), env_id],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    return jsonify({"message": f"{env_id} destroyed."})

# ── GET /envs/:id/logs — last 100 lines of app.log ───────
@app.route("/envs/<env_id>/logs", methods=["GET"])
def get_logs(env_id):
    log_file = LOGS_DIR / env_id / "app.log"
    if not log_file.exists():
        return jsonify({"error": "No logs found"}), 404
    lines = log_file.read_text().splitlines()[-100:]
    return jsonify({"env_id": env_id, "logs": lines})

# ── GET /envs/:id/health — last 10 health checks ─────────
@app.route("/envs/<env_id>/health", methods=["GET"])
def get_health(env_id):
    health_file = LOGS_DIR / env_id / "health.log"
    if not health_file.exists():
        return jsonify({"error": "No health logs found"}), 404
    lines = health_file.read_text().splitlines()[-10:]
    return jsonify({"env_id": env_id, "health": lines})

# ── POST /envs/:id/outage — trigger simulation ────────────
@app.route("/envs/<env_id>/outage", methods=["POST"])
def outage(env_id):
    body = request.json or {}
    mode = body.get("mode")
    if not mode:
        return jsonify({"error": "mode is required"}), 400
    if not load_state(env_id):
        return jsonify({"error": "Environment not found"}), 404
    result = subprocess.run(
        ["bash", str(PLATFORM_DIR / "simulate_outage.sh"),
         "--env", env_id, "--mode", mode],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify({"error": result.stderr}), 500
    return jsonify({"message": result.stdout})

if __name__ == "__main__":
    port = int(os.environ.get("PLATFORM_PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
