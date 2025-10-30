#!/usr/bin/env bash

set -euo pipefail

if command -v "openssl" >/dev/null 2>&1; then
	exit 0
fi

echo "⬇️  Installing openssl..."
if [[ -f /etc/debian_version ]]; then
	sudo apt-get update && \
	sudo apt-get install -y openssl
else
	echo "❗  Automatic openssl installation not supported" >&2
	exit 1
fi
