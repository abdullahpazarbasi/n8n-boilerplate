#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

set +e
ip_route_output=$( minikube -p "${PROFILE_NAME}" ssh -- ip route 2> >(tee /dev/stderr) )
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
	echo "🛑  Failed to execute 'ip route' inside minikube '${PROFILE_NAME}'" >&2
    exit 2
fi

set +e
host_ip=$( echo "${ip_route_output}" | awk '/^default/ {print $3}' | head -n 1 )
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
	echo "🛑  Could not parse host IP from route output" >&2
    exit 3
fi
if [[ -z "${host_ip}" ]]; then
    echo "🛑  Host IP is empty" >&2
    exit 4
fi

echo "${host_ip}"
