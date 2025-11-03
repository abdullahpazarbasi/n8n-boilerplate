#!/usr/bin/env bash

set -euo pipefail

docker tag "postgres:latest" "localhost:5000/postgres:latest" && \
docker tag "postgres:latest" "registry.local:5000/postgres:latest" && \
docker push "localhost:5000/postgres:latest"
