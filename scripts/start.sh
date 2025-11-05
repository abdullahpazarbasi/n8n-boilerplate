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
echo " 🏁  Start"
echo "--------------------------------------------------------------------------------"

registry_container_name="registry"

if [ "$( docker inspect -f '{{.State.Running}}' "${registry_container_name}" 2>/dev/null )" != "true" ]; then
  	docker start "${registry_container_name}"
fi

set +e
bash "${ROOT_DIR}/scripts/lib/wait-for-image-registry-to-become-healthy.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
	echo "✅  The image registry is healthy"
else
	echo "❌  The image registry is not healthy" >&2
	exit 2
fi

################################################################################

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-minikube-exists.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  Minikube is not available (exit code: ${exit_code})" >&2
    exit 3
fi

set +e
bash "${ROOT_DIR}/scripts/lib/assert-minikube-host-running.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
	echo "⏳  Minikube '${PROFILE_NAME}' is being started (exit code: ${exit_code})..."
	set +e
    bash "${ROOT_DIR}/scripts/lib/start-minikube-cluster.sh"
    exit_code=$?
	set -e
    if [ $exit_code -ne 0 ]; then
        echo "🛑  Minikube '${PROFILE_NAME}' could not be started (exit code: ${exit_code})" >&2
        exit 4
    fi
fi

set +e
# shellcheck disable=SC2097,SC2098
host_IP="$( ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/resolve-host-ip.sh" )"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
    echo "✅  Host IP resolved: ${host_IP}"
else
    echo "🛑  Host IP could not be resolved (exit code: ${exit_code})" >&2
    exit 5
fi

set +e
bash "${ROOT_DIR}/scripts/add-image-registry-host-entry-in-minikube.sh" "${host_IP}"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
    echo "✅  The image registry hostname is registered"
else
    echo "🛑  The image registry hostname could not be registered (exit code: ${exit_code})" >&2
    exit 6
fi

set +e
bash "${ROOT_DIR}/scripts/lib/trust-in-ca-for-image-registry.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
    echo "✅  Minikube '${PROFILE_NAME}' now trusts the root CA"
else
    echo "🛑  Minikube '${PROFILE_NAME}' could not trust in root CA (exit code: ${exit_code})" >&2
    exit 7
fi

################################################################################

set +e
bash "${ROOT_DIR}/scripts/lib/wait-for-cluster-to-become-healthy.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
	echo "👮  Minikube '$PROFILE_NAME' is ready"
else
    echo "🛑  Minikube '${PROFILE_NAME}' is not ready (exit code: ${exit_code})" >&2
    exit 8
fi

bash "${ROOT_DIR}/scripts/lib/view-n8n-urls.sh"
echo "👌  Started."
