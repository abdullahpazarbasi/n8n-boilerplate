#!/usr/bin/env bash

set -euo pipefail

registry_container_name="registry"

if docker ps -a --format '{{.Names}}' | grep -q "^${registry_container_name}\$"; then
    exit 0
fi

echo "⚠️   The image registry container '${registry_container_name}' does not exist" >&2
exit 1
