#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ] || [ -z "$BASH" ]; then
	echo "🛑  This script can only be run on bash" >&2
	echo "💡  Please use this script like that:" >&2
	echo "    bash $0 $@" >&2
	exit 1
fi

required_major=4
current_major="${BASH_VERSINFO[0]:-0}"

if (( current_major < required_major )); then
	echo "🛑  The current bash version is too old: ${BASH_VERSION}" >&2
	echo "💡  ${required_major}.0 or newer is required." >&2
	exit 2
fi

# Uncomment the line below (optional):
# exec bash "$0" "$@"
