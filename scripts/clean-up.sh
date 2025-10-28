#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="n8n"

cd "$(dirname "$0")/.."

minikube -p "${PROFILE_NAME}" delete
