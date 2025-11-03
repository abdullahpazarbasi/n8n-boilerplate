#!/usr/bin/env bash

set -euo pipefail

docker tag "n8n:latest" "localhost:5000/n8n:latest" && \
docker tag "n8n:latest" "registry.local:5000/n8n:latest" && \
docker push "localhost:5000/n8n:latest"
