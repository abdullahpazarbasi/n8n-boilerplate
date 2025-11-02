#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "🛑  Provide at least one community node package name" >&2
    exit 2
fi

for package in "$@"; do
    echo ""
    echo "⏳  Installing community node package '${package}'..."
    if minikube -p "${PROFILE_NAME}" kubectl -- exec deploy/n8n -c n8n -- \
        /bin/sh -c "[ -f /home/node/.n8n/nodes/package.json ] && grep -q \"${package}\" /home/node/.n8n/nodes/package.json"; then
        echo "⚠️  '${package}' is already installed"
        continue
    fi

    minikube -p "${PROFILE_NAME}" kubectl -- exec deploy/n8n -c n8n -- /bin/sh -c "cd /home/node/.n8n/nodes && npm install ${package}"
    echo "✅  '${package}' installed"
done
