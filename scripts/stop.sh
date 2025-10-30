#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/dotenv.sh"

echo ""
echo "--------------------------------------------------------------------------------"
echo " Stop"
echo "--------------------------------------------------------------------------------"

bash scripts/assert-minikube-host-running.sh "${PROFILE_NAME}" && \
minikube -p "${PROFILE_NAME}" stop
