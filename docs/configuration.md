# Configuration Reference

All deployment-specific values live in `.env` at the project root. The rendered
`build/compose.yaml` is what TrueNAS consumes.

Create `.env` with `./scripts/init-env.sh`, which also generates a random bearer
token and sets mode `600`. To manage values manually, copy `.env.example`.

## General settings

| Variable | Purpose | Default | Secret |
| :--- | :--- | :--- | :--- |
| `PANCAKE_IMAGE` | Container image repository | `zimengxiong/pancakeslicer` | No |
| `PANCAKE_VERSION` | Pinned image tag | `0.5.5` | No |
| `PANCAKE_PORT` | Host port for the web UI | `6868` | No |
| `TZ` | Container timezone | `Etc/UTC` | No |

Do not use `latest` for `PANCAKE_VERSION`. Update the pin deliberately after
reviewing upstream release notes.

## Storage

| Variable | Purpose | Example |
| :--- | :--- | :--- |
| `PANCAKE_DATA_PATH` | Persistent projects, profiles, printers, preferences, jobs | `/mnt/Apps/PancakeSlicer/data` |
| `PANCAKE_CACHE_PATH` | Disposable engine stage cache | `/mnt/Apps/PancakeSlicer/cache` |

Both paths must be writable by UID/GID `65532`. The cache path is mounted at
`/data/jobs/stage-cache` inside the container and should be excluded from
snapshots and backups.

See [Storage](storage.md).

## Runtime tuning

| Variable | Purpose | Default |
| :--- | :--- | :--- |
| `PANCAKE_MAX_JOBS` | Number of slices that run concurrently; extra jobs queue | `2` |
| `PANCAKE_STAGE_CACHE_MAX_MB` | Cap for the disposable stage cache, in MB | `1024` |
| `PANCAKE_MEMORY_LIMIT` | Container memory limit | `8g` |

If the container is OOM-killed, either raise `PANCAKE_MEMORY_LIMIT` or lower
`PANCAKE_MAX_JOBS`. Lowering the job count is usually the better first step.

## Printer networking

| Variable | Purpose | Default |
| :--- | :--- | :--- |
| `PANCAKE_PRINTER_NETWORK` | Where the service may connect to printers | `lan` |

Accepted values:

- `lan` — any private IPv4/IPv6 range (RFC1918, CGNAT, and ULA).
- A comma-separated list such as `lan,192.168.1.50,printer.local`.
- `off` — disable printer connections entirely.

The value is passed through as `ORCA_WEB_PRINTER_NETWORK`. It is an allow-list
for outbound printer connections, not a discovery mechanism. See
[Networking](networking.md) and [Printers](printers.md).

## Security

| Variable | Purpose | Default | Secret |
| :--- | :--- | :--- | :--- |
| `PANCAKE_BEARER_TOKEN` | Mutation bearer token | empty (disabled) | **Yes** |
| `PANCAKE_TRUSTED_PROXIES` | Trusted reverse-proxy CIDRs | empty | No |

### Bearer token

Set `PANCAKE_BEARER_TOKEN` to a random value if the UI is reachable by anyone you
do not trust. Generate a value with:

```bash
openssl rand -hex 32
```

Paste the output into `.env` as the value of `PANCAKE_BEARER_TOKEN`. The value is
passed through as `ORCA_WEB_BEARER_TOKEN`.

On first use, enter the token in the UI's access prompt, or open
`http://<TRUENAS_IP>:6868/?token=<token>` once. The app stores it in a browser
session and removes it from the URL. Rotating the token invalidates the old
value.

The token protects **mutation** requests. It does not make the UI read-only
private. For Internet exposure, put an authenticating reverse proxy in front of
the app. See [Reverse Proxy](reverse-proxy.md).

### Trusted proxies

Set `PANCAKE_TRUSTED_PROXIES` only when the app is behind a reverse proxy. Use
the proxy's source CIDR. For a proxy container on the default Docker bridge
network, `172.16.0.0/12` is a common starting point, but narrow it to the actual
proxy address where possible.

The value is passed through as `ORCA_WEB_TRUSTED_PROXIES`.

## Optional update notice

| Variable | Purpose | Default |
| :--- | :--- | :--- |
| `PANCAKE_RELEASE_FEED` | GitHub `owner/repo` for an update notice | empty (disabled) |

For example, setting it to `ZimengXiong/PancakeSlicer` lets the UI offer an
update notice when a newer release exists. The deployment still uses the pinned
`PANCAKE_VERSION`.

## Custom profiles

`config/filament/` and `config/printer/` contain optional example profiles for
manual import. They are not mounted into the container and are not read from disk
at runtime. Import them through the UI; the imported copies are stored under
`PANCAKE_DATA_PATH` and are included in that path's backups.

See [Custom Filament Profiles](../config/filament/README.md) and
[Custom Printer Profiles](../config/printer/README.md).

## Upstream environment mapping

The template also sets these upstream variables:

| Template value | Upstream variable |
| :--- | :--- |
| `PANCAKE_MAX_JOBS` | `ORCA_WEB_MAX_JOBS` |
| `PANCAKE_PRINTER_NETWORK` | `ORCA_WEB_PRINTER_NETWORK` |
| `PANCAKE_BEARER_TOKEN` | `ORCA_WEB_BEARER_TOKEN` |
| `PANCAKE_TRUSTED_PROXIES` | `ORCA_WEB_TRUSTED_PROXIES` |
| `PANCAKE_RELEASE_FEED` | `ORCA_WEB_RELEASE_FEED` |
| `PANCAKE_STAGE_CACHE_MAX_MB` | `PANCAKE_STAGE_CACHE_MAX_MB` |

The image already sets `ORCA_WEB_LISTEN`, `ORCA_WEB_DATA_DIR`,
`ORCA_WEB_JOB_ROOT`, and the engine paths. Do not override them unless you have a
specific reason.
