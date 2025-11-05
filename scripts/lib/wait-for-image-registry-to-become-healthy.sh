#!/usr/bin/env bash

set -euo pipefail

if [ -z "${REGISTRY_HOST:-}" ]; then
    echo "🛑  REGISTRY_HOST is undefined" >&2
    exit 1
fi

timeout=300 # in seconds
interval=7 # in seconds

now() { date +%s; }
deadline=$(( $(now) + timeout ))

while :; do
	if [ "$(now)" -ge "${deadline}" ]; then
		break
	fi

    curl -s -m 7 "https://${REGISTRY_HOST}:5000/v2/_catalog" >/dev/null 2>&1
    exit_code_1=$?
    curl -s -m 7 "http://localhost:5000/v2/_catalog" >/dev/null 2>&1
    exit_code_2=$?
    if [ "${exit_code_1}" = "0" ] && [ "${exit_code_2}" = "0" ]; then
        exit 0
    fi
    sleep "${interval}"
	elapsed=$(( timeout - (deadline - $(now)) ))
    echo "⏳  The image registry is not ready yet (exit code 1: ${exit_code_1} and exit code 2: ${exit_code_2}) (${elapsed} second(s) elapsed)..."
done

echo "🛑  The image registry was not ready within ${elapsed} second(s)" >&2
exit 2
