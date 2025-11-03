#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

if [ "$( minikube -p "${PROFILE_NAME}" status --format '{{.Host}}' )" != "Running" ]; then
    echo "⚠️   Minikube '${PROFILE_NAME}' is not running"
    exit 2
fi
