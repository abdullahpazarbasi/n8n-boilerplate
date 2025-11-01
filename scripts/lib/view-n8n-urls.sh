#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

if [ -z "${N8N_HOST:-}" ]; then
    echo "🛑  N8N_HOST is undefined" >&2
    exit 2
fi

NODE_URL="$(minikube -p "${PROFILE_NAME}" service n8n --url | head -n1 || true)"
echo "📌  Local URL:               https://${N8N_HOST}"
echo "📌  Tunnel Route Target URL: ${NODE_URL}"
