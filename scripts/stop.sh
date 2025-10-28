#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="n8n"

cd "$(dirname "$0")/.."

echo ""
echo "--------------------------------------------------------------------------------"
echo " Stop"
echo "--------------------------------------------------------------------------------"
bash scripts/assert-minikube-host-running.sh "$PROFILE_NAME" && \
minikube -p "$PROFILE_NAME" stop
