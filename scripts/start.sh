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

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-minikube-exists.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  Minikube is not available (exit code: ${exit_code})" >&2
    exit 2
fi

set +e
bash "${ROOT_DIR}/scripts/lib/assert-minikube-host-running.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
	echo "⏳  Minikube '${PROFILE_NAME}' is being started (exit code: ${exit_code})..."
	set +e
    bash "${ROOT_DIR}/scripts/lib/start-core.sh"
    exit_code=$?
	set -e
    if [ $exit_code -ne 0 ]; then
        echo "🛑  Minikube '${PROFILE_NAME}' could not be started (exit code: ${exit_code})" >&2
        exit 3
    fi
fi

bash "${ROOT_DIR}/scripts/lib/view-n8n-urls.sh"
