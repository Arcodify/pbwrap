pbwrap

PocketBase instance manager for a VPS (non-interactive CLI).

What it does
- Creates a reusable template from an existing PocketBase project folder (copies binary + optional migrations/hooks, excludes pb_data).
- Creates/removes/list/manages multiple PocketBase instances as systemd template units: pocketbase@<name>.service
- Downloads a chosen PocketBase version per instance (pinned list in config/versions.json).
- Stores instance configs in /etc/pbwrap/instances.d/<name>.env

Target paths on server
- /opt/pbwrap (this repo)
- /opt/pb_apps/<instance> (instance directories)
- /etc/pbwrap/instances.d/<instance>.env (instance env)
- /etc/systemd/system/pocketbase@.service (systemd template unit)

Dependencies on server
- bash, curl, unzip, jq, rsync, systemd
Quick start (on server)
1) Install deps:
   apt-get update && apt-get install -y curl unzip jq rsync
2) Install pbwrap from the extracted release directory:
   sudo ./install.sh   # copies pbwrap into /opt/pbwrap and symlinks /usr/local/bin/pbwrap
3) Install/refresh systemd unit:
   sudo pbwrap install-systemd
4) Initialize template from an existing PocketBase project folder (optional):
   sudo pbwrap template-init --src /path/to/project
5) Create an instance (example):
   sudo pbwrap create -n test -p 8091 -b 127.0.0.1 -V 0.36.1 \
     -e admin@example.com -w secret \
     --domain example.com \
     --smtp-host smtp.example.com --smtp-port 587 --smtp-user user --smtp-pass pass --smtp-from noreply@example.com --smtp-tls true

Other commands
- List:               sudo pbwrap list
- Show config:        sudo pbwrap show -n test
- Remove:             sudo pbwrap remove -n test --force
- Start/Stop/Restart: sudo pbwrap start -n test | stop -n test | restart -n test
- Status/logs:        sudo pbwrap status -n test | pbwrap logs -n test
- Create admin:       sudo pbwrap admin-create -n test -e admin@example.com -w secret
- Uninstall pbwrap:   sudo pbwrap uninstall --force [--purge]

Arch/pacman packaging
- Build/install locally: `makepkg -si` (uses the included PKGBUILD; source is the current directory via git+file://).
- After install, run `sudo /opt/pbwrap/install.sh` once to ensure /etc dirs are created (idempotent).

Remote helper
- Run pbwrap over SSH: `scripts/pbwrap-ssh.sh user@host -- <pbwrap args>` (wrapper will prepend `sudo pbwrap ...` on the remote).
