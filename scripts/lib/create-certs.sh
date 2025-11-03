#!/usr/bin/env bash

set -euo pipefail

if [ -z "${ROOT_DIR:-}" ]; then
    echo "🛑  ROOT_DIR is undefined" >&2
    exit 1
fi

HOSTNAME="$1"

if [ -z "${HOSTNAME}" ]; then
    echo "⚠️  Usage: $0 <hostname>" >&2
    exit 2
fi

CERTIFICATE_DIR="${ROOT_DIR}/k8s/base/certificates"
mkdir -p "${CERTIFICATE_DIR}"

KEY_FILE_NAME="${HOSTNAME}.key.pem"
CRT_FILE_NAME="${HOSTNAME}.crt.pem"
KEY_FILE_PATH="${CERTIFICATE_DIR}/${KEY_FILE_NAME}"
CRT_FILE_PATH="${CERTIFICATE_DIR}/${CRT_FILE_NAME}"

if [ ! -f "${KEY_FILE_PATH}" ] || [ ! -f "${CRT_FILE_PATH}" ]; then
    bash "${ROOT_DIR}/scripts/lib/ensure-mkcert-exists.sh" && \
    mkcert "${HOSTNAME}" && \
    mv "${HOSTNAME}-key.pem" "${KEY_FILE_PATH}" && \
    mv "${HOSTNAME}.pem" "${CRT_FILE_PATH}"
fi
