#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="$1"

if [ -z "$PROFILE_NAME" ]; then
    echo "Usage: $0 <minikube-profile>"
    exit 1
fi

cd "$(dirname "$0")/.."

if [ "$(minikube -p "$PROFILE_NAME" status --format '{{.Host}}')" != "Running" ]; then
    echo "❌  Minikube '$PROFILE_NAME' host is not running"
    exit 2
fi
