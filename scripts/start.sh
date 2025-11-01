#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/assert-running-in-bash.sh"

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/dotenv.sh"

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

echo ""
echo "--------------------------------------------------------------------------------"
echo " Start"
echo "--------------------------------------------------------------------------------"

# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-minikube-exists.sh" && {
	bash "${ROOT_DIR}/scripts/lib/assert-minikube-host-running.sh" || \
	bash "${ROOT_DIR}/scripts/lib/start-core.sh" || {
		echo "❌  Minikube '${PROFILE_NAME}' could not be started" >&2
		exit 2
	}
}

bash "${ROOT_DIR}/scripts/lib/view-n8n-urls.sh"
