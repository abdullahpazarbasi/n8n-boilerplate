#!/usr/bin/env bash

# Usage: source is-darwin.sh && is_darwin && echo "Here is a macOS platform."
is_darwin() {
  if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
    return 0
  fi

  if command -v sw_vers >/dev/null 2>&1; then
    return 0
  fi

  if [[ -f /System/Library/CoreServices/SystemVersion.plist ]]; then
    return 0
  fi

  return 1
}
