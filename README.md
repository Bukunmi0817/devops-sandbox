# devops-sandbox

A self-service platform for spinning up isolated temporary environments, simulating outages, and monitoring health — all on a single machine.

## Architecture

```
                   +-------------------------------------+
                   |           Your Machine              |
                   |                                     |
     HTTP :80      |   +-------------+                  |
User ----------->  |   |    Nginx    |                  |
                   |   |  (router)   |                  |
                   |   +------+------+                  |
                   |          | proxy_pass               |
                   |   +------v------+  +------------+  |
                   |   | app-env-    |  | app-env-   |  |
                   |   | abc123:5000 |  | def456:5000|  |
                   |   +-------------+  +------------+  |
                   |                                     |
                   |   +-------------+  +------------+  |
                   |   |   Cleanup   |  | API :8080  |  |
                   |   |   Daemon    |  |            |  |
                   |   +-------------+  +------------+  |
                   +-------------------------------------+
```

## Prerequisites

- Docker Desktop (running)
- Python 3.9+
- make

## Quick Start — One Command

```bash
make up
```

That single command does everything:
- Builds the demo app Docker image
- Starts Nginx on port 80
- Starts the control API on port 8080
- Starts the cleanup daemon in the background

Then create your first environment:

```bash
make create
```

## Full Demo Walkthrough

### 1. Start the platform
```bash
make up
```

### 2. Create an environment
```bash
make create
# Enter name: myapp
# Enter TTL: 30
```

### 3. Save the environment ID
```bash
TEST1=$(ls envs/ | sed 's/\.json//')
echo $TEST1
```

### 4. Hit the app
```bash
curl http://localhost/
curl http://localhost/health
```

### 5. List environments via API
```bash
curl http://localhost:8080/envs
```

### 6. View logs via API
```bash
curl http://localhost:8080/envs/$TEST1/logs
```

### 7. Check health status
```bash
make health
```

### 8. Simulate an outage
```bash
make simulate ENV=$TEST1 MODE=pause
```

### 9. Confirm it is paused
```bash
docker ps
```

### 10. Recover
```bash
make simulate ENV=$TEST1 MODE=recover
```

### 11. Auto-destroy demo
```bash
bash platform/create_env.sh shortlived 0
# Wait 15 seconds
cat logs/cleanup.log | tail -15
```

### 12. Stop everything
```bash
make down
```

## Makefile Commands

| Command | Description |
|---------|-------------|
| make up | Start everything - Nginx, API, cleanup daemon |
| make down | Stop everything cleanly |
| make create | Create a new environment (prompts for name and TTL) |
| make destroy ENV=env-abc123 | Destroy a specific environment |
| make logs ENV=env-abc123 | Tail environment logs |
| make health | Show all environment health statuses |
| make simulate ENV=env-abc123 MODE=pause | Run outage simulation |
| make clean | Wipe all state and logs |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /envs | Create environment |
| GET | /envs | List all environments + TTL remaining |
| DELETE | /envs/:id | Destroy environment |
| GET | /envs/:id/logs | Last 100 lines of app log |
| GET | /envs/:id/health | Last 10 health checks |
| POST | /envs/:id/outage | Trigger outage simulation |

## Outage Simulation Modes

| Mode | What it does |
|------|-------------|
| crash | Kills the container immediately |
| pause | Freezes the container - stops responding |
| network | Disconnects container from network |
| recover | Restores whatever was broken |

## Platform Rules

- Maximum TTL is 30 minutes - anything higher is automatically capped
- Minimum TTL is 0 - uses 10 seconds for demo purposes
- Cleanup daemon checks every 10 seconds for expired environments
- Logs are archived automatically on environment destroy
- Nginx routes update instantly without restart

## Known Limitations

- Environments use localhost routing - works on a single machine only
- No authentication on the API
- Log shipper uses simple approach (docker logs -f) not a proper aggregator
- Health monitor requires manual start for continuous polling
