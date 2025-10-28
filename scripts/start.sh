#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="n8n"

cd "$(dirname "$0")/.."

echo ""
echo "--------------------------------------------------------------------------------"
echo " Start"
echo "--------------------------------------------------------------------------------"
bash scripts/assert-minikube-host-running.sh "$PROFILE_NAME" || \
bash scripts/start-core.sh "$PROFILE_NAME" || {
    echo "❌  Minikube '$PROFILE_NAME' could not be started" >&2
    exit 1
}
