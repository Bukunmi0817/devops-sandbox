ifneq (,$(wildcard ./.env))
  include .env
  export
endif

.PHONY: up down create destroy logs health simulate clean

up:
	@echo "Building demo app image..."
	@docker build -t sandbox-demo-app demo-app/ -q
	@echo "Starting Nginx..."
	@docker compose -f docker-compose.yml up -d
	@echo "Starting API..."
	@nohup python3 platform/api.py >> logs/api.log 2>&1 &
	@echo "Starting cleanup daemon..."
	@nohup bash platform/cleanup_daemon.sh >> logs/cleanup.log 2>&1 &
	@echo ""
	@echo "Platform is up. Try: make create"

down:
	@bash platform/stop.sh

create:
	@bash -c 'read -p "Env name: " name; read -p "TTL in minutes (default 30): " ttl; ttl=$${ttl:-30}; bash platform/create_env.sh "$$name" "$$ttl"'

destroy:
	@bash platform/destroy_env.sh $(ENV)

logs:
	@tail -f logs/$(ENV)/app.log

health:
	@python3 monitor/health_poller.py --report

simulate:
	@bash platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

clean:
	@rm -rf logs/* envs/*
	@rm -f nginx/conf.d/*.conf
	@echo "Wiped."
