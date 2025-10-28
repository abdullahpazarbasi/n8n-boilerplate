#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="n8n"
POSTGRES_IMAGE="postgres:16-alpine"
N8N_IMAGE="n8nio/n8n:latest"
N8N_HOST_DEFAULT="n8n.local"
N8N_TIMEZONE="Europe/Istanbul"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${REPO_ROOT}/bin"
MANIFEST_DIR="${REPO_ROOT}/out/manifests"

mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

cd "$REPO_ROOT"

echo ""
echo "--------------------------------------------------------------------------------"
echo " Setup"
echo "--------------------------------------------------------------------------------"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' does not exist"; exit 1; }; }

ensure_minikube() {
    if command -v minikube >/dev/null 2>&1; then
        return 0
    fi

    local target="$BIN_DIR/minikube"
    if [ -x "$target" ]; then
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "⚠️  'minikube' is not available and 'curl' is required to download it." >&2
        return 1
    fi

    echo "⬇️  Downloading minikube binary..."
    local tmp
    tmp="$(mktemp)"
    if curl -fsSL "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" -o "$tmp"; then
        install -m 0755 "$tmp" "$target"
        rm -f "$tmp"
        hash -r
        return 0
    else
        echo "⚠️  Failed to download the minikube binary." >&2
        rm -f "$tmp"
        return 1
    fi
}

need openssl

MINIKUBE_READY=0
if ensure_minikube; then
    MINIKUBE_READY=1
else
    echo "⚠️  Continuing without a local minikube binary."
fi

MOCK_MODE=1
if [ "$MINIKUBE_READY" -eq 1 ]; then
    if bash scripts/start.sh; then
        MOCK_MODE=0
    else
        echo "⚠️  Minikube could not be started. Falling back to manifest generation." >&2
    fi
else
    echo "ℹ️  Falling back to manifest generation because minikube is unavailable." >&2
fi

PG_PASS="$(openssl rand -base64 18 | tr -d '=+/[:space:]' | head -c 20)"
N8N_ENCRYPTION_KEY="$(openssl rand -base64 36 | tr -d '=+/[:space:]' | head -c 32)"

if [ "$MOCK_MODE" -eq 0 ]; then
    minikube -p "${PROFILE_NAME}" kubectl -- delete secret "n8n-secrets" >/dev/null 2>&1 || true
    minikube -p "${PROFILE_NAME}" kubectl -- create secret generic "n8n-secrets" \
      --from-literal=POSTGRES_PASSWORD="${PG_PASS}" \
      --from-literal=N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY}"

    minikube -p "${PROFILE_NAME}" kubectl -- delete configmap "n8n-config" >/dev/null 2>&1 || true
    minikube -p "${PROFILE_NAME}" kubectl -- create configmap "n8n-config" \
      --from-literal=N8N_HOST="${N8N_HOST_DEFAULT}" \
      --from-literal=N8N_PORT="5678" \
      --from-literal=N8N_PROTOCOL="http" \
      --from-literal=GENERIC_TIMEZONE="${N8N_TIMEZONE}" \
      --from-literal=DB_TYPE="postgresdb" \
      --from-literal=DB_POSTGRESDB_HOST="postgres" \
      --from-literal=DB_POSTGRESDB_PORT="5432" \
      --from-literal=DB_POSTGRESDB_DATABASE="n8n" \
      --from-literal=DB_POSTGRESDB_USER="n8n"

    cat <<'YAML' | minikube -p "${PROFILE_NAME}" kubectl -- apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pg-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 8Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: n8n-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 4Gi
YAML

    cat <<YAML | minikube -p "${PROFILE_NAME}" kubectl -- apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector: { matchLabels: { app: postgres } }
  template:
    metadata: { labels: { app: postgres } }
    spec:
      containers:
        - name: postgres
          image: ${POSTGRES_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: POSTGRES_DB
              value: n8n
            - name: POSTGRES_USER
              value: n8n
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: n8n-secrets
                  key: POSTGRES_PASSWORD
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: pgdata
              mountPath: /var/lib/postgresql/data
          readinessProbe:
            exec: { command: ["pg_isready","-U","n8n"] }
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            tcpSocket: { port: 5432 }
            initialDelaySeconds: 15
            periodSeconds: 10
      volumes:
        - name: pgdata
          persistentVolumeClaim: { claimName: pg-data }
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  type: ClusterIP
  ports:
    - name: psql
      port: 5432
      targetPort: 5432
  selector: { app: postgres }
YAML

    cat <<YAML | minikube -p "${PROFILE_NAME}" kubectl -- apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
spec:
  replicas: 1
  selector: { matchLabels: { app: n8n } }
  template:
    metadata: { labels: { app: n8n } }
    spec:
      containers:
        - name: n8n
          image: ${N8N_IMAGE}
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef: { name: n8n-config }
          env:
            - name: N8N_ENCRYPTION_KEY
              valueFrom:
                secretKeyRef:
                  name: n8n-secrets
                  key: N8N_ENCRYPTION_KEY
          ports:
            - containerPort: 5678
          volumeMounts:
            - name: n8nvol
              mountPath: /home/node/.n8n
          readinessProbe:
            httpGet: { path: /healthz, port: 5678 }
            initialDelaySeconds: 15
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 5678 }
            initialDelaySeconds: 30
            periodSeconds: 10
      volumes:
        - name: n8nvol
          persistentVolumeClaim: { claimName: n8n-data }
