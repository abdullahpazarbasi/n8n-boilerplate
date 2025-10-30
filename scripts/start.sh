#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/dotenv.sh"

echo ""
echo "--------------------------------------------------------------------------------"
echo " Start"
echo "--------------------------------------------------------------------------------"

bash scripts/ensure-minikube-exists.sh && {
	bash scripts/assert-minikube-host-running.sh "${PROFILE_NAME}" || \
	bash scripts/start-core.sh "${PROFILE_NAME}" || {
		echo "❌  Minikube '${PROFILE_NAME}' could not be started" >&2
		exit 1
	}
}

bash scripts/view-n8n-urls.sh
