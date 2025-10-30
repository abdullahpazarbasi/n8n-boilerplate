#!/usr/bin/env bash

set -euo pipefail

NODE_URL="$(minikube -p "${PROFILE_NAME}" service n8n --url | head -n1 || true)"
echo "📌  Local URL:               https://${N8N_HOST}"
echo "📌  Tunnel Route Target URL: ${NODE_URL}"
