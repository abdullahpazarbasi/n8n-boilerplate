#!/usr/bin/env bash

if [ -z "${ROOT_DIR:-}" ]; then
    echo "🛑  ROOT_DIR is undefined" >&2
    exit 1
fi

if command -v "openssl" >/dev/null 2>&1; then
    exit 0
fi

echo "⬇️  Installing openssl..."

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/is-debian.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/is-darwin.sh"

if is_debian; then
	sudo apt-get update && sudo apt-get install -y openssl
elif is_darwin; then
	if command -v brew >/dev/null 2>&1; then
		brew list openssl@3 >/dev/null 2>&1 || brew install openssl@3
	else
		echo "🛑  Install Homebrew (https://brew.sh) to install curl automatically" >&2
		exit 3
	fi
else
	OS_NAME="$(uname -s)"
	echo "❗  Automatic openssl installation not supported on ${OS_NAME}" >&2
	exit 2
fi
