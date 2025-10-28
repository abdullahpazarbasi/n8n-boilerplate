#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="$1"

if [ -z "$PROFILE_NAME" ]; then
    echo "Usage: $0 <minikube-profile>"
    exit 1
fi

cd "$(dirname "$0")/.."

minikube -p "$PROFILE_NAME" start --driver=docker --addons=default-storageclass,storage-provisioner,ingress --wait=all --disk-size=20g
