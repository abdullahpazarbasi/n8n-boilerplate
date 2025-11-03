#!/usr/bin/env bash

if [ -z "${ROOT_DIR:-}" ]; then
    echo "🛑  ROOT_DIR is undefined" >&2
    exit 1
fi

if command -v "docker" >/dev/null 2>&1; then
    exit 0
fi

echo "⬇️  Installing Docker..."

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/is-debian.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/is-darwin.sh"

if is_debian; then
	# shellcheck disable=SC2097,SC2098
	ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-curl-exists.sh"

    sudo apt-get update && \
		sudo apt-get install -y ca-certificates gnupg lsb-release && \
    	sudo install -m 0755 -d /etc/apt/keyrings

	distributor=$( . /etc/os-release && echo "$ID" )
	codename=$( . /etc/os-release && echo "$VERSION_CODENAME" )
    curl -fsSL "https://download.docker.com/linux/${distributor}/gpg" | sudo gpg --dearmor -o "/etc/apt/keyrings/docker.gpg"
    echo "deb [arch=$( dpkg --print-architecture ) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${distributor} \
${codename} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update && \
    	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif is_darwin; then
    if command -v brew >/dev/null 2>&1; then
        brew list --cask docker >/dev/null 2>&1 || brew install --cask docker
    else
        echo "🛑  Install Homebrew (https://brew.sh) to install Docker automatically" >&2
        exit 3
    fi
else
    OS_NAME="$(uname -s)"
    echo "❗  Automatic Docker installation not supported on ${OS_NAME}" >&2
    exit 2
fi
