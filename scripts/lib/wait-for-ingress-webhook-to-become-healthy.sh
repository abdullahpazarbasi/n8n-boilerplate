#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

namespace="ingress-nginx"
service="ingress-nginx-controller-admission"
deployment="ingress-nginx-controller"

timeout=600
interval=7

now() { date +%s; }
deadline=$(( $(now) + timeout ))

echo -n "⏳  "
minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" rollout status "deployment/${deployment}" --timeout="${timeout}s"

echo "⏳  Waiting for ${namespace}/${service} endpoints..."
while :; do
    if [ "$(now)" -ge "${deadline}" ]; then
        echo "🛑  No ready endpoints before deadline." >&2
        minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" get pods,svc,endpoints,endpointslice
        exit 2
    fi
    if minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" get endpointslice -l "kubernetes.io/service-name=${service}" -o jsonpath='{range .items[*]}{.endpoints[*].addresses}{"|"}{range .ports[*]}{.port}{" "}{end}{end}' | tr -d '[]' | grep -q 8443; then
        echo "✅  EndpointSlice ready on 8443."
        break
    fi

    sleep "${interval}"
done

helper="curl-helper-$(date +%s)"
echo "⏳  Creating helper pod ${namespace}/${helper}..."
minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" run "${helper}" --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep infinity

trap 'echo "🧹  Cleaning up helper pod..."; minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" delete pod "${helper}" --ignore-not-found --grace-period=0 >/dev/null 2>&1 || true' EXIT

echo "⏳  Waiting helper pod to be Ready..."
minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" wait pod/"${helper}" --for=condition=Ready --timeout=90s

probe_service_dns() {
    minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" exec -i "${helper}" -- sh -lc "curl -ks --connect-timeout 3 --max-time 7 https://${service}.${namespace}.svc:443/ -o /dev/null"
}

probe_loopback() {
    local controller_pod
    controller_pod="$( minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" get pods -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true )"
    [ -n "${controller_pod}" ] || return 1
    minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" exec -i "${controller_pod}" -- sh -lc "curl -ks --connect-timeout 2 --max-time 7 https://127.0.0.1:8443/ -o /dev/null"
}

echo "⏳  Probing admission TLS..."
while :; do
    if [ "$(now)" -ge "${deadline}" ]; then
        echo "🛑  Admission not reachable before deadline." >&2
        minikube -p "${PROFILE_NAME}" kubectl -- -n "${namespace}" get pods,svc,endpoints,endpointslice
        exit 3
    fi
    if probe_service_dns; then
        echo "✅  Admission TLS reachable via Service DNS."
        break
    fi
    if probe_loopback; then
        echo "✅  Admission reachable via loopback (hairpin disabled)."
        break
    fi

    sleep "${interval}"
done

echo "✅  Admission endpoint verified. Cleaning up..."
