#!/usr/bin/env bash

set -euo pipefail

registry_container_name="registry"

registry_status=$( docker inspect -f '{{.State.Status}}' "${registry_container_name}" )
if [ "${registry_status}" != "running" ]; then
    echo "⚠️   The image registry '${registry_container_name}' is not running" >&2
	exit 1
fi
