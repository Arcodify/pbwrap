#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
INSTALL_DIR="/opt/pbwrap"

# If installed via distro packaging where /usr/bin/pbwrap might not sit in /opt,
# fall back to the canonical install dir when libs are missing.
if [[ ! -f "$ROOT_DIR/lib/common.sh" && -d "$INSTALL_DIR/lib" ]]; then
  ROOT_DIR="$INSTALL_DIR"
fi

export PBWRAP_ROOT="$ROOT_DIR"

. "$ROOT_DIR/lib/common.sh"
. "$ROOT_DIR/lib/instances.sh"
. "$ROOT_DIR/lib/systemd.sh"

usage() {
  cat <<'USAGE'
pbwrap - PocketBase instance manager

Commands (non-interactive):
  help                              Show this help
  install-systemd                   Install/refresh pocketbase@.service
  template-init --src PATH          Copy existing PocketBase project into template base
  create -n NAME -p PORT [-b 127.0.0.1] [-V VER]
         [-e EMAIL -w PASS]
         [--domain DOMAIN]
         [--smtp-host HOST --smtp-port PORT --smtp-user USER --smtp-pass PASS --smtp-from FROM --smtp-tls true|false]
  admin-create -n NAME -e EMAIL -w PASS   Create superuser in an existing instance
  remove -n NAME [--force]          Remove instance (stops service, deletes dir/env)
  list                              List instances (from env files)
  show -n NAME                      Show instance env config
  status -n NAME                    systemctl status pocketbase@NAME
  logs -n NAME                      journalctl logs pocketbase@NAME
  start|stop|restart -n NAME        Manage service state
  uninstall [--purge] [--force]     Remove systemd unit + symlink (purge also removes code/config/data)
USAGE
}

ensure_root_for_command() {
  local cmd="$1"
  case "$cmd" in
  help) return 0 ;;
  *) need_root ;;
  esac
}

require_instance_env() {
  local app="${1:-}" envfile
  [[ -n "$app" ]] || die "Missing --name"
  envfile="$PBWRAP_INST_DIR/$app.env"
  [[ -f "$envfile" ]] || die "Env file not found: $envfile"
}

require_value() {
  local flag="$1" value="${2:-}"
  [[ -n "$value" ]] || die "Missing value for $flag"
}

ensure_next_arg() {
  local flag="$1" count="$2"
  [[ "$count" -ge 2 ]] || die "Missing value for $flag"
}

parse_admin_create_args() {
  ADMIN_NAME=""; ADMIN_EMAIL=""; ADMIN_PASSWORD=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --name|-n) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; ADMIN_NAME="$2"; shift 2 ;;
    --admin-email|--email|-e) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; ADMIN_EMAIL="$2"; shift 2 ;;
    --admin-password|--password|-w) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; ADMIN_PASSWORD="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown flag for admin-create: $1" ;;
    esac
  done
  [[ -n "$ADMIN_NAME" ]] || die "Missing --name"
  [[ -n "$ADMIN_EMAIL" ]] || die "Missing --admin-email"
  [[ -n "$ADMIN_PASSWORD" ]] || die "Missing --admin-password"
}

parse_create_args() {
  CREATE_NAME=""; CREATE_PORT=""; CREATE_BIND="127.0.0.1"; CREATE_VERSION="$(versions_default)"
  CREATE_ADMIN_EMAIL=""; CREATE_ADMIN_PASSWORD=""
  CREATE_DOMAIN=""
  CREATE_SMTP_HOST=""; CREATE_SMTP_PORT=""; CREATE_SMTP_USER=""; CREATE_SMTP_PASS=""; CREATE_SMTP_FROM=""; CREATE_SMTP_TLS=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --name|-n) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_NAME="$2"; shift 2 ;;
    --port|-p) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_PORT="$2"; shift 2 ;;
    --bind|-b) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_BIND="$2"; shift 2 ;;
    --version|-V) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_VERSION="$2"; shift 2 ;;
    --admin-email|-e) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_ADMIN_EMAIL="$2"; shift 2 ;;
    --admin-password|-w) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_ADMIN_PASSWORD="$2"; shift 2 ;;
    --domain|-d) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_DOMAIN="$2"; shift 2 ;;
    --smtp-host) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_SMTP_HOST="$2"; shift 2 ;;
    --smtp-port) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_SMTP_PORT="$2"; shift 2 ;;
    --smtp-user) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_SMTP_USER="$2"; shift 2 ;;
    --smtp-pass) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_SMTP_PASS="$2"; shift 2 ;;
    --smtp-from) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_SMTP_FROM="$2"; shift 2 ;;
    --smtp-tls) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; CREATE_SMTP_TLS="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown create flag: $1" ;;
    esac
  done
  [[ -n "$CREATE_NAME" ]] || die "Missing --name"
  [[ -n "$CREATE_PORT" ]] || die "Missing --port"
}

