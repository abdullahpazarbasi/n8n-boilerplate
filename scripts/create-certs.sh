#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="$1"

if [ -z "$PROFILE_NAME" ]; then
    echo "Usage: $0 <minikube-profile>"
    exit 1
fi

cd "$(dirname "$0")/.."

HOSTNAME="$PROFILE_NAME.local"
KEY_FILE_NAME="$HOSTNAME.key.pem"
CRT_FILE_NAME="$HOSTNAME.crt.pem"
CERTIFICATE_DIR="$(pwd)/k8s/base/certificates"
KEY_FILE_PATH="$CERTIFICATE_DIR/$KEY_FILE_NAME"
CRT_FILE_PATH="$CERTIFICATE_DIR/$CRT_FILE_NAME"

mkdir -p "$CERTIFICATE_DIR"
if [ ! -f "$KEY_FILE_PATH" ] || [ ! -f "$CRT_FILE_PATH" ]; then
    bash scripts/install-mkcert.sh && \
    mkcert "$HOSTNAME" && \
    mv "$HOSTNAME.pem" "$CRT_FILE_PATH" && \
    mv "$HOSTNAME-key.pem" "$KEY_FILE_PATH"
fi
