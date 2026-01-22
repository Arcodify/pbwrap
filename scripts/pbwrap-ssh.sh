#!/usr/bin/env bash
set -euo pipefail

# Minimal SSH wrapper to run pbwrap commands on a remote host.
# Usage: pbwrap-ssh.sh user@host -- pbwrap args...

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 user@host -- <pbwrap args...>" >&2
  exit 1
fi

REMOTE="$1"
shift
[[ "$1" == "--" ]] || { echo "Missing -- separator before pbwrap args" >&2; exit 1; }
shift

if [[ $# -lt 1 ]]; then
  echo "No pbwrap arguments provided" >&2
  exit 1
fi

cmd=$(printf '%q ' "$@")
ssh "$REMOTE" "sudo pbwrap $cmd"
