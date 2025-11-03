#!/usr/bin/env bash

# Usage:
#   ./create-db-in-postgres.sh -n <DB_NAME> -u <DB_USER> -p <DB_PASS> [-P <profile>] [-s <namespace>] [-l <pod_regex>] [-x <superuser>] [-W <superpass>] [--debug]
#
# Example:
#   ./create-db-in-postgres.sh -n example -u myuser -p '12345678' -P n8n
#
# Notes:
# - Comments and messages are in English (as requested).
# - Requires: minikube, awk, grep, kubectl (or use minikube's built-in kubectl).
# - By default, searches all namespaces in the given profile and picks the first Running pod whose name matches /postgres/.
# - You can override namespace and selector if your labels/names differ.

set -euo pipefail

DB_NAME="";
DB_USER="";
DB_PASS=""
PROFILE="minikube";
NAMESPACE=""
POD_SELECTOR_REGEX="postgres"
SUPERUSER_OVERRIDE=""
SUPERPASS_OVERRIDE="" # -W to force PGPASSWORD
DEBUG=0

usage(){
	echo "Usage: $0 -n <DB_NAME> -u <DB_USER> -p <DB_PASS> [-P <profile>] [-s <namespace>] [-l <pod_regex>] [-x <superuser>] [-W <superpass>] [--debug]";
	exit 2;
}

# Parse args
while (( "$#" )); do
  case "$1" in
    -n) DB_NAME="$2"; shift 2;;
    -u) DB_USER="$2"; shift 2;;
    -p) DB_PASS="$2"; shift 2;;
    -P) PROFILE="$2"; shift 2;;
    -s) NAMESPACE="$2"; shift 2;;
    -l) POD_SELECTOR_REGEX="$2"; shift 2;;
    -x) SUPERUSER_OVERRIDE="$2"; shift 2;;
    -W) SUPERPASS_OVERRIDE="$2"; shift 2;;
    --debug) DEBUG=1; shift;;
    -h|--help) usage;;
    *) echo "[ERROR] Unknown arg: $1"; usage;;
  esac
done

[[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]] && usage

[[ $DEBUG -eq 1 ]] && set -x

mkctl(){ minikube -p "$PROFILE" kubectl -- "$@"; }

log(){ echo "[$(date +%H:%M:%S)] $*"; }

log "[INFO] Using minikube profile: $PROFILE"

# 1) Locate Postgres pod
if [[ -n "$NAMESPACE" ]]; then
  log "[INFO] Searching Postgres pod in ns=$NAMESPACE (regex=/$POD_SELECTOR_REGEX/)"
  POD_LINE=$(mkctl get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
    | awk -v ns="$NAMESPACE" -v re="$POD_SELECTOR_REGEX" '$1 ~ re && $3=="Running"{print ns ":" $1; exit}')
else
  log "[INFO] Searching Postgres pod across all namespaces (regex=/$POD_SELECTOR_REGEX/)"
  POD_LINE=$(mkctl get pods -A --no-headers 2>/dev/null \
    | awk -v re="$POD_SELECTOR_REGEX" '$2 ~ re && $4=="Running"{print $1 ":" $2; exit}')
fi
[[ -z "${POD_LINE:-}" ]] && { echo "[ERROR] No Running Postgres pod found."; exit 1; }
PG_NS="${POD_LINE%%:*}"; PG_POD="${POD_LINE##*:}"
log "[INFO] Target pod: $PG_POD (ns: $PG_NS)"

# 2) Helpers to run in pod
in_pod(){ mkctl exec -n "$PG_NS" "$PG_POD" -- bash -lc "$*"; }

# 3) Discover superuser and password (from env if possible)
discover_candidates(){
  local env_dump; env_dump="$(in_pod 'env || true')"
  local cands=()
  for k in POSTGRES_USER PGUSER POSTGRESQL_USERNAME; do
    v=$(awk -F= -v K="^${k}=" '$0~K{print $2}' <<<"$env_dump"); [[ -n "${v:-}" ]] && cands+=("$v")
  done
  cands+=("postgres" "admin" "bitnami" "default" "root" "n8n" "user")
  awk 'BEGIN{FS=OFS="\n"}{for(i=1;i<=NF;i++) if(!seen[$i]++){print $i}}' <<<"$(printf "%s\n" "${cands[@]}")"
}
discover_password(){
  [[ -n "$SUPERPASS_OVERRIDE" ]] && { echo "$SUPERPASS_OVERRIDE"; return 0; }
  local env_dump; env_dump="$(in_pod 'env || true')"
  # Common env names across images
  for k in POSTGRES_PASSWORD POSTGRESQL_PASSWORD PG_PASSWORD PGPASSWORD; do
    v=$(awk -F= -v K="^${k}=" '$0~K{print $2}' <<<"$env_dump")
    [[ -n "${v:-}" ]] && { echo "$v"; return 0; }
  done
  echo ""  # not fatal
}