---
apiVersion: v1
kind: Service
metadata:
  name: n8n
spec:
  selector: { app: n8n }
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 5678
      nodePort: 30080
YAML

    cat <<YAML | minikube -p "${PROFILE_NAME}" kubectl -- apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: n8n
spec:
  ingressClassName: "nginx"
  rules:
    - host: ${N8N_HOST_DEFAULT}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: n8n
                port:
                  number: 80
YAML

    echo "🏃  Pods are being prepared..."
    minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/postgres --timeout=120s
    minikube -p "${PROFILE_NAME}" kubectl -- rollout status deploy/n8n --timeout=300s

    sudo bash scripts/add-host-entry.sh "${N8N_HOST_DEFAULT}" "$(minikube -p "${PROFILE_NAME}" ip)"

    echo ""
    echo "👍  Setup completed."
    NODE_URL="$(minikube -p "${PROFILE_NAME}" service n8n --url | head -n1 || true)"
    echo "    with NodePort: ${NODE_URL:-http://$(minikube -p "${PROFILE_NAME}" ip)}:30080"
    echo "    with Ingress:  https://${N8N_HOST_DEFAULT}"
else
    echo ""
    echo "🗂️  Generating Kubernetes manifests instead of applying them."
    mkdir -p "$MANIFEST_DIR"

    b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

    cat >"$MANIFEST_DIR/n8n-secrets.yaml" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: n8n-secrets
type: Opaque
data:
  POSTGRES_PASSWORD: "$(b64 "$PG_PASS")"
  N8N_ENCRYPTION_KEY: "$(b64 "$N8N_ENCRYPTION_KEY")"
YAML

    cat >"$MANIFEST_DIR/n8n-configmap.yaml" <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: n8n-config
data:
  N8N_HOST: "${N8N_HOST_DEFAULT}"
  N8N_PORT: "5678"
  N8N_PROTOCOL: "http"
  GENERIC_TIMEZONE: "${N8N_TIMEZONE}"
  DB_TYPE: "postgresdb"
  DB_POSTGRESDB_HOST: "postgres"
  DB_POSTGRESDB_PORT: "5432"
  DB_POSTGRESDB_DATABASE: "n8n"
  DB_POSTGRESDB_USER: "n8n"
YAML

    cat >"$MANIFEST_DIR/persistent-volume-claims.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pg-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 8Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: n8n-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 4Gi
YAML

    cat >"$MANIFEST_DIR/postgres.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector: { matchLabels: { app: postgres } }
  template:
    metadata: { labels: { app: postgres } }
    spec:
      containers:
        - name: postgres
          image: ${POSTGRES_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: POSTGRES_DB
              value: n8n
            - name: POSTGRES_USER
              value: n8n
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: n8n-secrets
                  key: POSTGRES_PASSWORD
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: pgdata
              mountPath: /var/lib/postgresql/data
          readinessProbe:
            exec: { command: ["pg_isready","-U","n8n"] }
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            tcpSocket: { port: 5432 }
            initialDelaySeconds: 15
            periodSeconds: 10
      volumes:
        - name: pgdata
          persistentVolumeClaim: { claimName: pg-data }
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  type: ClusterIP
  ports:
    - name: psql
      port: 5432
      targetPort: 5432
  selector: { app: postgres }
YAML

    cat >"$MANIFEST_DIR/n8n.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
spec:
  replicas: 1
  selector: { matchLabels: { app: n8n } }
  template:
    metadata: { labels: { app: n8n } }
    spec:
      containers:
        - name: n8n
          image: ${N8N_IMAGE}
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef: { name: n8n-config }
          env:
            - name: N8N_ENCRYPTION_KEY
              valueFrom:
                secretKeyRef:
                  name: n8n-secrets
                  key: N8N_ENCRYPTION_KEY
          ports:
            - containerPort: 5678
          volumeMounts:
            - name: n8nvol
              mountPath: /home/node/.n8n
          readinessProbe:
            httpGet: { path: /healthz, port: 5678 }
            initialDelaySeconds: 15
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 5678 }
            initialDelaySeconds: 30
            periodSeconds: 10
      volumes:
        - name: n8nvol
          persistentVolumeClaim: { claimName: n8n-data }
---
apiVersion: v1
kind: Service
metadata:
  name: n8n
spec:
  selector: { app: n8n }
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 5678
      nodePort: 30080
YAML

    cat >"$MANIFEST_DIR/ingress.yaml" <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: n8n
spec:
  ingressClassName: "nginx"
  rules:
    - host: ${N8N_HOST_DEFAULT}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: n8n
                port:
                  number: 80
YAML

    echo ""
    echo "👍  Setup (manifests only) completed."
    echo "    Generated manifests are located in: ${MANIFEST_DIR}"
    echo "    Apply them with: kubectl apply -f ${MANIFEST_DIR}"
    echo "    Expected NodePort: http://localhost:30080"
    echo "    Expected Ingress:  https://${N8N_HOST_DEFAULT}"
fi

echo "📌  DB info:"
echo "      DB: n8n  USER: n8n  PASS: ${PG_PASS}"
