# Installation Guide

Deploy PancakeSlicer as a **Custom App** on TrueNAS SCALE 24.10 (Electric Eel) or newer.

## Prerequisites

1. TrueNAS SCALE with Docker-based Apps (24.10 or newer).
2. A location for persistent state, writable by UID/GID `65532`.
3. A management machine with Git and Docker Compose for rendering, or `envsubst`.
4. Sufficient CPU and RAM. The default limit is 8 GB of memory and two concurrent
   slices. Slicing is CPU-intensive.

## Step 1: Clone the repository

Clone this private repository to a management machine (not necessarily TrueNAS
itself):

```bash
git clone <your-repo-url> pancake-slicer
cd pancake-slicer
```

## Step 2: Create host directories and permissions

PancakeSlicer runs as a fixed non-root user, **UID/GID 65532**. Create the data
and cache directories and give that user ownership:

```bash
mkdir -p /mnt/Apps/PancakeSlicer/data /mnt/Apps/PancakeSlicer/cache
chown -R 65532:65532 /mnt/Apps/PancakeSlicer
```

The paths above are the defaults in `.env.example`. If you use different paths,
update `PANCAKE_DATA_PATH` and `PANCAKE_CACHE_PATH` accordingly.

### TrueNAS ACL note

TrueNAS datasets often use NFSv4 ACLs. If the container logs `permission denied`
after the `chown`, add an ACL entry for UID 65532 in the TrueNAS UI
(**Datasets → Edit ACL → Add ACL Item**), granting modify access to the data
and cache directories. Alternatively, from the TrueNAS shell:

```bash
setfacl -R -m u:65532:rwx /mnt/Apps/PancakeSlicer
```

See [Storage](storage.md) for details.

## Step 3: Configure `.env`

```bash
cp .env.example .env
vi .env
```

At minimum, confirm:

- `PANCAKE_DATA_PATH` and `PANCAKE_CACHE_PATH`
- `PANCAKE_PORT` (default `6868`)
- `TZ`
- `PANCAKE_VERSION` (default `0.5.5`)

Optionally set `PANCAKE_BEARER_TOKEN` if anyone you do not trust can reach the
UI. Never commit `.env`.

## Step 4: Render the Compose file

```bash
./scripts/render-compose.sh
```

This creates `build/compose.yaml`, containing your real paths and any secrets.
The file is written with mode `600` and is gitignored. **Do not share it.**

## Step 5: Validate

```bash
./scripts/validate.sh
```

The script checks Compose validity, the pinned image, the port and volume
mappings, required environment variables, container hardening, the documentation
set, and accidental secrets.

## Step 6: Install as a TrueNAS Custom App

1. Log in to the TrueNAS SCALE UI.
2. Go to **Apps → Discover Apps**.
3. Choose **Install via YAML** (or the Custom App YAML editor).
4. Set the application name to `pancake-slicer`.
5. Paste the entire contents of `build/compose.yaml`.
6. Install the app.

TrueNAS may override the top-level `name:` field in the rendered file. That is
expected; the application name you enter in the UI is authoritative.

## Step 7: Verify

Check the container and health endpoint:

```bash
docker ps --filter name=pancake
docker logs -f <container-name>
curl -fsS http://<TRUENAS_IP>:6868/api/healthz
```

The health response should contain `"status":"ok"`. After the engine finishes its
release qualification, `"artifact_state":"qualified"` appears as well. If the
engine has not qualified yet, wait for startup to finish and check the logs.

Open `http://<TRUENAS_IP>:6868` in a browser.

## Step 8: First-run setup

1. Open the UI.
2. Add your printers by IP address. Automatic discovery does not cross the Docker
   bridge network; see [Printers](printers.md).
3. For Bambu Lab printers in LAN-only mode, enter the printer IP and LAN access
   code.
4. Review or import profiles and filaments, then run a test slice.

## Updating

See [Upgrades & Maintenance](upgrades.md). In short:

1. Change `PANCAKE_VERSION` in `.env`.
2. Re-run `./scripts/render-compose.sh` and `./scripts/validate.sh`.
3. Edit the installed app and paste the new `build/compose.yaml`.
4. Re-deploy and verify `/api/healthz`.