# 4) Build connection probe (socket first, then TCP)
psql_probe(){
  local u="$1" d="$2" hflag="$3" pass="$4"
  local envs="PGCONNECT_TIMEOUT=5"
  [[ -n "$pass" ]] && envs="$envs PGPASSWORD='$pass'"
  # -X ignore .psqlrc; --no-password forbids prompts; -tA quiet; ON_ERROR_STOP for fail-fast
  in_pod "$envs psql -X --no-password -U '$u' $hflag -d '$d' -v ON_ERROR_STOP=1 -tA -c 'SELECT 1' >/dev/null 2>&1"
}

detect_superuser_and_conn(){
  local pass; pass="$(discover_password || true)"
  [[ -n "$SUPERUSER_OVERRIDE" ]] && {
    for db in postgres template1; do
      if psql_probe "$SUPERUSER_OVERRIDE" "$db" "" "$pass" || psql_probe "$SUPERUSER_OVERRIDE" "$db" "-h 127.0.0.1" "$pass"; then
        echo "$SUPERUSER_OVERRIDE;$db;${pass};" && return 0
      fi
    done
    return 1
  }
  local u db
  for u in $(discover_candidates); do
    for db in postgres template1; do
      if psql_probe "$u" "$db" "" "$pass"; then
        echo "$u;$db;${pass};" && return 0
      fi
      if psql_probe "$u" "$db" "-h 127.0.0.1" "$pass"; then
        echo "$u;$db;${pass};-h 127.0.0.1" && return 0
      fi
    done
  done
  return 1
}

log "[INFO] Probing superuser & connection method..."
CONN="$(detect_superuser_and_conn)" || {
  echo "[ERROR] Could not connect with any candidate superuser (socket or TCP). Try -x <user> and/or -W <pass>."
  echo "[HINT] Inspect env: minikube -p $PROFILE kubectl -- exec -n $PG_NS $PG_POD -- env | grep -Ei 'POSTGRES|PGUSER|PASS'"
  exit 2
}
IFS=';' read -r PSQL_USER CONNECT_DB SUPERPASS HFLAG <<<"$CONN"
[[ -n "${HFLAG:-}" ]] && HSTR="$HFLAG" || HSTR="(unix socket)"
[[ -n "$SUPERPASS" ]] && PASS_NOTE="(with password)" || PASS_NOTE="(no password)"
log "[INFO] Using superuser: $PSQL_USER"
log "[INFO] Connecting to DB: $CONNECT_DB via ${HSTR} ${PASS_NOTE}"

# 5) Small function to run a SQL and return scalar
sql_scalar(){
  local sql="$1"
  local envs="PGCONNECT_TIMEOUT=5"
  [[ -n "$SUPERPASS" ]] && envs="$envs PGPASSWORD='$SUPERPASS'"
  in_pod "$envs psql -X --no-password -U '$PSQL_USER' ${HFLAG:-} -d '$CONNECT_DB' -v ON_ERROR_STOP=1 -tA -c \"$sql\""
}

# 6) Idempotent ensure role
log "[STEP] Ensuring role '$DB_USER'..."
EXISTS_ROLE="$(sql_scalar "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER' LIMIT 1;")" || true
if [[ "${EXISTS_ROLE:-}" == "1" ]]; then
  log "[OK  ] Role exists → ALTER password"
  sql_scalar "ALTER ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$DB_PASS';" >/dev/null
else
  log "[OK  ] Creating role"
  sql_scalar "CREATE ROLE \"$DB_USER\" LOGIN PASSWORD '$DB_PASS';" >/dev/null
fi

# 7) Idempotent ensure database
log "[STEP] Ensuring database '$DB_NAME'..."
EXISTS_DB="$(sql_scalar "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME' LIMIT 1;")" || true
if [[ "${EXISTS_DB:-}" == "1" ]]; then
  log "[OK  ] Database exists"
else
  log "[OK  ] Creating database (owner: $DB_USER)"
  sql_scalar "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";" >/dev/null
fi

# 8) Grants (best-effort)
log "[STEP] Grants..."
sql_scalar "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";" >/dev/null || true

log "[DONE] Ensured DB '$DB_NAME' and role '$DB_USER' in pod $PG_POD (ns: $PG_NS)."
