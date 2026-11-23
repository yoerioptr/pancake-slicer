# PancakeSlicer on TrueNAS SCALE

A small, reproducible, security-conscious package for self-hosting
[PancakeSlicer](https://github.com/ZimengXiong/PancakeSlicer) as a
**TrueNAS SCALE custom app**.

It wraps the upstream multi-arch image in an `.env`-driven Compose template with
render and validation scripts, container hardening, operator documentation, and
a TrueNAS-specific deployment guide.

> This project is a deployment wrapper. It is not affiliated with PancakeSlicer
> or its maintainers.

## What You Get

- **One container** from the upstream multi-arch image, pinned to `0.5.5`.
- **Browser access** at `http://<TRUENAS_IP>:6868`.
- **Persistent state** in `${PANCAKE_DATA_PATH}` — projects, profiles, printers,
  preferences, and finished jobs.
- **Disposable slice cache** in `${PANCAKE_CACHE_PATH}`, excluded from backups.
- **Secure defaults** — non-root execution (UID/GID `65532`),
  `no-new-privileges`, all capabilities dropped, no Docker socket, no privileged
  mode, and an 8 GB memory limit.
- **Optional bearer token** for mutation requests and reverse-proxy support.
- **TrueNAS integration** — generated YAML includes `x-portals` for an **Open**
  button on the Installed Apps page.

## Architecture

```text
Browser (LAN or VPN)
        │  HTTP :6868
        ▼
pancakeslicer container
  ├── /data .................... persistent state
  └── /data/jobs/stage-cache ... disposable cache
        │
        ▼
/mnt/Apps/PancakeSlicer/{data,cache} on TrueNAS
```

Only one service is defined. There is no database, VPN namespace, or
inter-service network to maintain.

## Supported Platforms

- **TrueNAS SCALE 24.10 (Electric Eel) or newer** — Docker-based Apps.
- **Generic Docker Compose** — any Linux host with Docker Compose v2.
- **Architectures** — `amd64` and `arm64` (the image is multi-arch).

## Relationship to the Upstream `deploy/` Folder

Upstream's `deploy/docker-compose.yml` runs one container, publishes port
`6868`, and stores state in a named volume. This wrapper adapts it for TrueNAS
by:

- replacing the named volume with host-path bind mounts under `/mnt`;
- splitting the disposable stage cache into its own host path;
- pinning the image tag and adding container hardening and a memory limit;
- adding the render step, because TrueNAS does not expand `.env` variables.

Upstream's `deploy/Dockerfile` is a maintainer build that requires staged engine
artifacts. It is not used here; this wrapper consumes the published multi-arch
image. The upstream `docker-compose.proxy.yml`/Caddy setup is not included by
default because TrueNAS normally occupies ports 80/443. See
[Reverse Proxy](docs/reverse-proxy.md) if you want HTTPS.

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/yoerioptr/pancake-slicer.git
cd pancake-slicer
```

### 2. Create and edit `.env`

```bash
./scripts/init-env.sh
vi .env
```

`init-env.sh` copies `.env.example`, generates a random
`PANCAKE_BEARER_TOKEN`, and sets the file to mode `600`. Review at minimum:

- `PANCAKE_DATA_PATH` / `PANCAKE_CACHE_PATH` — host paths under `/mnt`.
- `PANCAKE_PORT` — host port for the web UI.
- `TZ` — your timezone.
- `PANCAKE_VERSION` — the pinned upstream release.

If you prefer to manage the token yourself:

```bash
cp .env.example .env
chmod 600 .env
vi .env
```

### 3. Create host directories on TrueNAS

The image runs as UID/GID `65532`:

```bash
mkdir -p /mnt/Apps/PancakeSlicer/data /mnt/Apps/PancakeSlicer/cache
chown -R 65532:65532 /mnt/Apps/PancakeSlicer
```

See [Storage](docs/storage.md) for ACL notes.

### 4. Render and validate

```bash
./scripts/render-compose.sh
./scripts/validate.sh
```

The render step creates a gitignored `build/compose.yaml` containing your real
paths and any token. It is written with mode `600`.

### 5. Install as a TrueNAS custom app

1. Go to **Apps → Discover Apps**.
2. Open the three-dot menu next to **Custom App** and choose **Install via YAML**.
3. Name the app `pancake-slicer`.
4. Paste the **entire** contents of `build/compose.yaml` into **Custom Config**.
5. Click **Save**.

### 6. Verify

```bash
curl -fsS http://<TRUENAS_IP>:6868/api/healthz
```

Look for `"status":"ok"` and, after initialization,
`"artifact_state":"qualified"`.

## Important Notes

- **UID/GID 65532** — Upstream runs the service as a fixed non-root user. The
  data and cache directories must be writable by `65532:65532`, not the usual
  TrueNAS `568:568`. See [Storage](docs/storage.md).
- **Printer discovery** — The default bridge network can reach printer IPs, but
  SSDP/mDNS/broadcast discovery does not cross the Docker bridge. Add printers
  by IP address. See [Networking](docs/networking.md) and
  [Printers](docs/printers.md).
- **Secrets** — The rendered `build/compose.yaml` may contain
  `PANCAKE_BEARER_TOKEN`. It is gitignored and written with mode `600`, but it is
  visible in the TrueNAS UI after installation. Keep the UI secured.
- **Reverse proxy** — Shipped with a direct port on `6868` only. If you put it
  behind a proxy, configure SSE buffering, upload size, and
  `PANCAKE_TRUSTED_PROXIES`. See [Reverse Proxy](docs/reverse-proxy.md).
- **Non-planar slicing** — Experimental upstream. Review the G-code preview and
  supervise the first print. See [Using PancakeSlicer](docs/usage.md).
- **AGPL-3.0** — PancakeSlicer is licensed AGPL-3.0-only. The image bundles the
  corresponding source archive; see the upstream repository for details.

## Documentation

- [Installation Guide](docs/installation.md)
- [Configuration Reference](docs/configuration.md)
- [Storage Strategy](docs/storage.md)
- [Networking](docs/networking.md)
- [Printer Connections](docs/printers.md)
- [Reverse Proxy](docs/reverse-proxy.md)
- [Security & Hardening](docs/security.md)
- [Using PancakeSlicer](docs/usage.md)
- [Upgrades & Maintenance](docs/upgrades.md)
- [Backup & Restore](docs/backup-restore.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Custom Filament Profiles](config/filament/README.md)
- [TrueNAS Packaging Notes](truenas/README.md)

## Repository Layout

```text
compose/       Compose template with environment substitution
config/        Optional custom filament profiles for import
scripts/       Init, render, validation, and secret-check scripts
docs/          Operator documentation
truenas/       TrueNAS SCALE Custom App notes and example YAML
build/         Generated deployment YAML (gitignored)
```

## Security Summary

- **Set a bearer token** if the UI is reachable by anyone you do not trust.
  `init-env.sh` generates one by default.
- **Do not expose port `6868` directly to the internet.** Use a reverse proxy
  with strong authentication, or reach it over a VPN.
- **The token protects mutations only.** It does not make reads private.
- **Never commit `.env` or `build/`.** They contain credentials and rendered
  paths. `scripts/check-secrets.sh` guards against obvious leaks.
- **Hardening is on by default** — the container drops all capabilities, sets
  `no-new-privileges`, runs as a non-root user, and does not mount the Docker
  socket.

See [Security & Hardening](docs/security.md) for the threat model and exposure
guidance.

## Versioning

This project follows [Semantic Versioning](https://semver.org/). See
[CHANGELOG.md](CHANGELOG.md).

The deployed PancakeSlicer release is controlled independently by
`PANCAKE_VERSION` in `.env`. The image is pinned to an explicit release tag,
never `latest`. See [Upgrades](docs/upgrades.md).

## License

This repository — its configuration, scripts, and documentation — is licensed
under the [MIT License](LICENSE).

The MIT license does not relicense upstream software. PancakeSlicer itself is
licensed **AGPL-3.0-only**; see the
[upstream project](https://github.com/ZimengXiong/PancakeSlicer) and its license
for the full text and obligations.
