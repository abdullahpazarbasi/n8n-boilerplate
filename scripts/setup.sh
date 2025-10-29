#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="n8n"
POSTGRES_IMAGE="postgres:16-alpine"
N8N_IMAGE="n8nio/n8n:latest"
N8N_HOST_DEFAULT="n8n.local"
N8N_TIMEZONE="Europe/Istanbul"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${REPO_ROOT}/bin"
MANIFEST_DIR="${REPO_ROOT}/out/manifests"
K8S_BASE_DIR="${REPO_ROOT}/k8s/base"
TLS_SECRET_NAME="n8n-tls"

mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

cd "$REPO_ROOT"

echo ""
echo "--------------------------------------------------------------------------------"
echo " Setup"
echo "--------------------------------------------------------------------------------"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' does not exist"; exit 1; }; }

ensure_minikube() {
    if command -v minikube >/dev/null 2>&1; then
        return 0
    fi

    local target="$BIN_DIR/minikube"
    if [ -x "$target" ]; then
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "⚠️  'minikube' is not available and 'curl' is required to download it." >&2
        return 1
    fi

    echo "⬇️  Downloading minikube binary..."
    local tmp
    tmp="$(mktemp)"
    if curl -fsSL "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" -o "$tmp"; then
        install -m 0755 "$tmp" "$target"
        rm -f "$tmp"
        hash -r
        return 0
    else
        echo "⚠️  Failed to download the minikube binary." >&2
        rm -f "$tmp"
        return 1
    fi
}

wait_for_ingress_webhook() {
    local profile="$1"
    local namespace="ingress-nginx"
    local svc="ingress-nginx-controller-admission"
    local timeout_seconds=180
    local interval=5
    local waited=0

    if ! minikube -p "$profile" kubectl -- -n "$namespace" wait --for=condition=Available deployment/ingress-nginx-controller --timeout="${timeout_seconds}s" >/dev/null 2>&1; then
        return 1
    fi

    while [ "$waited" -lt "$timeout_seconds" ]; do
        if minikube -p "$profile" kubectl -- -n "$namespace" get endpoints "$svc" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | grep -qE '\S'; then
            return 0
        fi

        sleep "$interval"
        waited=$((waited + interval))
    done

    return 1
}

need openssl

MINIKUBE_READY=0
if ensure_minikube; then
    MINIKUBE_READY=1
else
    echo "⚠️  Continuing without a local minikube binary."
fi

MOCK_MODE=1
if [ "$MINIKUBE_READY" -eq 1 ]; then
    if bash scripts/start.sh; then
        MOCK_MODE=0
    else
        echo "⚠️  Minikube could not be started. Falling back to manifest generation." >&2
    fi
else
    echo "ℹ️  Falling back to manifest generation because minikube is unavailable." >&2
fi

PG_PASS="$(openssl rand -base64 18 | tr -d '=+/[:space:]' | head -c 20)"
N8N_ENCRYPTION_KEY="$(openssl rand -base64 36 | tr -d '=+/[:space:]' | head -c 32)"

CERT_HOST="${N8N_HOST_DEFAULT}"
bash scripts/create-certs.sh "${CERT_HOST}"

TLS_CERT_PATH="${K8S_BASE_DIR}/certificates/${CERT_HOST}.crt.pem"
TLS_KEY_PATH="${K8S_BASE_DIR}/certificates/${CERT_HOST}.key.pem"

if [ "$MOCK_MODE" -eq 0 ]; then
    minikube -p "${PROFILE_NAME}" kubectl -- delete secret "n8n-secrets" >/dev/null 2>&1 || true
    minikube -p "${PROFILE_NAME}" kubectl -- create secret generic "n8n-secrets" \
      --from-literal=POSTGRES_PASSWORD="${PG_PASS}" \
      --from-literal=N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY}"
    minikube -p "${PROFILE_NAME}" kubectl -- delete secret "${TLS_SECRET_NAME}" >/dev/null 2>&1 || true
    minikube -p "${PROFILE_NAME}" kubectl -- create secret tls "${TLS_SECRET_NAME}" \
      --cert="${TLS_CERT_PATH}" \
      --key="${TLS_KEY_PATH}"

    minikube -p "${PROFILE_NAME}" kubectl -- apply -k "${K8S_BASE_DIR}"

    if wait_for_ingress_webhook "${PROFILE_NAME}"; then
        minikube -p "${PROFILE_NAME}" kubectl -- apply -f "${K8S_BASE_DIR}/ingress/n8n-ingress.yaml"
    else
        echo "⚠️  Ingress controller webhook is not ready; skipping ingress deployment for now." >&2
        echo "    Apply ${K8S_BASE_DIR}/ingress/n8n-ingress.yaml once ingress-nginx is ready." >&2
    fi

    echo "🏃  Pods are being prepared..."
    minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/postgres --timeout=120s
    minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/n8n --timeout=300s

    sudo bash scripts/add-host-entry.sh "${N8N_HOST_DEFAULT}" "$(minikube -p "${PROFILE_NAME}" ip)"

    echo ""
    echo "👍  Setup completed."
    NODE_URL="$(minikube -p "${PROFILE_NAME}" service n8n --url | head -n1 || true)"
    echo "    with NodePort: ${NODE_URL:-http://$(minikube -p "${PROFILE_NAME}" ip)}:30080"
    echo "    with Ingress:  https://${N8N_HOST_DEFAULT}"
else
    echo ""
    echo "🗂️  Generating Kubernetes manifests instead of applying them."
    rm -rf "$MANIFEST_DIR"
    mkdir -p "$MANIFEST_DIR"

    b64() { printf '%s' "$1" | base64 | tr -d '\n'; }
    file_b64() { base64 <"$1" | tr -d '\n'; }

    while IFS= read -r -d '' file; do
        rel_path="${file#${K8S_BASE_DIR}/}"
        dest_path="${MANIFEST_DIR}/${rel_path}"
        mkdir -p "$(dirname "$dest_path")"
        cp "$file" "$dest_path"
    done < <(find "$K8S_BASE_DIR" -type f -name '*.yaml' -print0)

    mkdir -p "$MANIFEST_DIR/secrets"
    cat >"$MANIFEST_DIR/secrets/n8n-secrets.yaml" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: n8n-secrets
type: Opaque
data:
  POSTGRES_PASSWORD: "$(b64 "$PG_PASS")"
  N8N_ENCRYPTION_KEY: "$(b64 "$N8N_ENCRYPTION_KEY")"
YAML

    cat >"$MANIFEST_DIR/secrets/n8n-tls.yaml" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: ${TLS_SECRET_NAME}
type: kubernetes.io/tls
data:
  tls.crt: "$(file_b64 "$TLS_CERT_PATH")"
  tls.key: "$(file_b64 "$TLS_KEY_PATH")"
YAML

    echo ""
    echo "👍  Setup (manifests only) completed."
    echo "    Generated manifests are located in: ${MANIFEST_DIR}"
    echo "    Apply secrets first with: kubectl apply -f ${MANIFEST_DIR}/secrets"
    echo "    Apply core resources with: kubectl apply -k ${MANIFEST_DIR}"
    echo "    Apply ingress with:       kubectl apply -f ${MANIFEST_DIR}/ingress/n8n-ingress.yaml"
    echo "    Expected NodePort: http://localhost:30080"
    echo "    Expected Ingress:  https://${N8N_HOST_DEFAULT}"
fi

echo "📌  DB info:"
echo "      DB: n8n  USER: n8n  PASS: ${PG_PASS}"
