#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/dotenv.sh"

echo ""
echo "--------------------------------------------------------------------------------"
echo " Status"
echo "--------------------------------------------------------------------------------"

bash scripts/view-n8n-urls.sh
