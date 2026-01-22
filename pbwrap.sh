#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/lib/common.sh"
. "$ROOT_DIR/lib/systemd.sh"
. "$ROOT_DIR/lib/instances.sh"

need_root
require_bin bash
require_bin curl
require_bin unzip
require_bin jq
require_bin rsync

ensure_dirs

usage() {
  cat <<USAGE
pbwrap

Interactive:
  pbwrap

Non-interactive:
  pbwrap --install-systemd
USAGE
}

menu() {
  echo
  echo "pbwrap menu"
  echo "  1) Install systemd template unit (pocketbase@.service)"
  echo "  2) Init/Update template from existing PocketBase project"
  echo "  3) Create instance"
  echo "  4) Remove instance"
  echo "  5) List instances"
  echo "  6) Show instance config"
  echo "  7) Service status"
  echo "  8) Service logs"
  echo "  9) Exit"
  echo
  read -r -p "Select: " choice || true
  echo "${choice:-}"
}

main_interactive() {
  while true; do
    c="$(menu)"
    case "$c" in
    1)
      install_systemd_unit
      ;;
    2)
      prompt SRC "Source project path" "/opt/pocketbase"
      template_init_from_existing "$SRC"
      ;;
    3)
      prompt APP "Instance name (linux username will match)"
      prompt PORT "Port" "8091"
      prompt BIND "Bind address" "127.0.0.1"
      VERSION="$(pick_version)"
      instance_create "$APP" "$PORT" "$BIND" "$VERSION"
      ;;
    4)
      prompt APP "Instance name to remove"
      instance_remove "$APP"
      ;;
    5)
      instance_list
      ;;
    6)
      prompt APP "Instance name"
      instance_show "$APP"
      ;;
    7)
      prompt APP "Instance name"
      svc_status "$APP"
      ;;
    8)
      prompt APP "Instance name"
      svc_logs "$APP"
      ;;
    9)
      exit 0
      ;;
    *)
      echo "Invalid choice."
      ;;
    esac
  done
}

main() {
  if [[ "${1:-}" == "--install-systemd" ]]; then
    install_systemd_unit
    exit 0
  fi

  if [[ $# -gt 0 ]]; then
    usage
    exit 1
  fi

  main_interactive
}

main "$@"
