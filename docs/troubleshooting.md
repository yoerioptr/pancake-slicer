# Troubleshooting

## First steps

```bash
docker ps --filter name=pancake
docker logs -f <container-name>
curl -fsS http://<TRUENAS_IP>:6868/api/healthz
```

The health response should contain `"status":"ok"`. The engine reports
`"artifact_state":"qualified"` after its release check passes.

## Mutations fail with 401

**Cause:** `PANCAKE_BEARER_TOKEN` is set and the browser session has not stored
it, or the token was rotated.

**Fix:** Enter the current token in the UI's access prompt, or open
`http://<TRUENAS_IP>:6868/?token=<token>` once. Reloading after a rotation also
prompts again. Reads and `/api/healthz` are unaffected.

## Permission denied under `/data`

**Symptoms:** The container starts but logs permission errors, or uploads and
saves fail.

**Cause:** The image runs as UID/GID `65532`, not the usual TrueNAS `568:568`.

**Fix:**

```bash
chown -R 65532:65532 /mnt/Apps/PancakeSlicer
```

If the dataset uses NFSv4 ACLs, add an ACL item for UID 65532 in the TrueNAS UI
or run:

```bash
setfacl -R -m u:65532:rwx /mnt/Apps/PancakeSlicer
```

## Container is unhealthy

The healthcheck uses the bundled Node runtime to call
`http://127.0.0.1:6868/api/healthz`.

- Give it time: the image is large and the engine initializes on first start.
- Check logs for fatal errors such as missing profiles, an unreadable data
  directory, or an invalid `PANCAKE_PRINTER_NETWORK` value.
- Confirm the container is actually listening on `6868`:
  ```bash
  docker exec <container-name> /usr/bin/node -e \
    "fetch('http://127.0.0.1:6868/api/healthz').then(r=>console.log(r.status))"
  ```

## `artifact_state` is not `qualified`

**Symptoms:** The UI loads but slicing is unavailable, or `/api/healthz` reports
a non-qualified artifact state.

**Checks:**

- Wait for first-start qualification to finish; watch the logs.
- Confirm the host CPU architecture is supported (`amd64` or `arm64`).
- Confirm the image tag exists for your architecture:
  `docker manifest inspect zimengxiong/pancakeslicer:0.5.5`.
- Ensure the container has enough memory; the engine can fail under memory
  pressure.
- Re-pull the pinned image if it was partially downloaded or corrupted.

## Printers cannot be discovered

**Expected behaviour:** SSDP, UDP broadcast, and mDNS discovery do not cross the
Docker bridge used by this deployment.

**Fix:** Add printers by IP address. Give them DHCP reservations. See
[Printers](printers.md). If discovery is mandatory, read the advanced host
networking note in [Networking](networking.md).

## Printer is reachable by IP but the app cannot connect

- Confirm the printer IP and port in the app match reality.
- Confirm `PANCAKE_PRINTER_NETWORK` allows the printer's address or subnet.
- From TrueNAS, test connectivity:
  ```bash
  nc -vz <printer-ip> 8883
  ```
- If the printer is on another VLAN, check routing and firewall rules.
- For Bambu LAN mode, confirm the access code is correct and LAN-only mode is
  enabled.
- Check the container logs for connection errors.

## A custom printer profile is skipped on import

**Cause:** A raw Orca machine preset must name a printer model that exists in
PancakeSlicer's bundled catalog. If the preset references a printer that is not
in the catalog, the import preview marks it as skipped.

**Fix:** Use a profile based on a catalog template. The repository's
[`anet-a8-plus-hemera-klipper.json`](../config/printer/anet-a8-plus-hemera-klipper.json)
is based on **Generic Klipper Printer** and overrides the machine values. If you
write your own, set `printer_model` to a catalog model and `inherits` to one of
its nozzle variants.

Settings listed as **not stored** in the import preview are usually process or
filament settings rather than printer settings. They are ignored; check the bed,
nozzle, motion, and G-code values after import.

## Klipper reports an unknown `PRINT_START` or `PRINT_END`

**Cause:** The imported printer profile calls macros that your `printer.cfg` does
not define, or the macro parameters have different names.

**Fix:** Rename the macros or edit the profile's `machine_start_gcode` and
`machine_end_gcode`. The A8 Plus example expects:

```gcode
PRINT_START EXTRUDER=[nozzle_temperature_initial_layer] BED=[bed_temperature_initial_layer_single]
```

and `PRINT_END`. Keep the heating and probing steps inside the macros so every
print uses the same homing and mesh routine.

## Upload fails with 413

**Cause:** A reverse proxy or the app's upload limit rejected the file.

- The app accepts up to 512 MiB by default (`ORCA_WEB_MAX_UPLOAD_MB`, not
  exposed in `.env.example`).
- If using a proxy, raise its body limit to at least 512 MiB. See
  [Reverse Proxy](reverse-proxy.md).
- If you intentionally need larger uploads, add `ORCA_WEB_MAX_UPLOAD_MB` to the
  Compose environment and raise the proxy limit to match.

## Slice progress freezes or arrives in one burst

**Cause:** A reverse proxy is buffering Server-Sent Events.

**Fix:** Disable proxy buffering and raise the response timeout:

- nginx: `proxy_buffering off; proxy_read_timeout 40m;`
- Caddy: `flush_interval -1` and `response_header_timeout 40m`
- Traefik: disable the buffering middleware and raise
  `forwardingTimeouts.responseHeaderTimeout`

## Port conflict

**Symptoms:** TrueNAS reports `address already in use` or the app fails to start
on `6868`.

**Fix:** Change `PANCAKE_PORT` in `.env`, re-render, and redeploy. Check what is
using the port:

```bash
ss -ltnp | grep 6868
```

## Container is OOM-killed

**Symptoms:** The container restarts during large slices; logs show exit code
137 or the kernel OOM killer.

**Fix:** Lower `PANCAKE_MAX_JOBS` first, then raise `PANCAKE_MEMORY_LIMIT` if the
host has capacity. Slicing is memory-intensive, especially with multiple
concurrent jobs.

## Wrong architecture

The image supports `amd64` and `arm64`. TrueNAS on x86_64 uses `amd64`. If you
see an exec format or no matching manifest error, verify the platform:

```bash
uname -m
docker manifest inspect zimengxiong/pancakeslicer:0.5.5
```

## Reverse proxy reports the wrong client IP

Set `PANCAKE_TRUSTED_PROXIES` to the proxy's source CIDR. Without it, the app
does not trust `X-Forwarded-For` and may rate-limit or log the proxy IP.

## Timezone is wrong

Set `TZ` in `.env` to your IANA timezone, then re-render and redeploy.

## Data directory was moved

Update `PANCAKE_DATA_PATH` in `.env`, keep the ownership at `65532:65532`,
re-render, and redeploy. Do not point two instances at the same data directory
simultaneously.

## Getting help

- Upstream project: <https://github.com/ZimengXiong/PancakeSlicer>
- Upstream issues: <https://github.com/ZimengXiong/PancakeSlicer/issues>
- TrueNAS Docker apps: <https://apps.truenas.com/>
