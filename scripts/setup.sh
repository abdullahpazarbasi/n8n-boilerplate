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
echo " 🏗️  Setup"
echo "--------------------------------------------------------------------------------"

K8S_BASE_DIR="${ROOT_DIR}/k8s/base"
K8S_LOCAL_DIR="${ROOT_DIR}/k8s/overlays/local"

if [ ! -f "${ROOT_DIR}/.env.local" ]; then
	cp "${ROOT_DIR}/.env.local.dist" "${ROOT_DIR}/.env.local"
fi

if [ -z "${TUNNEL_TOKEN:-}" ]; then
    echo "🛑  Set a Cloudflare Tunnel token into '${ROOT_DIR}/.env.local'" >&2
    exit 2
fi

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-openssl-exists.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  openssl is not available (exit code: ${exit_code})" >&2
    exit 3
fi

if [ -z "${DB_POSTGRESDB_PASSWORD:-}" ]; then
    DB_POSTGRESDB_PASSWORD="$(openssl rand -base64 18 | tr -d '=+/[:space:]' | head -c 20)"
    echo "🛑  Add following line into the file named '.env.local'" >&2
    echo "📌  DB_POSTGRESDB_PASSWORD=\"${DB_POSTGRESDB_PASSWORD}\"" >&2
    exit 4
fi
if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
    N8N_ENCRYPTION_KEY="$(openssl rand -base64 36 | tr -d '=+/[:space:]' | head -c 32)"
    echo "🛑  Add following line into the file named '.env.local'" >&2
    echo "📌  N8N_ENCRYPTION_KEY=\"${N8N_ENCRYPTION_KEY}\"" >&2
    exit 5
fi

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-cluster-tls-certificates-exist.sh" "${N8N_HOST}"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  TLS certificates could not be created (exit code: ${exit_code})" >&2
    exit 6
fi

################################################################################

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-docker-exists.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  Docker is not available (exit code: ${exit_code})" >&2
    exit 7
fi

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/build-n8n-image.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  n8n image could not be built (exit code: ${exit_code})" >&2
    exit 8
fi

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/build-postgres-image.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  postgres image could not be built (exit code: ${exit_code})" >&2
    exit 9
fi

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/register-n8n-image.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  n8n image could not be registered (exit code: ${exit_code})" >&2
    exit 10
fi

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/register-postgres-image.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  postgres image could not be registered (exit code: ${exit_code})" >&2
    exit 11
fi

################################################################################

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-minikube-exists.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  Minikube is not available (exit code: ${exit_code})" >&2
    exit 12
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
        exit 13
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
    exit 14
fi

set +e
bash "${ROOT_DIR}/scripts/add-image-registry-host-entry-in-minikube.sh" "${host_IP}"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
    echo "✅  The image registry hostname is registered"
else
    echo "🛑  The image registry hostname could not be registered (exit code: ${exit_code})" >&2
    exit 15
fi

set +e
bash "${ROOT_DIR}/scripts/lib/trust-in-ca-for-image-registry.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
    echo "✅  Minikube '${PROFILE_NAME}' now trusts the root CA"
else
    echo "🛑  Minikube '${PROFILE_NAME}' could not trust in root CA (exit code: ${exit_code})" >&2
    exit 16
fi

################################################################################

minikube -p "${PROFILE_NAME}" kubectl -- delete secret "n8n-secrets" >/dev/null 2>&1 || true
minikube -p "${PROFILE_NAME}" kubectl -- create secret generic "n8n-secrets" \
    --from-literal=N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL}" \
    --from-literal=N8N_TUNNEL_SUBDOMAIN="${N8N_TUNNEL_SUBDOMAIN}" \
    --from-literal=WEBHOOK_URL="${WEBHOOK_URL}" \
    --from-literal=TUNNEL_TOKEN="${TUNNEL_TOKEN}" \
    --from-literal=DB_POSTGRESDB_PASSWORD="${DB_POSTGRESDB_PASSWORD}" \
    --from-literal=N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY}"

minikube -p "${PROFILE_NAME}" kubectl -- apply -k "${K8S_LOCAL_DIR}"

set +e
bash "${ROOT_DIR}/scripts/lib/wait-for-ingress-webhook-to-become-healthy.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
	echo "⏳  Ingress manifest is being applied..."
    minikube -p "${PROFILE_NAME}" kubectl -- apply -f "${K8S_BASE_DIR}/ingress/n8n-ingress.yaml"
else
	echo ""
	echo "⚠️   Apply ingress manifest manually by making run the command below:"
	echo ""
	echo "minikube -p \"${PROFILE_NAME}\" kubectl -- apply -f \"${K8S_BASE_DIR}/ingress/n8n-ingress.yaml\""
	echo ""
fi

################################################################################

sudo bash "${ROOT_DIR}/scripts/add-host-entry-in-host.sh" "${N8N_HOST}" "$(minikube -p "${PROFILE_NAME}" ip)"

################################################################################

minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/postgres --timeout=300s
minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/n8n --timeout=300s

set +e
bash "${ROOT_DIR}/scripts/lib/wait-for-cluster-to-become-healthy.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
	echo "👮  Minikube '$PROFILE_NAME' is ready"
else
    echo "🛑  Minikube '${PROFILE_NAME}' is not ready (exit code: ${exit_code})" >&2
    exit 17
fi

bash "${ROOT_DIR}/scripts/lib/view-n8n-urls.sh"
echo "👌  Setup completed."
