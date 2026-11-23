# Upgrades & Maintenance

## Safe upgrade workflow

1. **Back up** the data directory and `.env`. See
   [Backup & Restore](backup-restore.md).
2. **Read the upstream release notes** for the target PancakeSlicer version.
   Check for schema or behaviour changes that require action.
3. **Pull the latest wrapper**:
   ```bash
   git pull origin main
   ```
4. **Review changes**:
   - `CHANGELOG.md`
   - `.env.example` for new or renamed variables
   - `compose/compose.template.yaml`
5. **Update `.env`**:
   - Set `PANCAKE_VERSION` to the new release.
   - Add any new variables from `.env.example`.
6. **Re-render and validate**:
   ```bash
   ./scripts/render-compose.sh
   ./scripts/validate.sh
   ```
7. **Update the TrueNAS app**:
   - Go to **Apps → Installed Apps**.
   - Select `pancake-slicer`.
   - Edit the app and paste the new `build/compose.yaml`.
   - Save/redeploy.
8. **Verify**:
   ```bash
   docker ps --filter name=pancake
   docker logs -f <container-name>
   curl -fsS http://<TRUENAS_IP>:6868/api/healthz
   ```
   Confirm `"status":"ok"` and that the engine reaches
   `"artifact_state":"qualified"`.

## Changing the version pin

The wrapper does not track `latest`. To upgrade, change one line:

```dotenv
PANCAKE_VERSION=0.5.5
```

Then re-render and redeploy. To roll back, set the previous version, re-render,
and redeploy. If the new version changed the data schema, restore the matching
data snapshot as well.

## Container image updates

TrueNAS may offer an image pull/update action. It does not change the tag in your
Compose file. Keep `PANCAKE_VERSION` in `.env` as the source of truth, and
redeploy with the new tag when you are ready.

## Cache

`PANCAKE_CACHE_PATH` is disposable. After an upgrade you may delete its contents
while the app is stopped to reclaim space. Do not delete `PANCAKE_DATA_PATH`.

## Non-destructive expectations

Upgrading the wrapper does not:

- Delete projects, profiles, or printer configurations.
- Move files on the host.
- Change the data path unless you edit `.env`.

Upstream application schema migrations may still be irreversible. That is why a
data backup before every upgrade is recommended.

## Downtime

A redeploy restarts the container and interrupts running slices. Finish or cancel
active jobs first. The app retains finished jobs according to its internal TTL.

## Maintenance tasks

- Monitor dataset usage and the cache cap.
- Review container logs after upgrades.
- Rotate the bearer token if it was exposed.
- Keep `.env` and `build/compose.yaml` private.
- Periodically test restoring the data dataset.
