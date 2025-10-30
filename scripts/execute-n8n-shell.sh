#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/dotenv.sh"

minikube -p "${PROFILE_NAME}" kubectl -- exec -it "$(minikube -p "${PROFILE_NAME}" kubectl -- get pods -l app=n8n -o jsonpath='{.items[0].metadata.name}')" -- /bin/sh
