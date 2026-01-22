# pbwrap

**pbwrap** is a non-interactive CLI tool for managing multiple **PocketBase** instances on a VPS.
It is designed to be simple, reproducible, and systemd-native.

Each PocketBase app runs as a **systemd template instance** (`pocketbase@<name>.service`), with its own binary version, environment file, and data directory.

---

## Key Features

* Create a reusable **PocketBase template** from an existing project directory

  * Copies the PocketBase binary
  * Optionally copies `migrations/` and `hooks/`
  * Excludes `pb_data/`
* Create, list, remove, and manage **multiple PocketBase instances**
* Run each instance as a **systemd template unit**
* Download and pin a **specific PocketBase version per instance**

  * Versions are defined in `config/versions.json`
* Store per-instance configuration in simple `.env` files
* Designed for **VPS / server usage** (non-interactive, scriptable)

---

## Directory Layout (on the server)

pbwrap uses fixed, predictable paths:

* **pbwrap installation**

  ```
  /opt/pbwrap
  ```

* **PocketBase application instances**

  ```
  /opt/pb_apps/<instance>
  ```

* **Instance environment files**

  ```
  /etc/pbwrap/instances.d/<instance>.env
  ```

* **systemd template unit**

  ```
  /etc/systemd/system/pocketbase@.service
  ```

---

## Server Requirements

The following tools must be installed on the server:

* bash
* curl
* unzip
* jq
* rsync
* systemd

On Debian/Ubuntu:

```bash
apt-get update && apt-get install -y curl unzip jq rsync
```

---

## Quick Start (on the server)

### 1. Install dependencies

```bash
apt-get update && apt-get install -y curl unzip jq rsync
```

---

### 2. Install pbwrap

From the extracted release directory:

```bash
sudo ./install.sh
```

This will:

* Copy pbwrap to `/opt/pbwrap`
* Symlink `pbwrap` to `/usr/local/bin/pbwrap`

---

### 3. Install or refresh the systemd unit

```bash
sudo pbwrap install-systemd
```

This installs the `pocketbase@.service` systemd template unit.

---

### 4. (Optional) Initialize a template from an existing project

If you already have a PocketBase project directory:

```bash
sudo pbwrap template-init --src /path/to/project
```

This creates a reusable template used for future instances.

---

### 5. Create a PocketBase instance

Example:

```bash
sudo pbwrap create \
  -n test \
  -p 8091 \
  -b 127.0.0.1 \
  -V 0.36.1 \
  -e admin@example.com \
  -w secret \
  --domain example.com \
  --smtp-host smtp.example.com \
  --smtp-port 587 \
  --smtp-user user \
  --smtp-pass pass \
  --smtp-from noreply@example.com \
  --smtp-tls true
```

This will:

* Download the specified PocketBase version
* Create `/opt/pb_apps/test`
* Write configuration to `/etc/pbwrap/instances.d/test.env`
* Enable and start `pocketbase@test.service`

---

## Common Commands

### List all instances

```bash
sudo pbwrap list
```

---

### Show instance configuration

```bash
sudo pbwrap show -n test
```

---

### Start / Stop / Restart an instance

```bash
sudo pbwrap start   -n test
sudo pbwrap stop    -n test
sudo pbwrap restart -n test
```

---

### Check status or view logs

```bash
sudo pbwrap status -n test
sudo pbwrap logs   -n test
```

---

### Create an admin user

```bash
sudo pbwrap admin-create -n test -e admin@example.com -w secret
```

---

### Remove an instance

```bash
sudo pbwrap remove -n test --force
```

This stops the service and deletes the instance directory and config.

---

### Uninstall pbwrap

```bash
sudo pbwrap uninstall --force [--purge]
```

* `--force` removes pbwrap binaries
* `--purge` also removes `/etc/pbwrap` and instance data

---

## Arch Linux / pacman Packaging

A `PKGBUILD` is included.

### Build and install locally

```bash
makepkg -si
```

The package uses the current directory as its source via `git+file://`.

After installation, run once:

```bash
sudo /opt/pbwrap/install.sh
```

This ensures required directories under `/etc` are created (safe to run multiple times).

---

## Remote Usage (SSH helper)

pbwrap includes a helper script for running commands over SSH:

```bash
scripts/pbwrap-ssh.sh user@host -- <pbwrap arguments>
```

Example:

```bash
scripts/pbwrap-ssh.sh root@server -- create -n test -p 8091 -V 0.36.1
```

The script automatically runs `sudo pbwrap ...` on the remote host.

---

## Design Notes

* pbwrap is intentionally **non-interactive**
* All state lives in:

  * `/opt/pb_apps`
  * `/etc/pbwrap`
* systemd is the single source of truth for process management
* Designed to be safe for automation and CI-style provisioning
