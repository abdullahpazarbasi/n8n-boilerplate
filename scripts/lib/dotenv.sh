#!/usr/bin/env bash

: "${DOTENV_NO_CLOBBER:=1}"
: "${DOTENV_EXPAND:=1}"
: "${DOTENV_AUTORUN:=1}"
: "${DOTENV_ROOT:=.}"
: "${DOTENV_FORCE_KEYS:=}"
: "${DOTENV_PROTECT_KEYS:=}"
: "${CI:=0}"
: "${PREEXISTING_KEYS:=}"

dotenv__log(){ printf '[dotenv] %s\n' "$*" >&2; }

dotenv__reject_unsafe(){
  local line had_unsafe=0
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*($|#) ]] && continue
    line=${line##+([[:space:]])}
    [[ $line == export[[:space:]]* ]] && line=${line#export}
    line=${line##+([[:space:]])}
    [[ $line =~ ^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*= ]] || continue
    if [[ $line == *\`* || $line == *\$\(* ]]; then
      printf 'UNSAFE:%s\n' "$line" >&2
      had_unsafe=1
      continue
    fi
    printf '%s\n' "$line"
  done
  (( had_unsafe == 0 ))
}

dotenv__strip_comments(){
  local line key val out c dq=0 sq=0 i

  local _restore
  _restore="$(shopt -p extglob 2>/dev/null || true)"
  shopt -s extglob

  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*($|#) ]] && continue
    line=${line##+([[:space:]])}
    [[ $line == export[[:space:]]* ]] && { line=${line#export}; line=${line##+([[:space:]])}; }
    [[ $line == *"="* ]] || continue

    key=${line%%=*}
    val=${line#*=}
    key=${key%%+([[:space:]])}
    [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

    out=''; dq=0; sq=0
    for (( i=0; i<${#val}; i++ )); do
      c=${val:i:1}
      if [[ $c == '"' && $sq -eq 0 ]]; then ((dq=1-dq)); out+='"'; continue; fi
      if [[ $c == "'" && $dq -eq 0 ]]; then ((sq=1-sq)); out+="'"; continue; fi
      if [[ $c == '#' && $dq -eq 0 && $sq -eq 0 ]]; then break; fi
      out+="$c"
    done
    out=${out##+([[:space:]])}
    out=${out%%+([[:space:]])}
    printf '%s=%s\n' "$key" "$out"
  done

  eval "${_restore:-:}"
}

dotenv__expand_value(){
  if [ "${DOTENV_EXPAND:-1}" = "1" ]; then
    eval "printf '%s\n' \"$1\""
  else
    printf '%s\n' "$1"
  fi
}

dotenv__preexisting_has(){
  printf '%s\n' "${PREEXISTING_KEYS-}" | awk -v k="$1" '($0==k){f=1} END{exit(f?0:1)}'
}

dotenv__csv_has(){
  local csv=",$1," key=",$2,"
  case "$csv" in *"$key"*) return 0;; *) return 1;; esac
}

dotenv__should_assign(){
  local key="${1-}"
  if [ -n "${DOTENV_FORCE_KEYS-}" ] && dotenv__csv_has "${DOTENV_FORCE_KEYS-}" "$key"; then return 0; fi
  if [ -n "${DOTENV_PROTECT_KEYS-}" ] && dotenv__csv_has "${DOTENV_PROTECT_KEYS-}" "$key"; then return 1; fi
  if [ "${DOTENV_NO_CLOBBER:-1}" = "1" ] && dotenv__preexisting_has "$key"; then return 1; fi

  return 0
}

dotenv__source_file(){
  local file="${1-}"
  [ -n "${file-}" ] || return 0
  [ -f "$file" ] || return 0

  local content
  content="$(
    set -o pipefail
    dotenv__reject_unsafe < "$file" | dotenv__strip_comments
  )" || { dotenv__log "ABORT: $file contains a dangerous line"; return 1; }

  content="${content%$'\n'}"$'\n'

  while IFS='=' read -r key val; do
    case "${key-}" in ''|*[!A-Za-z0-9_]* ) continue;; esac
    if [ -n "${val-}" ]; then
      case "$val" in
        \"*\") val="$(dotenv__expand_value "${val:1:${#val}-2}")" ;;
        \'*\') val="${val:1:${#val}-2}" ;;
        *)     val="$(dotenv__expand_value "$val")" ;;
      esac
    else
      val=""
    fi
    if dotenv__should_assign "$key"; then export "$key=$val"; fi
  done <<< "$content"
}

dotenv__snapshot_preexisting(){
  PREEXISTING_KEYS="$(env | awk -F= '{print $1}')"
}

dotenv__load(){
  local root="${1:-${DOTENV_ROOT:-.}}"
  dotenv__snapshot_preexisting
  local app_env="${APP_ENV:-}"
  local -a files=("$root/.env" "$root/.env.local")
  [ -n "$app_env" ] && files+=("$root/.env.$app_env" "$root/.env.$app_env.local")
  local f
  for f in "${files[@]}"; do
    case "$f" in *.local) [ "${CI:-0}" = "1" ] && continue ;; esac
    dotenv__source_file "$f" || return 1
  done
}

dotenv__print(){ env | sort; }

if [ "${DOTENV_AUTORUN:-1}" = "1" ]; then
  dotenv__load "${DOTENV_ROOT:-.}" || exit 1
fi
