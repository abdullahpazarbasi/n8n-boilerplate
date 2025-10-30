#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="/usr/local/bin"
MKCERT_BIN="${BIN_DIR}/mkcert"

CURRENT_VERSION=""
if command -v mkcert > /dev/null 2>&1; then
    CURRENT_VERSION="$(mkcert --version | sed 's/v//')"
    echo "📦  Current mkcert version: v${CURRENT_VERSION}"
fi

LATEST_VERSION=$(curl -Ls "https://api.github.com/repos/FiloSottile/mkcert/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4 | sed 's/v//')
echo "🌐  Latest mkcert version: v${LATEST_VERSION}"

if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
    echo "✅  Up-to-date mkcert version is being used already"
    exit 0
fi

if ! command -v certutil > /dev/null 2>&1; then
    if [[ -f /etc/debian_version ]]; then
        sudo apt-get update && \
        sudo apt-get install -y libnss3-tools
    else
        echo "❗  Automatic mkcert installation not supported" >&2
        exit 1
    fi
fi

bash scripts/ensure-curl-exists.sh

echo "⬇️  Installing mkcert..."
tmp="$(mktemp)"
MKCERT_URL="https://github.com/FiloSottile/mkcert/releases/download/v${LATEST_VERSION}/mkcert-v${LATEST_VERSION}-linux-amd64"
curl -fsSL -o "${tmp}" "${MKCERT_URL}"
chmod +x "${tmp}"
sudo mv "${tmp}" "${MKCERT_BIN}"

if [[ ! -d "${HOME}/.local/share/mkcert" ]]; then
    "${MKCERT_BIN}" -install
fi
