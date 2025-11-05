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
echo " ☢️  Cleaning Up"
echo "--------------------------------------------------------------------------------"

minikube -p "${PROFILE_NAME}" delete
rm -f "${ROOT_DIR}/k8s/base/certificates/*.pem"
rm -rf "${ROOT_DIR}/.cache/*"
