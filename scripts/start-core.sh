#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="$1"

if [ -z "${PROFILE_NAME}" ]; then
    echo "⚠️  Usage: $0 <minikube-profile-name>" >&2
    exit 1
fi

minikube -p "${PROFILE_NAME}" start \
    --driver=docker \
    --addons=default-storageclass,storage-provisioner,ingress \
    --wait=all
