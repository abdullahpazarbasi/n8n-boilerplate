#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/dotenv.sh"

usage() {
  cat <<USAGE
Usage: $0 [-n <namespace>] [-o <output_dir>]

Options:
  -n    Kubernetes namespace (default: default)
  -o    Backup directory relative to project root (default: backup/credentials)

Examples:
  $0
  $0 -o backup/credentials
  $0 -n n8n -o backup/creds
USAGE
}

NAMESPACE="default"
BACKUP_DIR="backup/credentials"

while (($#)); do
  case "$1" in
    -n) NAMESPACE="$2"; shift 2;;
    -o) BACKUP_DIR="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[ERROR] Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

if [ -z "${PROFILE_NAME:-}" ]; then
  echo "🛑  PROFILE_NAME is undefined" >&2
  exit 1
fi

mkctl() { minikube -p "${PROFILE_NAME}" kubectl -- -n "${NAMESPACE}" "$@"; }

POD_NAME="$(mkctl get pods -l app=n8n -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [ -z "${POD_NAME}" ]; then
  echo "🛑  Could not find a Running n8n pod in namespace '${NAMESPACE}'" >&2
  exit 2
fi

OUTPUT_DIR="${ROOT_DIR}/${BACKUP_DIR}"
TMP_DIR="/tmp/n8n-credentials"

mkdir -p "${OUTPUT_DIR}"

echo "🚚  Exporting credentials from pod '${POD_NAME}' (namespace: ${NAMESPACE})..."
mkctl exec "${POD_NAME}" -- sh -lc "rm -rf '${TMP_DIR}' && mkdir -p '${TMP_DIR}' && n8n export:credentials --all --pretty --separate --decrypted --output='${TMP_DIR}'"

echo "💾  Copying export to host at '${OUTPUT_DIR}'..."
mkctl cp "${POD_NAME}:${TMP_DIR}" "${OUTPUT_DIR}"
mkctl exec "${POD_NAME}" -- rm -rf "${TMP_DIR}" >/dev/null 2>&1 || true

echo "✅  Credentials exported to '${OUTPUT_DIR}'."
