#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="/usr/local/bin"

CURRENT_VERSION=""
if command -v minikube > /dev/null 2>&1; then
    CURRENT_VERSION=$(minikube version --short | sed 's/v//')
    echo "📦  Current minikube version: v${CURRENT_VERSION}"
fi

LATEST_VERSION=$(curl -Ls "https://api.github.com/repos/kubernetes/minikube/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4 | sed 's/v//')
echo "🌐  Latest minikube version: v${LATEST_VERSION}"

if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
    echo "✅  Up-to-date minikube version is being used already"
    exit 0
fi

bash scripts/ensure-curl-exists.sh

echo "⬇️  Downloading minikube binary..."
tmp="$(mktemp)"
MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
if curl -fsSL -o "${tmp}" "${MINIKUBE_URL}"; then
	install -m 0755 "${tmp}" "${BIN_DIR}"
	rm -f "${tmp}"
	hash -r
	exit 0
else
	echo "❗  Failed to download the minikube binary." >&2
	rm -f "${tmp}"
	exit 1
fi
