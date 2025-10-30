#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="$1"

if [ -z "${PROFILE_NAME}" ]; then
    echo "⚠️  Usage: $0 <minikube-profile-name>" >&2
    exit 1
fi

namespace="ingress-nginx"
svc="ingress-nginx-controller-admission"
timeout_seconds=180
interval=5
waited=0

if ! minikube -p "${PROFILE_NAME}" kubectl -- -n "$namespace" wait --for=condition=Available deployment/ingress-nginx-controller --timeout="${timeout_seconds}s" >/dev/null 2>&1; then
	exit 2
fi

while [ "$waited" -lt "$timeout_seconds" ]; do
	if minikube -p "${PROFILE_NAME}" kubectl -- -n "$namespace" get endpoints "$svc" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | grep -qE '\S'; then
		exit 0
	fi

	sleep "$interval"
	waited=$((waited + interval))
done

exit 3