parse_name_only() {
  local flagname="$1"; shift
  NAME_ARG=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --name|-n) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; NAME_ARG="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown flag for $flagname: $1" ;;
    esac
  done
  [[ -n "$NAME_ARG" ]] || die "Missing --name"
}

parse_remove_args() {
  REMOVE_FORCE="true"; NAME_ARG=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --name|-n) ensure_next_arg "$1" "$#"; require_value "$1" "$2"; NAME_ARG="$2"; shift 2 ;;
    --force|--yes) REMOVE_FORCE="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown flag for remove: $1" ;;
    esac
  done
  [[ -n "$NAME_ARG" ]] || die "Missing --name"
}

parse_uninstall_args() {
  UNINSTALL_PURGE="false"; UNINSTALL_FORCE="false"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --purge) UNINSTALL_PURGE="true"; shift ;;
    --force|--yes) UNINSTALL_FORCE="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown flag for uninstall: $1" ;;
    esac
  done
}

perform_uninstall() {
  local purge="$1" force="$2"
  if [[ "$force" != "true" ]]; then
    die "Uninstall requires --force"
  fi

  if [[ -d "$PBWRAP_INST_DIR" ]]; then
    for env in "$PBWRAP_INST_DIR"/*.env; do
      [[ -e "$env" ]] || continue
      local app
      app="$(basename "$env" .env)"
      svc_stop_disable "$app" || true
    done
  fi

  local unit="/etc/systemd/system/pocketbase@.service"
  rm -f /usr/local/bin/pbwrap
  if [[ -f "$unit" ]]; then
    rm -f "$unit"
    systemctl daemon-reload
  fi

  if [[ "$purge" == "true" ]]; then
    rm -rf "$PBWRAP_ROOT" "$PBWRAP_ETC" "$PBWRAP_APPS"
  fi

  echo "Uninstall complete."
}

COMMAND="${1:-help}"
shift || true

ensure_root_for_command "$COMMAND"

if [[ "$COMMAND" != "help" && "$COMMAND" != "uninstall" ]]; then
  assert_installed
fi

case "$COMMAND" in
help|-h|--help)
  usage
  ;;
install-systemd)
  install_systemd_unit
  ;;
template-init)
  SRC_PATH=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --src) ensure_next_arg "$1" "$#"; SRC_PATH="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown flag for template-init: $1" ;;
    esac
  done
  [[ -n "$SRC_PATH" ]] || die "Missing --src"
  template_init_from_existing "$SRC_PATH"
  ;;
create)
  parse_create_args "$@"
  instance_create "$CREATE_NAME" "$CREATE_PORT" "$CREATE_BIND" "$CREATE_VERSION" \
    "$CREATE_ADMIN_EMAIL" "$CREATE_ADMIN_PASSWORD" \
    "$CREATE_DOMAIN" \
    "$CREATE_SMTP_HOST" "$CREATE_SMTP_PORT" "$CREATE_SMTP_USER" "$CREATE_SMTP_PASS" "$CREATE_SMTP_FROM" "$CREATE_SMTP_TLS"
  ;;
remove)
  parse_remove_args "$@"
  instance_remove "$NAME_ARG" "$REMOVE_FORCE"
  ;;
list)
  instance_list
  ;;
show)
  parse_name_only "show" "$@"
  instance_show "$NAME_ARG"
  ;;
status)
  parse_name_only "status" "$@"
  require_instance_env "$NAME_ARG"
  svc_status "$NAME_ARG"
  ;;
logs)
  parse_name_only "logs" "$@"
  require_instance_env "$NAME_ARG"
  svc_logs "$NAME_ARG"
  ;;
uninstall)
  parse_uninstall_args "$@"
  perform_uninstall "$UNINSTALL_PURGE" "$UNINSTALL_FORCE"
  ;;
start)
  parse_name_only "start" "$@"
  require_instance_env "$NAME_ARG"
  svc_start "$NAME_ARG"
  ;;
stop)
  parse_name_only "stop" "$@"
  require_instance_env "$NAME_ARG"
  svc_stop "$NAME_ARG"
  ;;
restart)
  parse_name_only "restart" "$@"
  require_instance_env "$NAME_ARG"
  svc_restart "$NAME_ARG"
  ;;
admin-create)
  parse_admin_create_args "$@"
  require_instance_env "$ADMIN_NAME"
  instance_admin_create "$ADMIN_NAME" "$ADMIN_EMAIL" "$ADMIN_PASSWORD"
  ;;
*)
  die "Unknown command: $COMMAND"
  ;;
esac
