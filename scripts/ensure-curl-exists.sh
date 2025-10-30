#!/usr/bin/env bash

set -euo pipefail

if command -v "curl" >/dev/null 2>&1; then
	exit 0
fi

echo "⬇️  Installing curl..."
if [[ -f /etc/debian_version ]]; then
	sudo apt-get update && \
	sudo apt-get install -y curl
else
	echo "❗  Automatic curl installation not supported" >&2
	exit 1
fi
