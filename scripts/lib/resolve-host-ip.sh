#!/usr/bin/env bash

set -euo pipefail

if [ -z "${ROOT_DIR:-}" ]; then
    echo "🛑  ROOT_DIR is undefined" >&2
    exit 1
fi

cache_dir="${ROOT_DIR}/.cache"

mkdir -p "${cache_dir}"
host_ip_file_path="${cache_dir}/host-ip"

if [[ -f "${host_ip_file_path}" ]]; then
    cat "${host_ip_file_path}"
    exit 0
fi

host_ip=$( bash "${ROOT_DIR}/scripts/lib/resolve-host-ip-core.sh" )

echo "${host_ip}" > "${host_ip_file_path}"
echo "${host_ip}"
