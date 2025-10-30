.DEFAULT_GOAL := setup
SHELL := /bin/bash

.PHONY: setup start all-pods-listed stop status-checked n8n-logs-viewed n8n-shell-connected postgres-logs-viewed postgres-shell-connected logs-viewed cleaned-up

setup:
	bash scripts/setup.sh

start:
	bash scripts/start.sh

all-pods-listed:
	bash scripts/list-all-pods.sh

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

logs-viewed:
	minikube -p n8n logs

cleaned-up:
	@echo "🔥 This will terminate everything 🔥 Continue? (y/N)"
	@read -r confirm && [[ $$confirm == "y" ]] && bash scripts/clean-up.sh || echo "Cleaning up cancelled"
