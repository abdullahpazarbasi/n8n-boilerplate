.DEFAULT_GOAL := setup
SHELL := /bin/bash

.PHONY: setup started stopped status-checked n8n-logs-viewed n8n-shell-connected ollama-logs-viewed ollama-shell-connected postgres-logs-viewed postgres-shell-connected qdrant-logs-viewed qdrant-shell-connected cleaned-up

setup:
	bash scripts/setup.sh

started:
	bash scripts/start.sh

stopped:
	bash scripts/stop.sh

status-checked:
	bash scripts/check-status.sh

n8n-logs-viewed:
	bash scripts/view-n8n-previous-log.sh

n8n-shell-connected:
	bash scripts/execute-n8n-shell.sh

ollama-logs-viewed:
	bash scripts/view-ollama-previous-log.sh

ollama-shell-connected:
	bash scripts/execute-ollama-shell.sh

postgres-logs-viewed:
	bash scripts/view-postgres-previous-log.sh

postgres-shell-connected:
	bash scripts/execute-postgres-shell.sh

qdrant-logs-viewed:
	bash scripts/view-qdrant-previous-log.sh

qdrant-shell-connected:
	bash scripts/execute-qdrant-shell.sh

cleaned-up:
	@echo "🔥 This will terminate everything 🔥 Continue? (y/N)"
	@read -r confirm && [[ $$confirm == "y" ]] && bash scripts/clean-up.sh || echo "Cleaning up cancelled"
