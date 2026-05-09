ifneq (,$(wildcard ./.env))
  include .env
  export
endif

.PHONY: up down create destroy logs health simulate clean

up:
	@docker compose -f docker-compose.yml up -d
	@nohup bash platform/cleanup_daemon.sh >> logs/cleanup.log 2>&1 &
	@nohup python3 platform/api.py >> logs/api.log 2>&1 &
	@echo Platform is up.

down:
	@docker compose -f docker-compose.yml down
	@pkill -f cleanup_daemon.sh || true
	@pkill -f api.py || true

create:
	@bash platform/create_env.sh $(NAME) $(TTL)

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
	@echo Wiped.
