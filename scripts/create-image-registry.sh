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

now() { date +%s; }

echo ""
echo "--------------------------------------------------------------------------------"
echo "🚧  Creating The Image Registry"
echo "--------------------------------------------------------------------------------"

registry_container_name="registry"

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

set +e
# shellcheck disable=SC2097,SC2098
ROOT_DIR="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/lib/ensure-mkcert-exists.sh"
exit_code=$?
set -e
if [ $exit_code -ne 0 ]; then
    echo "🛑  mkcert is not available (exit code: ${exit_code})" >&2
    exit 4
fi

registry_crt_file_name="${REGISTRY_HOST}.crt.pem"
registry_key_file_name="${REGISTRY_HOST}.key.pem"
registry_certificate_dir="${HOME}"
registry_crt_file_path="${registry_certificate_dir}/${registry_crt_file_name}"
registry_key_file_path="${registry_certificate_dir}/${registry_key_file_name}"

mkdir -p "${registry_certificate_dir}"

if [ ! -f "${registry_crt_file_path}" ] || [ ! -f "${registry_key_file_path}" ]; then
    mkcert "${REGISTRY_HOST}" && \
    mv "${REGISTRY_HOST}.pem" "${registry_crt_file_path}" && \
    mv "${REGISTRY_HOST}-key.pem" "${registry_key_file_path}"
fi

if [ ! -f "${registry_crt_file_path}" ] || [ ! -f "${registry_key_file_path}" ]; then
    echo "❌  CRT file or KEY file could not be found" >&2
    exit 5
fi

timeout=300
deadline=$(( $(now) + timeout ))

target_ca_cert_dir="/etc/docker/certs.d/${REGISTRY_HOST}:5000"
target_ca_cert_path="${target_ca_cert_dir}/ca.crt"
if [ ! -f "${target_ca_cert_path}" ]; then
    source_ca_cert_dir=$( mkcert -CAROOT )
    source_ca_cert_path="${source_ca_cert_dir}/rootCA.pem"
    sudo mkdir -p "${target_ca_cert_dir}"
    sudo cp -f "${source_ca_cert_path}" "${target_ca_cert_path}"
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
    -v "${registry_crt_file_path}:/certs/domain.crt" \
    -v "${registry_key_file_path}:/certs/domain.key" \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    registry:2

sudo bash "${ROOT_DIR}/scripts/add-host-entry-in-host.sh" "${REGISTRY_HOST}" "127.0.0.1"

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
