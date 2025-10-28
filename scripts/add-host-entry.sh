#!/usr/bin/env bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌  This script must be run with root permissions" >&2
    exit 1
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <hostname> <IP> [<comment>]" >&2
    exit 2
fi

HOSTNAME="$1"
IP="$2"
COMMENT="${3-}"
HOSTS_FILE_PATH="/etc/hosts"
TEMPORARY_FILE_PATH="$(mktemp)"

awk -v ip="$IP" -v host="$HOSTNAME" -v comment="$COMMENT" '
BEGIN { updated=0; found=0 }
$1==ip {
  has=0
  for (i=2; i<=NF; i++) {
    if ($i==host) { has=1; break }
    if ($i=="#") break
  }
  if (has==1) {
    found=1
    print $0
    next
  }
  line=""
  cmt=""
  for (i=1;i<=NF;i++){
    if ($i=="#"){
      for (j=i;j<=NF;j++) cmt=cmt (j==i?"":" ") $j
      break
    }
    line=line (i==1?"":" ") $i
  }
  if (cmt=="") {
    if (comment!="") cmt=" # " comment
  }
  print line " " host cmt
  updated=1
  next
}
{ print }
END {
  if (found==0 && updated==0) {
    if (comment!="") {
      print ip " " host " # " comment
    } else {
      print ip " " host
    }
  }
}
' "$HOSTS_FILE_PATH" > "$TEMPORARY_FILE_PATH"

install -m 0644 "$TEMPORARY_FILE_PATH" "$HOSTS_FILE_PATH"
rm -f "$TEMPORARY_FILE_PATH"

grep -E "^${IP}[[:space:]]" "$HOSTS_FILE_PATH" | head -n1 && echo "✅"
