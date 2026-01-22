#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/pbwrap"

# Load helpers from source tree (prior to copy)
. "$SRC_DIR/lib/common.sh"

need_root

# Dependency check (no implicit installs)
for bin in bash curl unzip jq rsync; do
  require_bin "$bin"
done

echo "Copying pbwrap to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Preserve admin-managed files (versions.json, template base)
rsync -a --delete \
  --exclude "config/versions.json" \
  --exclude "templates/base/" \
  "$SRC_DIR"/ "$INSTALL_DIR"/

# Re-source from installed location to lock paths
export PBWRAP_ROOT="$INSTALL_DIR"
export PBWRAP_APPS="/opt/pb_apps"
export PBWRAP_ETC="/etc/pbwrap"
. "$INSTALL_DIR/lib/common.sh"
. "$INSTALL_DIR/lib/systemd.sh"

ensure_dirs

# Copy default versions file if missing
[[ -f "$PBWRAP_VERSIONS_DEFAULT" ]] || die "Missing default versions file: $PBWRAP_VERSIONS_DEFAULT"
if [[ ! -f "$PBWRAP_VERSIONS_FILE" ]]; then
  cp "$PBWRAP_VERSIONS_DEFAULT" "$PBWRAP_VERSIONS_FILE"
  echo "Created $PBWRAP_VERSIONS_FILE"
else
  echo "Keeping existing $PBWRAP_VERSIONS_FILE"
fi

# Ensure template ignore exists
if [[ ! -f "$PBWRAP_IGNORE_FILE" ]]; then
  cat >"$PBWRAP_IGNORE_FILE" <<'EOF'
pb_data
*.db
*.db-shm
*.db-wal
EOF
  echo "Created $PBWRAP_IGNORE_FILE"
fi

# Ensure template base dir exists
mkdir -p "$PBWRAP_TPL_BASE"

# Install/refresh systemd unit
install_systemd_unit

# Make sure executables are runnable
chmod +x "$INSTALL_DIR/install.sh" "$INSTALL_DIR/pbwrap.sh" "$INSTALL_DIR"/lib/*.sh
chmod +x "$INSTALL_DIR"/scripts/*.sh 2>/dev/null || true

# Symlink CLI
ln -sf "$INSTALL_DIR/pbwrap.sh" /usr/local/bin/pbwrap
echo "Symlinked /usr/local/bin/pbwrap -> $INSTALL_DIR/pbwrap.sh"

echo "Install completed successfully."
