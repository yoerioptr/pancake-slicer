# TrueNAS SCALE Packaging

Modern TrueNAS SCALE (24.10 Electric Eel and newer) uses a **Docker-powered Apps**
system. This repository targets the **Custom App / Install via YAML** workflow.

## Private distribution model

For a private, single-application deployment, the maintainable approach is:

1. Keep this wrapper repository private.
2. Render a Compose file from `.env`.
3. Paste it into the TrueNAS Custom App YAML editor.

### Why not a catalog?

TrueNAS catalogs are designed for public distribution and require a specific
package structure and metadata. For a private deployment of one upstream
container, a catalog adds maintenance overhead without a meaningful benefit.

## Deployment workflow

1. **Prepare** a management machine with Git and Docker Compose.
2. **Configure** `.env` from `.env.example`.
3. **Render** with `./scripts/render-compose.sh`.
4. **Validate** with `./scripts/validate.sh`.
5. **Install**:
   - Open **Apps → Discover Apps**.
   - Choose **Install via YAML**.
   - Name the app `pancake-slicer`.
   - Paste the contents of `build/compose.yaml`.
   - Install.
6. **Verify** `http://<TRUENAS_IP>:6868/api/healthz`.
7. **Maintain**: pull the wrapper, update `.env`, re-render, and paste the new
   YAML when upgrading.

## What the rendered file contains

The render step resolves all `${VARIABLES}`. TrueNAS does not read `.env`, so the
rendered file is authoritative. It includes:

- The pinned image tag.
- Host paths for data and cache.
- The host port.
- Printer network policy.
- Any bearer token you configured.

`build/compose.yaml` is written with mode `600` and is gitignored. Treat it as a
secret when a bearer token is set.

## TrueNAS-specific behaviour

- **Application name**: The name entered in the UI is authoritative. The rendered
  file also contains a Compose project name (`pancakeslicer`); TrueNAS may
  override it.
- **Storage**: Both volumes are host-path bind mounts under `/mnt`, so they are
  visible to datasets, snapshots, and replication.
- **Ownership**: The upstream image runs as UID/GID `65532`. Set ownership on the
  host directories accordingly:
  ```bash
  chown -R 65532:65532 /mnt/Apps/PancakeSlicer
  ```
- **Networking**: The app uses Docker bridge networking and publishes one port.
  TrueNAS manages the bridge. Printer discovery broadcasts do not cross it; add
  printers by IP.
- **Updates**: Changing the image tag in the Compose file and redeploying updates
  the app. Keep `PANCAKE_VERSION` in `.env` as the source of truth.

## Limitations

- **Secrets in the UI**: TrueNAS requires the full Compose YAML. A configured
  `PANCAKE_BEARER_TOKEN` is visible in the installed app's configuration. Secure
  the TrueNAS UI and restrict who can edit apps. If TrueNAS exposes an
  app-level secret field in your version, prefer storing the token there and
  remove the rendered value.
- **Bridge discovery**: Automatic printer discovery is not available by default.
  Manual IP entry is required. Host networking is possible but unsupported by
  this wrapper's default template.
- **Ports**: The app publishes `6868` by default. TrueNAS's own web UI typically
  uses 80/443, so the wrapper does not ship the upstream Caddy service. Use an
  external reverse proxy when HTTPS is required.
- **Architecture**: The image is published for `amd64` and `arm64`. Confirm your
  TrueNAS platform matches.
- **Resources**: The default memory limit is 8 GB and two concurrent slices.
  Plan CPU and RAM accordingly.
- **Permissions**: TrueNAS's usual `apps` user (`568`) is not the runtime user.
  Use numeric UID `65532` for dataset permissions.

## Upgrading the app in TrueNAS

1. Back up the data dataset.
2. Update `PANCAKE_VERSION` in `.env`.
3. Re-render and validate.
4. Edit the installed app and paste the new `build/compose.yaml`.
5. Redeploy.
6. Check logs and `/api/healthz`.
7. If the upgrade fails, restore the previous version pin and, if necessary, the
   data snapshot.

## Verification commands

```bash
docker ps --filter name=pancake
docker logs -f <container-name>
curl -fsS http://<TRUENAS_IP>:6868/api/healthz
```

The health response should contain `"status":"ok"` and, after initialization,
`"artifact_state":"qualified"`.
