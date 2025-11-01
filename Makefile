.DEFAULT_GOAL := setup
SHELL := /bin/bash

.PHONY: setup start stop status-checked n8n-logs-viewed n8n-shell-connected postgres-logs-viewed postgres-shell-connected cleaned-up

setup:
	bash scripts/setup.sh

start:
	bash scripts/start.sh

stop:
	bash scripts/stop.sh

status-checked:
	bash scripts/check-status.sh

n8n-logs-viewed:
	bash scripts/view-n8n-previous-log.sh

n8n-shell-connected:
	bash scripts/execute-n8n-shell.sh

postgres-logs-viewed:
	bash scripts/view-postgres-previous-log.sh

postgres-shell-connected:
	bash scripts/execute-postgres-shell.sh

cleaned-up:
	@echo "🔥 This will terminate everything 🔥 Continue? (y/N)"
	@read -r confirm && [[ $$confirm == "y" ]] && bash scripts/clean-up.sh || echo "Cleaning up cancelled"
