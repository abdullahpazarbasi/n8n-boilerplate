#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/dotenv.sh"

usage() {
  cat <<USAGE
Usage: $0 [-n <namespace>] [-s <source_path>]

Options:
  -n    Kubernetes namespace (default: default)
  -s    Source path for credentials (file or directory, default: backup/credentials)

Examples:
  $0
  $0 -s backup/credentials
  $0 -n n8n -s backup/credentials/creds.json
USAGE
}

NAMESPACE="default"
SOURCE_PATH=""
DEFAULT_BACKUP_DIR="backup/credentials"

while (($#)); do
  case "$1" in
    -n) NAMESPACE="$2"; shift 2;;
    -s) SOURCE_PATH="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[ERROR] Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

if [ -z "${PROFILE_NAME:-}" ]; then
  echo "🛑  PROFILE_NAME is undefined" >&2
  exit 1
fi

if [ -z "${SOURCE_PATH}" ]; then
  if [ ! -d "${DEFAULT_BACKUP_DIR}" ]; then
    echo "🛑  No exports found at '${DEFAULT_BACKUP_DIR}'. Provide a source via -s." >&2
    exit 2
  fi
  SOURCE_PATH="${DEFAULT_BACKUP_DIR}"
fi

if [[ ! -f "${SOURCE_PATH}" && ! -d "${SOURCE_PATH}" ]]; then
  echo "🛑  Source path '${SOURCE_PATH}' does not exist." >&2
  exit 3
fi

mkctl() { minikube -p "${PROFILE_NAME}" kubectl -- -n "${NAMESPACE}" "$@"; }

POD_NAME="$(mkctl get pods -l app=n8n -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [ -z "${POD_NAME}" ]; then
  echo "🛑  Could not find a Running n8n pod in namespace '${NAMESPACE}'" >&2
  exit 4
fi

TMP_DIR="/tmp/n8n-credentials"

echo "📤  Copying credentials from host to pod '${POD_NAME}'..."
mkctl exec "${POD_NAME}" -- rm -rf "${TMP_DIR}" && mkctl exec "${POD_NAME}" -- mkdir -p "${TMP_DIR}"
mkctl cp "${SOURCE_PATH}" "${POD_NAME}:${TMP_DIR}"

echo "🚀  Importing credentials inside the pod..."
mkctl exec "${POD_NAME}" -- sh -lc "n8n import:credentials --separate --input='${TMP_DIR}'"
mkctl exec "${POD_NAME}" -- rm -rf "${TMP_DIR}" >/dev/null 2>&1 || true

echo "✅  Credentials imported from '${SOURCE_PATH}'."
