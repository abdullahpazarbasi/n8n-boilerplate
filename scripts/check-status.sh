#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/assert-running-in-bash.sh"

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/dotenv.sh"

if [ -z "${PROFILE_NAME}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

echo ""
echo "--------------------------------------------------------------------------------"
echo "🔎  Status"
echo "--------------------------------------------------------------------------------"

echo ""
echo "✨  Minikube addons:"
echo "--------------------------------------------------------------------------------"
echo ""
minikube -p "$PROFILE_NAME" addons list

echo ""
echo "🖥  Minikube host:"
echo "--------------------------------------------------------------------------------"
bash "${ROOT_DIR}/scripts/lib/assert-minikube-host-running.sh" && \
echo "🏃  Minikube host '$PROFILE_NAME' is running" || \
exit 0

echo ""
echo "🕸  Minikube IP:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" ip

echo ""
echo "🗎  Available k8s contexts:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- config get-contexts

echo ""
echo "🌠  Namespaces:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get namespaces

echo ""
echo "🖴  Persistent Volumes:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get pv,pvc

echo ""
echo "🟧  Pods:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get pods

echo ""
echo "🔄  Replica Sets:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get replicasets

echo ""
echo "⏫  Deployments:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get deployments

echo ""
echo "🎯  Services:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get services

echo ""
echo "🛡️  Ingresses:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get ingress

echo ""
echo "🔑  Secrets:"
echo "--------------------------------------------------------------------------------"
minikube -p "$PROFILE_NAME" kubectl -- get secrets

echo ""
echo "🚑  Cluster Health:"
echo "--------------------------------------------------------------------------------"
bash "${ROOT_DIR}/scripts/lib/check-cluster-health.sh" && \
echo "👮  The cluster '$PROFILE_NAME' is ready" || \
exit 0

echo ""
echo "🔗  URLs:"
echo "--------------------------------------------------------------------------------"
bash "${ROOT_DIR}/scripts/lib/view-n8n-urls.sh"
