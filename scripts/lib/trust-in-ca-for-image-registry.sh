#!/usr/bin/env bash

set -euo pipefail

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

if [ -z "${REGISTRY_HOST:-}" ]; then
    echo "🛑  REGISTRY_HOST is undefined" >&2
    exit 2
fi

registry_port="5000"

timeout=120 # in seconds
interval=3 # in seconds
elapsed=0 # in seconds

registry_authority="${REGISTRY_HOST}:${registry_port}"
root_ca_dir=$( mkcert -CAROOT )
root_ca_cert_path="${root_ca_dir}/rootCA.pem"
remote_ca_dir="/etc/docker/certs.d/${registry_authority}"
remote_ca_cert_path="${remote_ca_dir}/ca.crt"

minikube -p "${PROFILE_NAME}" ssh -- "sudo mkdir -p ${remote_ca_dir}"
minikube -p "${PROFILE_NAME}" cp "${root_ca_cert_path}" "${PROFILE_NAME}:${remote_ca_cert_path}"

if minikube -p "${PROFILE_NAME}" ssh -- "pgrep dockerd" > /dev/null; then
    if minikube -p "${PROFILE_NAME}" ssh -- "sudo systemctl restart docker" > /dev/null; then
        while [ "${elapsed}" -lt "${timeout}" ]; do
            if minikube -p "${PROFILE_NAME}" ssh -- "sudo systemctl is-active --quiet docker && docker info" > /dev/null 2>&1; then
                echo "✅  Minikube 'docker' is ready"
                break
            fi
            sleep "${interval}"
			elapsed=$((elapsed + interval))
            echo "⏳  Minikube 'docker' is not ready yet (${elapsed} second(s) elapsed)..."
        done
		elapsed=0
        while [ "${elapsed}" -lt "${timeout}" ]; do
            if minikube -p "${PROFILE_NAME}" kubectl -- get nodes > /dev/null 2>&1; then
                echo "✅  Minikube 'kubernetes' is ready"
                break
            fi
            sleep "${interval}"
			elapsed=$((elapsed + interval))
            echo "⏳  Minikube 'kubernetes' is not ready yet (${elapsed} second(s) elapsed)..."
        done
    else
        echo "🛑  Minikube 'docker' could not be restarted" >&2
        exit 4
    fi
else
    echo "❌  Minikube driver is not 'docker'" >&2
    exit 3
fi
