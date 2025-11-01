#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

minikube -p "${PROFILE_NAME}" start \
    --driver=docker \
    --addons=default-storageclass,storage-provisioner,ingress \
    --wait=all
