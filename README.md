# devops-sandbox

A self-service platform for spinning up isolated temporary environments, simulating outages, and monitoring health — all on a single machine.

## Prerequisites

- Docker Desktop
- Python 3.9+
- make

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/devops-sandbox.git
cd devops-sandbox

# 2. Start Nginx
docker compose up -d

# 3. Build the demo app image
docker build -t sandbox-demo-app demo-app/

# 4. Start the API and cleanup daemon
nohup bash platform/cleanup_daemon.sh >> logs/cleanup.log 2>&1 &
nohup python3 platform/api.py >> logs/api.log 2>&1 &

# 5. Create your first environment
bash platform/create_env.sh myapp 30
```

## Demo Walkthrough

### 1. Create an environment
```bash
bash platform/create_env.sh myapp 30
# Returns: URL and env ID
```

### 2. Hit the app
```bash
curl http://localhost/
curl http://localhost/health
```

### 3. Check health status
```bash
make health
```

### 4. Simulate an outage
```bash
bash platform/simulate_outage.sh --env env-abc123 --mode pause
```

### 5. Recover
```bash
bash platform/simulate_outage.sh --env env-abc123 --mode recover
```

### 6. Destroy manually
```bash
bash platform/destroy_env.sh env-abc123
```

### 7. Auto-destroy (create with short TTL and wait)
```bash
bash platform/create_env.sh shortlived 1
# Wait 60 seconds — cleanup daemon destroys it automatically
cat logs/cleanup.log
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /envs | Create environment |
| GET | /envs | List all environments |
| DELETE | /envs/:id | Destroy environment |
| GET | /envs/:id/logs | Last 100 lines of app log |
| GET | /envs/:id/health | Last 10 health checks |
| POST | /envs/:id/outage | Trigger outage simulation |

## Makefile Commands

```bash
make up                        # Start everything
make down                      # Stop everything
make create                    # Create new environment
make destroy ENV=env-abc123    # Destroy specific environment
make logs ENV=env-abc123       # Tail environment logs
make health                    # Show all health statuses
make simulate ENV=env-abc123 MODE=pause  # Run simulation
make clean                     # Wipe all state and logs
```

## Known Limitations

- Environments use localhost routing — works on a single machine only
- No authentication on the API
- Log shipper uses simple approach (docker logs -f) not a proper aggregator
- Health monitor requires manual start — not auto-started with make up


