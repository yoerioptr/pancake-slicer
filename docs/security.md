# Security & Hardening

PancakeSlicer is a web application that accepts model uploads, runs a slicing
engine, stores project data, and can connect to printers on your network. Treat
network access to it as access to your print farm.

> This project is a deployment wrapper. It does not audit or relicense the
> upstream application. Review the upstream project's security posture and
> advisories as part of your risk assessment.

## Threat Model

| Asset | Why it matters |
| :--- | :--- |
| Projects, models, and G-code in `/data` | May contain proprietary designs or personal files |
| Printer access codes and credentials | Stored in the data directory; can control printers |
| Printer network access | The app can reach LAN printers and the internet |
| The TrueNAS app definition | Contains the rendered Compose YAML, including the token |

The container is isolated from the TrueNAS host by Docker. It is **not** a
sandbox against a malicious upstream image, and it can reach anything routable
from the TrueNAS host, subject to `PANCAKE_PRINTER_NETWORK`.

## Default Controls in This Package

| Control | Default | Effect |
| :--- | :--- | :--- |
| Non-root user | UID/GID `65532` | No root inside the container |
| Capabilities | `cap_drop: ALL` | Removes Linux capabilities the app does not need |
| Privilege escalation | `no-new-privileges:true` | Setuid binaries cannot gain privileges |
| Docker socket | Not mounted | The app cannot control the host Docker daemon |
| Privileged mode | Off | No broad host access |
| Host networking | Off | Ports stay mapped and isolated |
| Image pin | Explicit semver tag | No silent upgrades from `latest` |
| Memory limit | `8g` | Bounds runaway slicing jobs |
| Bearer token | Optional | Protects mutation requests when set |

## Authentication and Authorization

PancakeSlicer's built-in bearer token protects **mutation** requests only. It
does not provide user accounts, per-user permissions, or private reads.

- Set `PANCAKE_BEARER_TOKEN` when anyone you do not trust can reach the UI.
  `scripts/init-env.sh` generates one by default.
- The token is passed through as `ORCA_WEB_BEARER_TOKEN`.
- On first use, enter the token in the UI's access prompt, or open
  `http://<TRUENAS_IP>:6868/?token=<token>` once. The app stores it in a
  browser session and removes it from the URL.
- If a reverse proxy injects its own `Authorization` header, clear the token
  instead of duplicating authentication.
- For Internet exposure, add authentication at the proxy — Basic Auth, OIDC,
  mTLS, or a VPN. See [Reverse Proxy](reverse-proxy.md).

### Keeping the Token Out of the TrueNAS UI

TrueNAS stores the pasted Compose YAML in its app configuration, so a configured
token is visible there. Options:

1. **Reverse proxy authentication** — leave `PANCAKE_BEARER_TOKEN` empty and
   authenticate at the proxy. This is the simplest production pattern.
2. **Restrict the TrueNAS UI** — keep the rendered YAML limited to admins and
   treat the token as a shared secret.

There is no built-in file-based secret mechanism in the upstream image that this
wrapper can rely on. Do not paste the token into tickets, chat, or screenshots.

## Exposure Guidance

| Scenario | Recommendation |
| :--- | :--- |
| Trusted home LAN | Bearer token is reasonable; keep the TrueNAS UI secured |
| Shared household or makerspace | Bearer token plus a reverse proxy with per-user auth |
| Internet-facing | **Do not port-forward `6868` directly.** Use a reverse proxy with strong auth or a VPN |
| Untrusted multi-tenant host | Run a dedicated instance with its own data path and network policy |

Direct exposure gives anyone who can reach the port the same view of projects,
printers, and jobs that you have. The absence of a login page is not an
invitation to publish the port.

## Network and Data Boundaries

- The container uses Docker bridge networking and publishes one port.
- `PANCAKE_PRINTER_NETWORK` is an allow-list for outbound printer connections:
  `lan`, an explicit comma-separated list, or `off`.
- Only two host paths are mounted: the data directory and the disposable cache.
- Do not mount `/mnt`, the pool root, `/var/run/docker.sock`, or host devices.
- If the app does not need printer access, set `PANCAKE_PRINTER_NETWORK=off`.

See [Networking](networking.md) and [Storage](storage.md).

## Secrets Hygiene

- `.env` is gitignored and mode `600` after `init-env.sh`.
- `build/` is gitignored because rendered YAML contains the token when set.
- `scripts/check-secrets.sh` scans the working tree for non-empty tokens,
  private keys, and tracked `.env` files. It is a guardrail, not a guarantee.
- If a token leaks, generate a new one, update `.env`, re-render, and redeploy.
  Rotating the token invalidates the old value immediately.
- Printer access codes live in `PANCAKE_DATA_PATH`. Protect that dataset with
  filesystem permissions, ACLs, and encrypted backups.

## TLS and Reverse Proxies

The app listens on plain HTTP. Put it behind a TLS-terminating reverse proxy if
traffic crosses untrusted networks.

When using a proxy:

- Set `PANCAKE_TRUSTED_PROXIES` to the proxy's source CIDR so client IPs and
  rate limiting work correctly.
- Disable response buffering for Server-Sent Events.
- Allow uploads up to at least 512 MiB.
- Use a long response-header timeout for long slices.
- Preserve the `Authorization` header if you use a bearer token.

See [Reverse Proxy](reverse-proxy.md) for nginx, Caddy, and Traefik examples.

## Updates Are Security Updates

The image bundles the application, its engine, and its runtime. Pin a release for
reproducibility, but do not stay on an old tag forever.

1. Review upstream release notes and security advisories.
2. Back up the data dataset.
3. Bump `PANCAKE_VERSION` deliberately.
4. Re-render, validate, and redeploy.

See [Upgrades & Maintenance](upgrades.md) and
[Backup & Restore](backup-restore.md).
