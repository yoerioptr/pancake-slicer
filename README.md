# PancakeSlicer on TrueNAS SCALE

A small, reproducible deployment wrapper that runs [PancakeSlicer](https://github.com/ZimengXiong/PancakeSlicer) as a **Custom App** on TrueNAS SCALE 24.10 (Electric Eel) or newer.

It follows the same repository pattern as *The Black Pearl*: a Compose template, a private `.env` file, render/validation scripts, operator documentation, and a TrueNAS-specific guide.

## What you get

- One `pancakeslicer` container from the upstream multi-arch image, pinned to `0.5.5`.
- Web UI on `http://<TRUENAS_IP>:6868`.
- Persistent state in `${PANCAKE_DATA_PATH}` (default `/mnt/Apps/PancakeSlicer/data`).
- Disposable slice cache in `${PANCAKE_CACHE_PATH}` (excluded from backups).
- Non-root execution (UID/GID `65532`), `no-new-privileges`, all capabilities dropped, and an 8 GB memory limit.
- Optional bearer token for mutations and reverse-proxy support.

## Relationship to the upstream `deploy/` folder

Upstream's `deploy/docker-compose.yml` runs one container, publishes port `6868`,
and stores state in a named volume. This wrapper adapts it for TrueNAS by:

- replacing the named volume with host-path bind mounts under `/mnt`,
- splitting the disposable stage cache into its own host path,
- pinning the image tag and adding container hardening and a memory limit,
- adding the render step, because TrueNAS does not expand `.env` variables.

Upstream's `deploy/Dockerfile` is a maintainer build that requires staged engine
artifacts. It is not used here; this wrapper consumes the published multi-arch
image. The upstream `docker-compose.proxy.yml`/Caddy setup is not included by
default because TrueNAS normally occupies ports 80/443. See
[Reverse Proxy](docs/reverse-proxy.md) if you want HTTPS.


## Quick start

1. **Clone the repository** on a management machine:
   ```bash
   git clone <your-repo-url> pancake-slicer
   cd pancake-slicer
   ```

2. **Create the host directories** on TrueNAS and give the container's user ownership:
   ```bash
   mkdir -p /mnt/Apps/PancakeSlicer/data /mnt/Apps/PancakeSlicer/cache
   chown -R 65532:65532 /mnt/Apps/PancakeSlicer
   ```

3. **Configure**:
   ```bash
   cp .env.example .env
   vi .env
   ```

4. **Render and validate**:
   ```bash
   ./scripts/render-compose.sh
   ./scripts/validate.sh
   ```

5. **Install**:
   Go to **Apps → Discover Apps → Install via YAML**, name the app `pancake-slicer`, and paste the contents of `build/compose.yaml`.

6. **Verify**:
   ```bash
   curl -fsS http://<TRUENAS_IP>:6868/api/healthz
   ```
   Look for `"status":"ok"` and an eventually `"artifact_state":"qualified"` value.

## Important notes

- **UID/GID 65532**: Upstream runs the service as a fixed non-root user. The data and cache directories must be writable by `65532:65532`, not the usual TrueNAS `568:568`. See [Storage](docs/storage.md).
- **Printer discovery**: The default bridge network can reach printer IPs, but SSDP/mDNS/broadcast discovery does not cross the Docker bridge. Add printers by IP address. See [Networking](docs/networking.md) and [Printers](docs/printers.md).
- **Secrets**: The rendered `build/compose.yaml` may contain `PANCAKE_BEARER_TOKEN`. It is gitignored and written with mode `600`, but it is visible in the TrueNAS UI after installation. Keep the UI secured.
- **Reverse proxy**: Shipped as direct port `6868` only. If you put it behind a proxy, configure SSE buffering, upload size, and `ORCA_WEB_TRUSTED_PROXIES`. See [Reverse Proxy](docs/reverse-proxy.md).
- **AGPL-3.0**: PancakeSlicer is licensed AGPL-3.0-only. The image bundles the corresponding source archive; see the upstream repository for details.

## Documentation

- [Installation Guide](docs/installation.md)
- [Configuration Reference](docs/configuration.md)
- [Storage Strategy](docs/storage.md)
- [Networking](docs/networking.md)
- [Printer Connections](docs/printers.md)
- [Reverse Proxy](docs/reverse-proxy.md)
- [Upgrades & Maintenance](docs/upgrades.md)
- [Backup & Restore](docs/backup-restore.md)
- [Troubleshooting](docs/troubleshooting.md)
- [TrueNAS Packaging Notes](truenas/README.md)

## Repository layout

```text
compose/       Compose template with environment substitution
scripts/       Render, validation, and secret-check scripts
docs/          Operator documentation
truenas/       TrueNAS SCALE Custom App notes
build/         Generated deployment YAML (gitignored)
```

## Security

- `.env` and `build/compose.yaml` are gitignored. Never commit either.
- `scripts/check-secrets.sh` rejects non-empty bearer tokens and PEM private keys in the working tree.
- The container drops all capabilities and sets `no-new-privileges`.
- A bearer token only protects mutation endpoints; for Internet exposure put an authenticating reverse proxy in front of the app.

## Versioning

This project follows [Semantic Versioning](https://semver.org/). See [CHANGELOG.md](CHANGELOG.md).

The deployed PancakeSlicer release is controlled independently by `PANCAKE_VERSION` in `.env`.

## License

The deployment wrapper is private/proprietary and not for public distribution. PancakeSlicer itself is licensed **AGPL-3.0-only**; see the [upstream project](https://github.com/ZimengXiong/PancakeSlicer) and [LICENSE](https://github.com/ZimengXiong/PancakeSlicer/blob/main/LICENSE).
