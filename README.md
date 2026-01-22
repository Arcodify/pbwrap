pbwrap

Interactive PocketBase instance manager for a VPS.

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
2) Install pbwrap:
   ln -sf /opt/pbwrap/pbwrap.sh /usr/local/bin/pbwrap
3) Install systemd unit:
   /opt/pbwrap/pbwrap.sh --install-systemd
4) Initialize template from existing PocketBase project folder (example /opt/pocketbase):
   pbwrap
   -> Init/Update template
5) Create instance:
   pbwrap
   -> Create instance
