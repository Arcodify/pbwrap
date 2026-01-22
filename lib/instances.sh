#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/github.sh"
. "$(dirname "$0")/systemd.sh"

versions_default() {
  [[ -f "$PBWRAP_VERSIONS_FILE" ]] || die "Missing $PBWRAP_VERSIONS_FILE"
  jq -r ".default" "$PBWRAP_VERSIONS_FILE"
}

versions_list() {
  [[ -f "$PBWRAP_VERSIONS_FILE" ]] || die "Missing $PBWRAP_VERSIONS_FILE"
  jq -r ".versions[]" "$PBWRAP_VERSIONS_FILE"
}

pick_version() {
  local def ver
  def="$(versions_default)"

  echo "Available versions:"
  local i=1
  while read -r ver; do
    echo "  [$i] $ver"
    i=$((i + 1))
  done < <(versions_list)
  echo "  [0] custom"

  local choice
  read -r -p "Select version number [$def]: " choice || true
  choice="${choice:-}"

  if [[ -z "$choice" ]]; then
    echo "$def"
    return
  fi
  if [[ "$choice" == "0" ]]; then
    read -r -p "Enter version (e.g. 0.36.1): " ver || true
    [[ -n "${ver:-}" ]] || die "Empty version."
    echo "$ver"
    return
  fi

  local idx=1
  while read -r ver; do
    if [[ "$idx" == "$choice" ]]; then
      echo "$ver"
      return
    fi
    idx=$((idx + 1))
  done < <(versions_list)

  die "Invalid selection."
}

ensure_app_user() {
  local app="$1"
  if ! id -u "$app" >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "/var/lib/$app" --shell /usr/sbin/nologin "$app"
  fi
}

template_init_from_existing() {
  local src="$1"
  [[ -d "$src" ]] || die "Source dir not found: $src"

  mkdir -p "$PBWRAP_TPL_BASE"
  rsync -a --delete \
    --exclude-from="$PBWRAP_IGNORE_FILE" \
    "$src/" "$PBWRAP_TPL_BASE/"

  [[ -f "$PBWRAP_TPL_BASE/pocketbase" ]] || die "Template missing pocketbase binary."
  chmod +x "$PBWRAP_TPL_BASE/pocketbase"
  echo "Template updated: $PBWRAP_TPL_BASE"
}

instance_create() {
  local app="$1" port="$2" bind="$3" version="$4"
  assert_valid_name "$app"

  local appdir="$PBWRAP_APPS/$app"
  local envfile="$PBWRAP_INST_DIR/$app.env"

  [[ -e "$appdir" ]] && die "App directory exists: $appdir"
  [[ -f /etc/systemd/system/pocketbase@.service ]] || die "Missing systemd unit. Install via pbwrap.sh --install-systemd"
  [[ -f "$PBWRAP_TPL_BASE/pocketbase" ]] || die "Template missing. Run template init first."

  ensure_app_user "$app"

  mkdir -p "$appdir"
  rsync -a "$PBWRAP_TPL_BASE/" "$appdir/"

  pb_download_version "$version" "$appdir"

  mkdir -p "$appdir/pb_data"
  chown -R "$app:$app" "$appdir"

  cat >"$envfile" <<EOF
PB_PORT=$port
PB_BIND=$bind
PB_VERSION=$version
EOF
  chmod 640 "$envfile"

  svc_enable_start "$app"

  echo "Created instance: $app"
  echo "  dir: $appdir"
  echo "  env: $envfile"
  echo "  service: pocketbase@$app"
}

instance_remove() {
  local app="$1"
  assert_valid_name "$app"

  local appdir="$PBWRAP_APPS/$app"
  local envfile="$PBWRAP_INST_DIR/$app.env"

  [[ -d "$appdir" ]] || die "Not found: $appdir"

  confirm "Stop service and delete instance directory + env file for '$app'"
  svc_stop_disable "$app"
  rm -rf "$appdir"
  rm -f "$envfile"
  echo "Removed instance: $app"
}

instance_list() {
  echo "Instances (from $PBWRAP_INST_DIR):"
  if [[ -d "$PBWRAP_INST_DIR" ]]; then
    ls -1 "$PBWRAP_INST_DIR" 2>/dev/null | sed -n 's/\.env$//p' || true
  fi
}

instance_show() {
  local app="$1"
  assert_valid_name "$app"

  local envfile="$PBWRAP_INST_DIR/$app.env"
  [[ -f "$envfile" ]] || die "Not found: $envfile"
  echo "Config for '$app':"
  cat "$envfile"
}
EOF
