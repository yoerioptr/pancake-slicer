# Storage Strategy

PancakeSlicer keeps all application state under `/data` inside the container.
This wrapper maps `/data` to a host path so TrueNAS datasets, snapshots, and
replication can manage it.

## Host layout

The defaults from `.env.example`:

```text
/mnt/Apps/PancakeSlicer/
├── data/     -> /data
└── cache/    -> /data/jobs/stage-cache
```

- **`data`** contains projects, models, profiles, filaments, printers,
  preferences, blobs, and finished job state. Back this up.
- **`cache`** contains disposable slice scratch data. It can be deleted at any
  time and should be excluded from snapshots and backup jobs.

You can place these on different datasets. Keep the cache on fast local storage
rather than a network share.

## Container paths

Do not change these inside application configuration:

| Container path | Contents |
| :--- | :--- |
| `/data` | Persistent state root |
| `/data/library` | Projects, profiles, filaments, printers, preferences |
| `/data/jobs` | Job working directories and results |
| `/data/jobs/stage-cache` | Disposable engine stage cache |
| `/data/blobs` | Uploaded model blobs and cached artifacts |

## Permissions

The upstream image runs as **UID/GID 65532**. This is different from the usual
TrueNAS `apps` user (`568:568`). Set ownership on the host:

```bash
mkdir -p /mnt/Apps/PancakeSlicer/data /mnt/Apps/PancakeSlicer/cache
chown -R 65532:65532 /mnt/Apps/PancakeSlicer
```

If the dataset uses NFSv4 ACLs and `chown` does not grant write access, add an
ACL item for UID 65532 in the TrueNAS UI, or use:

```bash
setfacl -R -m u:65532:rwx /mnt/Apps/PancakeSlicer
```

Verify from the TrueNAS shell by writing a test file as the same numeric user:

```bash
docker run --rm -u 65532:65532 -v /mnt/Apps/PancakeSlicer/data:/data \
  busybox sh -c 'touch /data/.write-test && rm /data/.write-test && echo writable'
```

## Backups and snapshots

- Snapshot or replicate `PANCAKE_DATA_PATH`.
- Do **not** include `PANCAKE_CACHE_PATH`; it can be large and is disposable.
- Back up `.env` separately in a password manager or encrypted store.
- For the most consistent snapshot, stop the app before snapshotting, or accept
  a crash-consistent ZFS snapshot while it runs.

See [Backup & Restore](backup-restore.md).

## Capacity planning

The image itself is roughly 300 MB. Growth comes from:

- Uploaded models and project history in `/data/library` and `/data/blobs`.
- Job results retained until their TTL expires.
- The stage cache, capped by `PANCAKE_STAGE_CACHE_MAX_MB` (default 1 GB).

A few gigabytes of data plus the cache cap is usually sufficient for a small
makerspace. Monitor dataset usage and adjust the job TTL in the application if
needed.

## Restore

Restore the `data` dataset to the same host path (or update
`PANCAKE_DATA_PATH`), then re-render and redeploy. The cache directory can be
empty; the engine recreates it.
