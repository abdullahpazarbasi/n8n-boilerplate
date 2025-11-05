#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
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

    cnt=$(minikube -p "${PROFILE_NAME}" kubectl -- get pods --all-namespaces -o json | jq -r '.items[] | select((.status.phase == "Running") and (.status.containerStatuses[]?.ready == false)) | [.metadata.namespace, .metadata.name] | @tsv' | wc -l)
    if [ "${cnt}" -eq 0 ]; then
        exit 0
    fi

    sleep "${interval}"
	elapsed=$(( timeout - (deadline - $(now)) ))
    echo "⏳  Minikube '${PROFILE_NAME}' is being waited (${elapsed} second(s) elapsed)..."
done

echo "❌  Minikube '${PROFILE_NAME}' was not ready within ${elapsed} second(s)" >&2
exit 2
