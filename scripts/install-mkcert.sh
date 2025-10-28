#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="/usr/local/bin"
MKCERT_BIN="$INSTALL_DIR/mkcert"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' does not exist"; exit 1; }; }

if ! need certutil; then
    if [[ -f /etc/debian_version ]]; then
        sudo apt-get update
        sudo apt-get install -y libnss3-tools
    else
        echo "Automatic mkcert installation not supported" >&2
        exit 1
    fi
fi

if [[ ! -x "${MKCERT_BIN}" ]]; then
    MKCERT_URL="https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    curl -fsSL -o /tmp/mkcert "${MKCERT_URL}"
    chmod +x /tmp/mkcert
    sudo mv /tmp/mkcert "${MKCERT_BIN}"
fi

if [[ ! -d "${HOME}/.local/share/mkcert" ]]; then
    "${MKCERT_BIN}" -install
fi
