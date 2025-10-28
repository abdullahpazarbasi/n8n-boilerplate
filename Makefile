.DEFAULT_GOAL := setup
SHELL := /bin/bash

.PHONY: setup start stop logs-viewed restarted cleaned-up

setup:
	bash scripts/setup.sh

start:
	bash scripts/start.sh

stop:
	bash scripts/stop.sh

logs-viewed:
	minikube -p n8n logs

restarted:
	kubectl rollout restart deployment/n8n

cleaned-up:
	@echo "🔥 This will terminate everything 🔥 Continue? (y/N)"
	@read -r confirm && [[ $$confirm == "y" ]] && bash scripts/clean-up.sh || echo "Cleaning up cancelled"
