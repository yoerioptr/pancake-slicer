# Backup & Restore

## What to back up

1. **`PANCAKE_DATA_PATH`** — projects, models, profiles, filaments, printers,
   preferences, blobs, and finished job state. This is the important data.
2. **`.env`** — contains your paths, port, version pin, and possibly a bearer
   token. Store it in a password manager or encrypted backup.
3. **This repository** — the Compose template, scripts, and documentation.

## What not to back up

`PANCAKE_CACHE_PATH` is disposable slicing scratch space. It can be large and is
recreated automatically. Exclude it from snapshots and replication jobs.

## Recommended method

Use TrueNAS **ZFS Snapshots** and **Replication Tasks**:

1. Create a periodic snapshot task for the dataset containing
   `PANCAKE_DATA_PATH`.
2. Replicate to a second pool or an offsite target.
3. Exclude the cache dataset from the schedule.

For the most consistent backup, stop the `pancake-slicer` app before taking the
snapshot, then start it again. A snapshot taken while the app is running is
crash-consistent and usually fine, but stopping first avoids capturing in-flight
job state.

## Manual backup

From the TrueNAS shell:

```bash
# Stop the app first if you want a fully consistent copy.
tar -C /mnt/Apps/PancakeSlicer -czf /mnt/Backups/pancakeslicer-data-$(date +%F).tar.gz data
```

Store the archive off the appliance. Do not include the cache directory.

## Restore workflow

1. Install or reinstall TrueNAS/Docker if starting fresh.
2. Restore the `data` directory to `PANCAKE_DATA_PATH`, or update
   `PANCAKE_DATA_PATH` to the restored location.
3. Restore ownership:
   ```bash
   chown -R 65532:65532 /mnt/Apps/PancakeSlicer/data
   ```
   If the dataset uses NFSv4 ACLs, add an ACL item for UID 65532 as described in
   [Storage](storage.md).
4. Restore the wrapper repository and your `.env`.
5. Render and validate:
   ```bash
   ./scripts/render-compose.sh
   ./scripts/validate.sh
   ```
6. Reinstall or update the TrueNAS Custom App with the rendered
   `build/compose.yaml`.
7. Verify:
   ```bash
   curl -fsS http://<TRUENAS_IP>:6868/api/healthz
   ```
   Open the UI and confirm projects, profiles, and printers are present.

## Restoring to a different version

The application may migrate its data schema on startup. Restore a snapshot that
matches the deployed `PANCAKE_VERSION` where possible. If you upgrade and then
restore an older snapshot, either deploy the older version or accept that the
app may re-run migrations.

## Testing backups

A backup is only useful if it restores. Periodically restore the data dataset to
a temporary path, start a throwaway instance on an alternate port, and confirm
the UI loads the expected projects and printers.
