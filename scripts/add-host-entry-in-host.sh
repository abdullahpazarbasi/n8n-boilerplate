#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/assert-running-in-bash.sh"

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "🛑  This script must be run with root permissions" >&2
    exit 1
fi

if [ "$#" -lt 2 ]; then
    echo "⚠️  Usage: $0 <hostname> <IP> [<comment>]" >&2
    exit 2
fi

HOSTNAME="$1"
IP="$2"
COMMENT="${3-}"

hosts_file_path="/etc/hosts"
tmp="$(mktemp)"

awk -v ip="${IP}" -v host="${HOSTNAME}" -v comment="${COMMENT}" '
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
' "${hosts_file_path}" > "${tmp}"

install -m 0644 "${tmp}" "${hosts_file_path}"
rm -f "${tmp}"

echo -n "📌  "
grep -E "^${IP}[[:space:]]" "${hosts_file_path}" | head -n1
