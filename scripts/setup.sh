#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/dotenv.sh"

echo ""
echo "--------------------------------------------------------------------------------"
echo " Setup"
echo "--------------------------------------------------------------------------------"

K8S_BASE_DIR="${ROOT_DIR}/k8s/base"

if [ -z "${TUNNEL_TOKEN:-}" ]; then
    echo "🛑  Set a Cloudflare Tunnel token into the file named '.env.local'" >&2
    exit 1
fi

bash scripts/ensure-openssl-exists.sh

if [ -z "${DB_POSTGRESDB_PASSWORD:-}" ]; then
    DB_POSTGRESDB_PASSWORD="$(openssl rand -base64 18 | tr -d '=+/[:space:]' | head -c 20)"
    echo "🛑  Add following line into the file named '.env.local'" >&2
    echo "📌  DB_POSTGRESDB_PASSWORD=\"${DB_POSTGRESDB_PASSWORD}\"" >&2
    exit 2
fi
if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
    N8N_ENCRYPTION_KEY="$(openssl rand -base64 36 | tr -d '=+/[:space:]' | head -c 32)"
    echo "🛑  Add following line into the file named '.env.local'" >&2
    echo "📌  N8N_ENCRYPTION_KEY=\"${N8N_ENCRYPTION_KEY}\"" >&2
    exit 3
fi

bash scripts/create-certs.sh "${N8N_HOST}"

TLS_CERT_PATH="${K8S_BASE_DIR}/certificates/${N8N_HOST}.crt.pem"
TLS_KEY_PATH="${K8S_BASE_DIR}/certificates/${N8N_HOST}.key.pem"

bash scripts/ensure-minikube-exists.sh && {
    bash scripts/assert-minikube-host-running.sh "${PROFILE_NAME}" || \
    bash scripts/start-core.sh "${PROFILE_NAME}" || {
        echo "❌  Minikube '${PROFILE_NAME}' could not be started" >&2
        exit 4
    }
}

minikube -p "${PROFILE_NAME}" kubectl -- delete secret "n8n-secrets" >/dev/null 2>&1 || true
minikube -p "${PROFILE_NAME}" kubectl -- create secret generic "n8n-secrets" \
    --from-literal=N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL}" \
    --from-literal=N8N_TUNNEL_SUBDOMAIN="${N8N_TUNNEL_SUBDOMAIN}" \
    --from-literal=WEBHOOK_URL="${WEBHOOK_URL}" \
    --from-literal=TUNNEL_TOKEN="${TUNNEL_TOKEN}" \
    --from-literal=DB_POSTGRESDB_PASSWORD="${DB_POSTGRESDB_PASSWORD}" \
    --from-literal=N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY}"
minikube -p "${PROFILE_NAME}" kubectl -- delete secret "n8n-tls" >/dev/null 2>&1 || true
minikube -p "${PROFILE_NAME}" kubectl -- create secret tls "n8n-tls" \
    --cert="${TLS_CERT_PATH}" \
    --key="${TLS_KEY_PATH}"

minikube -p "${PROFILE_NAME}" kubectl -- apply -k "${K8S_BASE_DIR}"

if bash scripts/wait-for-ingress-webhook.sh "${PROFILE_NAME}"; then
    minikube -p "${PROFILE_NAME}" kubectl -- apply -f "${K8S_BASE_DIR}/ingress/n8n-ingress.yaml"
else
    echo "⚠️  Ingress controller webhook is not ready; skipping ingress deployment for now." >&2
    echo "    Apply ${K8S_BASE_DIR}/ingress/n8n-ingress.yaml once ingress-nginx is ready." >&2
fi

echo "🏃  Pods are being prepared..."
minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/postgres --timeout=300s
minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/n8n --timeout=300s

sudo bash scripts/add-host-entry.sh "${N8N_HOST}" "$(minikube -p "${PROFILE_NAME}" ip)"

echo ""
echo "👍  Setup completed."
bash scripts/view-n8n-urls.sh
