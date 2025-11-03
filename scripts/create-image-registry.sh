#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/assert-running-in-bash.sh"

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/lib/dotenv.sh"

if [ -z "${PROFILE_NAME:-}" ]; then
    echo "🛑  PROFILE_NAME is undefined" >&2
    exit 1
fi

registry_container_name="registry"

now() { date +%s; }

set +e
bash "${ROOT_DIR}/scripts/lib/assert-image-registry-container-exists.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
	set +e
    bash "${ROOT_DIR}/scripts/lib/assert-image-registry-running.sh"
	exit_code=$?
	set -e
	if [ $exit_code -eq 0 ]; then
		echo "✅  The image registry is running already"
        exit 0
	else
		docker start "${registry_container_name}" || {
            echo "🛑  The image registry could not be started" >&2
            exit 2
        }
		set +e
		bash "${ROOT_DIR}/scripts/lib/wait-for-image-registry-to-become-healthy.sh"
		exit_code=$?
		set -e
		if [ $exit_code -eq 0 ]; then
			echo "✅  The image registry is healthy"
            exit 0
		else
			echo "❌  The image registry is not healthy" >&2
            exit 3
		fi
	fi
fi

CRT_FILE_NAME="${REGISTRY_HOST}.crt.pem"
KEY_FILE_NAME="${REGISTRY_HOST}.key.pem"
CERTIFICATE_DIR="${HOME}"
CRT_FILE_PATH="${CERTIFICATE_DIR}/${CRT_FILE_NAME}"
KEY_FILE_PATH="${CERTIFICATE_DIR}/${KEY_FILE_NAME}"

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-mkcert-exists.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  mkcert is not available (exit code: ${exit_code})" >&2
    exit 4
fi

mkdir -p "${CERTIFICATE_DIR}"

if [ ! -f "${CRT_FILE_PATH}" ] || [ ! -f "${KEY_FILE_PATH}" ]; then
    mkcert "${REGISTRY_HOST}" && \
    mv "${REGISTRY_HOST}.pem" "${CRT_FILE_PATH}" && \
    mv "${REGISTRY_HOST}-key.pem" "${KEY_FILE_PATH}"
fi

if [ ! -f "$CRT_FILE_PATH" ] || [ ! -f "$KEY_FILE_PATH" ]; then
    echo "❌  CRT file or KEY file could not be found" >&2
    exit 5
fi

timeout=120
deadline=$(( $(now) + timeout ))

TARGET_CA_CERT_DIR="/etc/docker/certs.d/${REGISTRY_HOST}:5000"
TARGET_CA_CERT_PATH="${TARGET_CA_CERT_DIR}/ca.crt"
if [ ! -f "${TARGET_CA_CERT_PATH}" ]; then
    SOURCE_CA_CERT_DIR=$( mkcert -CAROOT )
    SOURCE_CA_CERT_PATH="${SOURCE_CA_CERT_DIR}/rootCA.pem"
    sudo mkdir -p "${TARGET_CA_CERT_DIR}"
    sudo cp -f "${SOURCE_CA_CERT_PATH}" "${TARGET_CA_CERT_PATH}"
    if sudo systemctl restart docker > /dev/null; then
        while :; do
			if [ "$(now)" -ge "${deadline}" ]; then
				echo "🛑  Host 'docker' could not be ready within ${timeout} second(s)" >&2
				exit 7
			fi
            if systemctl is-active --quiet docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
                echo "✅  Host 'docker' is ready"
                break
            fi
            echo "⏳  Host 'docker' is not ready yet..."
            sleep 3
        done
    else
        echo "🛑  Host 'docker' could not be restarted" >&2
        exit 6
    fi
fi

docker rm -f "${registry_container_name}" > /dev/null 2>&1 && \
docker image rm -f "registry:2" > /dev/null 2>&1 && \
docker run -d \
    -p 5000:5000 \
    --restart=always \
    --name "${registry_container_name}" \
    -v "${CRT_FILE_PATH}:/certs/domain.crt" \
    -v "${KEY_FILE_PATH}:/certs/domain.key" \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    registry:2

sudo bash "${ROOT_DIR}/scripts/add-host-entry.sh" "${REGISTRY_HOST}" "127.0.0.1"

set +e
bash "${ROOT_DIR}/scripts/lib/wait-for-image-registry-to-become-healthy.sh"
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
	echo "✅  The image registry is healthy"
	exit 0
else
	echo "❌  The image registry is not healthy" >&2
	exit 8
fi
