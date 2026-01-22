#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIB_DIR/common.sh"
. "$LIB_DIR/github.sh"
. "$LIB_DIR/systemd.sh"

versions_default() {
  [[ -f "$PBWRAP_VERSIONS_FILE" ]] || die "Missing $PBWRAP_VERSIONS_FILE"
  jq -r ".default" "$PBWRAP_VERSIONS_FILE"
}

versions_list() {
  [[ -f "$PBWRAP_VERSIONS_FILE" ]] || die "Missing $PBWRAP_VERSIONS_FILE"
  jq -r ".versions[]" "$PBWRAP_VERSIONS_FILE"
}

# Non-interactive fallback picker: returns default version
pick_version() {
  versions_default
}

ensure_app_user() {
  local app="$1"
  if ! id -u "$app" >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "/var/lib/$app" --shell /usr/sbin/nologin "$app"
  fi
}

template_init_from_existing() {
  local src="$1"

  # Normalize relative paths for local testing
  if [[ "$src" != /* ]]; then
    src="$(cd "$src" 2>/dev/null && pwd)" || die "Source dir not found: $1"
  fi

  [[ -d "$src" ]] || die "Source dir not found: $src"

  # Must contain the pocketbase binary
  [[ -f "$src/pocketbase" ]] || die "No pocketbase binary found at: $src/pocketbase"

  mkdir -p "$PBWRAP_TPL_BASE"
  rsync -a --delete \
    --exclude-from="$PBWRAP_IGNORE_FILE" \
    "$src/" "$PBWRAP_TPL_BASE/"

  chmod +x "$PBWRAP_TPL_BASE/pocketbase"
  echo "Template updated: $PBWRAP_TPL_BASE"
}

instance_create() {
  local app="$1" port="$2" bind="$3" version="$4"
  local admin_email="${5:-}" admin_password="${6:-}"
  local domain="${7:-}"
  local smtp_host="${8:-}" smtp_port="${9:-}" smtp_user="${10:-}" smtp_pass="${11:-}" smtp_from="${12:-}" smtp_tls="${13:-}"
  assert_valid_name "$app"

  local appdir="$PBWRAP_APPS/$app"
  local envfile="$PBWRAP_INST_DIR/$app.env"

  [[ "$port" =~ ^[0-9]+$ ]] || die "Port must be a number."
  ((port >= 1 && port <= 65535)) || die "Port must be between 1 and 65535."
  [[ -n "$bind" ]] || die "Bind address cannot be empty."
  [[ -n "$version" ]] || die "Version cannot be empty."

  [[ -e "$appdir" ]] && die "App directory exists: $appdir"
  [[ -e "$envfile" ]] && die "Env file already exists: $envfile"
  [[ -f /etc/systemd/system/pocketbase@.service ]] || die "Missing systemd unit. Install via pbwrap.sh --install-systemd"

  if [[ -n "$admin_email" || -n "$admin_password" ]]; then
    [[ -n "$admin_email" && -n "$admin_password" ]] || die "Admin email and password must both be provided."
  fi
  if [[ -n "$smtp_port" ]]; then
    [[ "$smtp_port" =~ ^[0-9]+$ ]] || die "SMTP port must be numeric."
  fi

  ensure_dirs
  ensure_app_user "$app"
  mkdir -p "$appdir"

  # Template is optional
  if [[ -f "$PBWRAP_TPL_BASE/pocketbase" || -d "$PBWRAP_TPL_BASE/pb_migrations" || -d "$PBWRAP_TPL_BASE/pb_hooks" ]]; then
    echo "Using template: $PBWRAP_TPL_BASE"
    rsync -a --exclude-from="$PBWRAP_IGNORE_FILE" "$PBWRAP_TPL_BASE/" "$appdir/" || true
  else
    echo "No template found. Creating blank instance."
  fi

  pb_download_version "$version" "$appdir"

  mkdir -p "$appdir/pb_data"
  chown -R "$app:$app" "$appdir"

  cat >"$envfile" <<EOV
PB_PORT=$port
PB_BIND=$bind
PB_VERSION=$version
EOV
  [[ -n "$domain" ]] && echo "PB_DOMAIN=$domain" >>"$envfile"
  [[ -n "$smtp_host" ]] && echo "SMTP_HOST=$smtp_host" >>"$envfile"
  [[ -n "$smtp_port" ]] && echo "SMTP_PORT=$smtp_port" >>"$envfile"
  [[ -n "$smtp_user" ]] && echo "SMTP_USER=$smtp_user" >>"$envfile"
  [[ -n "$smtp_pass" ]] && echo "SMTP_PASS=$smtp_pass" >>"$envfile"
  [[ -n "$smtp_from" ]] && echo "SMTP_FROM=$smtp_from" >>"$envfile"
  [[ -n "$smtp_tls" ]] && echo "SMTP_TLS=$smtp_tls" >>"$envfile"
  chmod 640 "$envfile"

  # Optional initial superuser
  if [[ -n "$admin_email" ]]; then
    runuser -u "$app" -- "$appdir/pocketbase" --dir "$appdir/pb_data" superuser create "$admin_email" "$admin_password"
  fi

  svc_enable_start "$app"

  echo "Created instance: $app"
  echo "  dir: $appdir"
  echo "  env: $envfile"
  echo "  service: pocketbase@$app"
}

instance_remove() {
  local app="$1"
  local force="${2:-false}"
  assert_valid_name "$app"

  local appdir="$PBWRAP_APPS/$app"
  local envfile="$PBWRAP_INST_DIR/$app.env"

  [[ -d "$appdir" ]] || die "Not found: $appdir"

  if [[ "$force" != "true" ]]; then
    confirm "Stop service and delete instance directory + env file for '$app'"
  fi
  svc_stop_disable "$app"
  rm -rf "$appdir"
  rm -f "$envfile"
  echo "Removed instance: $app"
}

instance_list() {
  echo "Instances (from $PBWRAP_INST_DIR):"
  if [[ -d "$PBWRAP_INST_DIR" ]]; then
    ls -1 "$PBWRAP_INST_DIR" 2>/dev/null | sed -n "s/\.env$//p" || true
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

instance_admin_create() {
  local app="$1" email="$2" password="$3"
  assert_valid_name "$app"
  [[ -n "$email" && -n "$password" ]] || die "Email and password required."

  local appdir="$PBWRAP_APPS/$app"
  [[ -x "$appdir/pocketbase" ]] || die "PocketBase binary missing at $appdir/pocketbase"
  [[ -d "$appdir/pb_data" ]] || mkdir -p "$appdir/pb_data"

  runuser -u "$app" -- "$appdir/pocketbase" --dir "$appdir/pb_data" superuser create "$email" "$password"
  echo "Superuser created for $app ($email)"
}
