#!/usr/bin/env bash
set -euo pipefail

PBWRAP_ROOT_DEFAULT="/opt/pbwrap"
PBWRAP_APPS_DEFAULT="/opt/pb_apps"
PBWRAP_ETC_DEFAULT="/etc/pbwrap"

PBWRAP_ROOT="${PBWRAP_ROOT:-$PBWRAP_ROOT_DEFAULT}"
PBWRAP_APPS="${PBWRAP_APPS:-$PBWRAP_APPS_DEFAULT}"
PBWRAP_ETC="${PBWRAP_ETC:-$PBWRAP_ETC_DEFAULT}"

PBWRAP_INST_DIR="${PBWRAP_ETC}/instances.d"
PBWRAP_TPL_BASE="${PBWRAP_ROOT}/templates/base"
PBWRAP_CONFIG_DIR="${PBWRAP_ROOT}/config"
PBWRAP_VERSIONS_FILE="${PBWRAP_CONFIG_DIR}/versions.json"
PBWRAP_VERSIONS_DEFAULT="${PBWRAP_CONFIG_DIR}/versions.default.json"
PBWRAP_IGNORE_FILE="${PBWRAP_CONFIG_DIR}/template.ignore"

die() {
  echo "ERROR: $*" >&2
  exit 1
}
need_root() { [[ "$(id -u)" -eq 0 ]] || die "Run as root."; }
require_bin() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

ensure_dirs() {
  mkdir -p "$PBWRAP_ROOT" "$PBWRAP_APPS" "$PBWRAP_ETC" "$PBWRAP_INST_DIR" "$PBWRAP_TPL_BASE" "$PBWRAP_CONFIG_DIR"
}

arch_tag() {
  local m
  m="$(uname -m)"
  case "$m" in
  x86_64 | amd64) echo "linux_amd64" ;;
  aarch64 | arm64) echo "linux_arm64" ;;
  armv7l | armv6l) echo "linux_armv7" ;;
  *) die "Unsupported arch: $m" ;;
  esac
}

prompt() {
  local __var="$1" msg="$2" def="${3:-}"
  local val
  if [[ -n "$def" ]]; then
    read -r -p "$msg [$def]: " val || true
    val="${val:-$def}"
  else
    read -r -p "$msg: " val || true
  fi
  [[ -n "${val:-}" ]] || die "Empty value not allowed."
  printf -v "$__var" "%s" "$val"
}

confirm() {
  local msg="$1" ans
  read -r -p "$msg (yes/no): " ans || true
  [[ "${ans:-}" == "yes" ]] || die "Aborted."
}

is_valid_name() {
  local s="$1"
  [[ "$s" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

assert_valid_name() {
  local s="$1"
  is_valid_name "$s" || die "Invalid instance name '$s'. Use: [a-z_][a-z0-9_-]{0,31}"
}

assert_installed() {
  local unit_etc="/etc/systemd/system/pocketbase@.service"
  local unit_lib="/usr/lib/systemd/system/pocketbase@.service"
  [[ -f "$unit_etc" || -f "$unit_lib" ]] || die "Not installed. Run: sudo /opt/pbwrap/install.sh"
  [[ -d "$PBWRAP_INST_DIR" ]] || die "Not installed. Run: sudo /opt/pbwrap/install.sh"
  [[ -f "$PBWRAP_VERSIONS_FILE" ]] || die "Missing versions.json. Run: sudo /opt/pbwrap/install.sh"
}
