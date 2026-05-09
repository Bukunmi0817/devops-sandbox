#!/usr/bin/env python3
import json
import os
import time
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime

ROOT_DIR = Path(__file__).parent.parent
ENVS_DIR = ROOT_DIR / "envs"
LOGS_DIR = ROOT_DIR / "logs"
POLL_INTERVAL = 30
FAILURE_THRESHOLD = 3

def log(env_id, message):
    log_file = LOGS_DIR / env_id / "health.log"
    log_file.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {message}\n"
    with open(log_file, "a") as f:
        f.write(line)
    print(line.strip())

def check_health(env_id, container_name):
    url = f"http://localhost/{env_id}/health"
    start = time.time()
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            latency = round((time.time() - start) * 1000)
            return resp.status, latency
    except urllib.error.HTTPError as e:
        latency = round((time.time() - start) * 1000)
        return e.code, latency
    except Exception:
        latency = round((time.time() - start) * 1000)
        return 0, latency

def update_status(state_file, status):
    with open(state_file) as f:
        data = json.load(f)
    data["status"] = status
    tmp = str(state_file) + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, state_file)

def report():
    state_files = list(ENVS_DIR.glob("*.json"))
    if not state_files:
        print("No active environments.")
        return
    for sf in state_files:
        with open(sf) as f:
            data = json.load(f)
        health_log = LOGS_DIR / data["id"] / "health.log"
        last = "No checks yet"
        if health_log.exists():
            lines = health_log.read_text().strip().splitlines()
            last = lines[-1] if lines else "No checks yet"
        print(f"  {data['id']} ({data['name']}) — status: {data['status']}")
        print(f"    Last check: {last}")

def poll():
    failure_counts = {}
    print("Health poller started.")
    while True:
        state_files = list(ENVS_DIR.glob("*.json"))
        for sf in state_files:
            with open(sf) as f:
                data = json.load(f)
            env_id = data["id"]
            container = data["container"]
            status_code, latency = check_health(env_id, container)
            if status_code == 200:
                failure_counts[env_id] = 0
                log(env_id, f"OK — HTTP {status_code} — {latency}ms")
                if data["status"] == "degraded":
                    update_status(sf, "running")
            else:
                failure_counts[env_id] = failure_counts.get(env_id, 0) + 1
                count = failure_counts[env_id]
                log(env_id, f"FAIL — HTTP {status_code} — {latency}ms — failures: {count}")
                if count >= FAILURE_THRESHOLD:
                    print(f"⚠️  WARNING: {env_id} is degraded ({count} consecutive failures)")
                    update_status(sf, "degraded")
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--report":
        report()
    else:
        poll()
