#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/dotenv.sh"

minikube -p "${PROFILE_NAME}" kubectl -- get pods -A
