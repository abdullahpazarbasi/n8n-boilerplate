#!/usr/bin/env bash

set -euo pipefail

if [ -z "${ROOT_DIR:-}" ]; then
    echo "🛑  ROOT_DIR is undefined" >&2
    exit 1
fi

docker build \
  -t "n8n:latest" \
  -f "${ROOT_DIR}/services/n8n/Dockerfile" \
  "${ROOT_DIR}/services/n8n"
