#!/usr/bin/env bash

# Usage: source is-debian.sh && is_debian && echo "Here is a Debian-based platform."
is_debian() {
  if command -v dpkg >/dev/null 2>&1; then
    return 0
  fi

  if [[ -f /etc/debian_version ]]; then
    return 0
  fi

  if grep -qi 'debian' /etc/os-release 2>/dev/null; then
    return 0
  fi

  if command -v lsb_release >/dev/null 2>&1 && lsb_release -is 2>/dev/null | grep -qi 'debian'; then
    return 0
  fi

  return 1
}
