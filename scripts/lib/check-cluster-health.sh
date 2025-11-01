#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

MAX_WAIT=120 # in seconds

for i in $( seq 3 3 $MAX_WAIT ); do
    CNT=$(minikube -p "${PROFILE_NAME}" kubectl -- get pods --all-namespaces -o json | jq -r '.items[] | select((.status.phase == "Running") and (.status.containerStatuses[]?.ready == false)) | [.metadata.namespace, .metadata.name] | @tsv' | wc -l)
    if [ "$CNT" -eq 0 ]; then
        exit 0
    fi
    echo "⏳  The cluster '$PROFILE_NAME' has been waiting (${i})..."
    sleep 3
done

echo "❌  The cluster '$PROFILE_NAME' was not ready within $MAX_WAIT seconds" >&2
exit 1
