# Using PancakeSlicer

This page covers the day-to-day workflow after the app is deployed. The upstream
project is the authority on slicer features and printer support:
<https://github.com/ZimengXiong/PancakeSlicer>.

## Logging In

1. Browse to `http://<TRUENAS_IP>:6868`.
2. If `PANCAKE_BEARER_TOKEN` is set, the first mutation returns `401` and the UI
   asks for the access token. Paste the value from `.env`. You can also open
   `http://<TRUENAS_IP>:6868/?token=<token>` once; the UI stores it and removes
   it from the URL.
3. If authentication is provided by a reverse proxy, log in there first.

The default deployment has no user accounts. Everyone who reaches the UI sees
the same projects and printers. See [Security](security.md) before sharing it.

## First-Run Setup

1. **Add printers.** Use the printer's IP address or hostname. Automatic
   discovery usually does not work through Docker bridge networking. See
   [Printers](printers.md).
2. **Review profiles and filaments.** Set the printer, material, and process
   defaults you use most often.
3. **Run a small test slice.** Confirm the engine reaches
   `"artifact_state":"qualified"` in `/api/healthz` before starting a long job.
4. **Check the output.** Preview the result and, for a new printer, supervise
   the first print.

## Importing a Custom Filament Profile

PancakeSlicer can import Orca-style filament JSON profiles.

1. Choose **File → Import profiles…**.
2. Select the `.json` file.
3. Review the import preview, then add the profile or replace an existing one.
4. Open **Library → Filaments**, select the imported profile, and assign it to a
   slot.

The repository includes an example under
[`config/filament/`](../config/filament/README.md): the
**Extrudr GreenTEC Pro** JSON profile for the Voron 0.1 with a 0.4 mm nozzle.
Importing a profile does not change the printer profile or the process settings.

## Importing a Custom Printer Profile

PancakeSlicer imports Orca-style machine JSON profiles through the same
**File → Import profiles…** dialog.

1. Choose **File → Import profiles…**.
2. Select the `.json` file.
3. Review the import preview. The profile is added as a printer preset; it does
   not create a physical connection.
4. Open **Library → Printers**, select the imported printer, and confirm the bed
   size, nozzle, and motion settings.
5. Add the printer's network connection separately, or export G-code for
   microSD/USB.

The repository includes an example under
[`config/printer/`](../config/printer/README.md): the
**Anet A8 Plus (Hemera, Klipper)** profile for a modified A8 Plus with a Hemera
V6 extruder, a bed probe, and Klipper.

Klipper profiles often call `PRINT_START` and `PRINT_END` macros. If your
`printer.cfg` uses different macro names or parameters, edit the profile's start
and end G-code before importing. Importing a printer profile does not change your
existing filaments or process profiles.

## Uploading and Managing Models

The exact upload control depends on the upstream UI version, but the workflow is
consistent:

1. Open the project or upload area.
2. Select or drop a model file — typically STL, 3MF, STEP, or OBJ.
3. Wait for the upload to finish before leaving the page.
4. Place and orient the model on the plate.
5. Save the project so the model and settings persist in `/data`.

Large uploads can take a while. If you use a reverse proxy, its request-body
limit must be at least 512 MiB. See [Reverse Proxy](reverse-proxy.md).

## Slicing

1. Choose the printer, filament, and process settings.
2. Arrange one or more objects on the plate.
3. Start the slice.
4. Watch progress in the UI. Progress is streamed with Server-Sent Events; a
   proxy that buffers responses makes it arrive in one burst at the end.
5. Review the toolpath preview.
6. Download or export the G-code.

`PANCAKE_MAX_JOBS` controls how many slices run at once. Additional jobs queue.
Slicing is CPU- and memory-intensive; a single large model can consume several
gigabytes.

## Non-Planar Slicing Safety

PancakeSlicer's non-planar features are experimental. Incorrect toolpaths can
collide with the printer, damage hardware, or produce a failed print.

- Start with a small, simple model and a printer you can stop quickly.
- Review the preview from multiple angles before printing.
- Confirm the printer's Z clearance and toolhead geometry.
- Supervise the first print with any new non-planar setting.
- Keep a known-good planar profile to fall back to.

The upstream project's warnings take precedence over any example in this
repository.

## Printer Jobs

Depending on the printer and connection type, you can:

- send a sliced job directly from the UI;
- upload G-code to the printer's web UI or storage;
- download the G-code and use your normal workflow (USB, Mainsail/Fluidd,
  PrusaLink, vendor cloud, etc.).

For Bambu Lab LAN-only mode, enter the printer IP and LAN access code. See
[Printers](printers.md) for protocol-specific notes.

A redeploy restarts the container and interrupts running slices. Finish or
cancel active jobs before upgrading.

## Where Data Lives

| Host path | Container path | Contents |
| :--- | :--- | :--- |
| `PANCAKE_DATA_PATH` | `/data` | Projects, profiles, printers, preferences, finished jobs, blobs |
| `PANCAKE_CACHE_PATH` | `/data/jobs/stage-cache` | Disposable engine scratch data |

Only the data path needs backup. The cache is recreated automatically. See
[Storage](storage.md) and [Backup & Restore](backup-restore.md).

## Multiple Users

The app is a shared web service, not a multi-tenant platform. There are no
per-user projects or permissions.

Options:

1. **One shared instance** — fine for a household or a small trusted team.
   Coordinate so two people do not start conflicting jobs.
2. **One instance per user or group** — duplicate the app with distinct
   `PANCAKE_DATA_PATH`, `PANCAKE_CACHE_PATH`, and `PANCAKE_PORT` values.
3. **Proxy-level access control** — restrict who can reach the single instance.

Running two instances against the same data directory is not supported.

## Resetting the App

To start from a clean application state:

1. Stop the app in TrueNAS.
2. Snapshot or rename `PANCAKE_DATA_PATH`.
3. Create an empty directory at the same path and set ownership to
   `65532:65532`.
4. Start the app.

This discards projects, profiles, and printer configuration. Restore the
snapshot if you need them back.

## Checking Health

```bash
curl -fsS http://<TRUENAS_IP>:6868/api/healthz
```

Expected values:

- `"status":"ok"` — the web service is responding.
- `"artifact_state":"qualified"` — the slicing engine finished its release
  check and is ready. It may take time on first start.

If the response is missing or the container is unhealthy, see
[Troubleshooting](troubleshooting.md).

## Reporting Issues

When asking for help, include:

- The deployed `PANCAKE_VERSION`.
- TrueNAS version and Docker/Compose version.
- The rendered YAML with secrets redacted.
- Relevant container logs.
- Browser and operating system.
- Whether the problem is the UI, the slicing engine, or printer connectivity.

Never paste `.env`, a real bearer token, printer access codes, or the rendered
YAML with secrets included.
