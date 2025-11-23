#!/usr/bin/env bash

if [ -z "${ROOT_DIR:-}" ]; then
    echo "🛑  ROOT_DIR is undefined" >&2
    exit 1
fi

install_binary() {
    local src="$1"
    local dest="$2"

    if install -m 0755 "${src}" "${dest}" 2>/dev/null; then
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo install -m 0755 "${src}" "${dest}"
    else
        echo "🛑  Failed to install minikube binary into ${dest}. Try re-running the command with elevated permissions." >&2
        return 1
    fi
}

# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-curl-exists.sh"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/is-debian.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/is-darwin.sh"

if is_debian; then
	PLATFORM="linux"
elif is_darwin; then
	PLATFORM="darwin"
else
	OS_NAME="$(uname -s)"
	echo "❗  Automatic minikube installation not supported on ${OS_NAME}" >&2
	exit 2
fi

ARCH_NAME="$(uname -m)"
case "${ARCH_NAME}" in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    *)
        echo "❗  Unsupported architecture: ${ARCH_NAME}" >&2
        exit 3
        ;;
esac

CURRENT_VERSION=""
if command -v minikube > /dev/null 2>&1; then
    CURRENT_VERSION=$(minikube version --short | sed 's/v//')
    echo "📦  Current minikube version: v${CURRENT_VERSION}"
fi

LATEST_VERSION="$( curl -Ls "https://api.github.com/repos/kubernetes/minikube/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4 | sed 's/v//' )"
if [[ -z "${LATEST_VERSION}" ]]; then
    echo "❗  Unable to determine the latest minikube version." >&2
    exit 4
fi

echo "🌐  Latest minikube version: v${LATEST_VERSION}"

if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
    echo "✅  Up-to-date minikube version is being used already"
    exit 0
fi

echo "⬇️   Downloading minikube binary for ${PLATFORM}-${ARCH}..."

tmp="$(mktemp)"
MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/latest/minikube-${PLATFORM}-${ARCH}"
if curl -fsSL -o "${tmp}" "${MINIKUBE_URL}"; then
    if install_binary "${tmp}" "/usr/local/bin/minikube"; then
        rm -f "${tmp}"
        hash -r
        exit 0
    else
        rm -f "${tmp}"
        exit 5
    fi
else
    echo "🛑  Failed to download the minikube binary." >&2
    rm -f "${tmp}"
    exit 6
fi
