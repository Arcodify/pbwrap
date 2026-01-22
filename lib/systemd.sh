#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

svc_name() { echo "pocketbase@$1"; }

install_systemd_unit() {
  local unit="/etc/systemd/system/pocketbase@.service"

  cat >"$unit" <<'UNITEOF'
[Unit]
Description=PocketBase instance (%i)
After=network.target

[Service]
Type=simple
User=%i
Group=%i
WorkingDirectory=/opt/pb_apps/%i
EnvironmentFile=/etc/pbwrap/instances.d/%i.env
ExecStart=/opt/pb_apps/%i/pocketbase serve --http=${PB_BIND}:${PB_PORT} --dir=/opt/pb_apps/%i/pb_data
Restart=on-failure
RestartSec=2

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/pb_apps/%i

[Install]
WantedBy=multi-user.target
UNITEOF

  systemctl daemon-reload
  echo "Installed: $unit"
}

svc_enable_start() {
  local app="$1"
  systemctl daemon-reload
  systemctl enable --now "$(svc_name "$app")"
}

svc_stop_disable() {
  local app="$1"
  systemctl stop "$(svc_name "$app")" || true
  systemctl disable "$(svc_name "$app")" || true
}

svc_status() { systemctl status "$(svc_name "$1")" --no-pager; }
svc_logs() { journalctl -u "$(svc_name "$1")" -n 200 --no-pager; }
