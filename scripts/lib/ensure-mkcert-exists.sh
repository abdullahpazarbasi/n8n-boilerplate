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
        echo "🛑  Failed to install mkcert binary into ${dest}. Try re-running the command with elevated permissions." >&2
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
	MKCERT_STORE_DIR="${HOME}/.local/share/mkcert"
elif is_darwin; then
	PLATFORM="darwin"
	MKCERT_STORE_DIR="${HOME}/Library/Application Support/mkcert"
else
	OS_NAME="$(uname -s)"
	echo "❗  Automatic mkcert installation not supported on ${OS_NAME}" >&2
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
if command -v mkcert > /dev/null 2>&1; then
    CURRENT_VERSION="$(mkcert --version | awk '{print $2}' | sed 's/v//')"
    echo "📦  Current mkcert version: v${CURRENT_VERSION}"
fi

LATEST_VERSION=$(curl -Ls "https://api.github.com/repos/FiloSottile/mkcert/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4 | sed 's/v//')
if [[ -z "${LATEST_VERSION}" ]]; then
    echo "❗  Unable to determine the latest mkcert version." >&2
    exit 4
fi

echo "🌐  Latest mkcert version: v${LATEST_VERSION}"

if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
    echo "✅  Up-to-date mkcert version is being used already"
    exit 0
fi

if ! command -v certutil > /dev/null 2>&1; then
    case "${PLATFORM}" in
        linux)
            sudo apt-get update && sudo apt-get install -y libnss3-tools
            ;;
        darwin)
            if command -v brew >/dev/null 2>&1; then
                brew list nss >/dev/null 2>&1 || brew install nss
            else
                echo "⚠️  'certutil' is not available. Install Homebrew (https://brew.sh) and run 'brew install nss'." >&2
            fi
            ;;
    esac
fi

echo "⬇️  Installing mkcert for ${PLATFORM}-${ARCH}..."

tmp="$(mktemp)"
MKCERT_URL="https://github.com/FiloSottile/mkcert/releases/download/v${LATEST_VERSION}/mkcert-v${LATEST_VERSION}-${PLATFORM}-${ARCH}"
if curl -fsSL -o "${tmp}" "${MKCERT_URL}"; then
    chmod +x "${tmp}"
    if install_binary "${tmp}" "/usr/local/bin/mkcert"; then
        rm -f "${tmp}"
        hash -r
    else
        rm -f "${tmp}"
        exit 5
    fi
else
    echo "🛑  Failed to download the mkcert binary." >&2
    rm -f "${tmp}"
    exit 6
fi

if [[ ! -f "${MKCERT_STORE_DIR}/rootCA-key.pem" ]] || [[ ! -f "${MKCERT_STORE_DIR}/rootCA.pem" ]]; then
    mkcert -install
fi
