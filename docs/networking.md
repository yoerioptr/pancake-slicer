# Networking

The default deployment uses Docker's bridge network and publishes one port on
the TrueNAS host:

```text
LAN client -> http://<TRUENAS_IP>:6868 -> pancakeslicer:6868
```

## LAN access

The Compose template maps `${PANCAKE_PORT}` to container port `6868`. The
container listens on all interfaces inside its namespace.

To change the host port, edit `PANCAKE_PORT` in `.env`, re-render, and update the
TrueNAS app.

## Printer connectivity

Outbound printer connections are allowed according to
`PANCAKE_PRINTER_NETWORK` (default `lan`). The app can reach private LAN
addresses, including the printer's web/API ports.

The Docker bridge performs NAT for outbound traffic, so the printer sees the
connection coming from the TrueNAS host IP. This works for normal TCP APIs.

### Discovery limitation

PancakeSlicer's automatic printer discovery uses protocols that do not cross a
Docker bridge by default:

- SSDP/M-SEARCH to `239.255.255.250:1990`
- UDP broadcast to `255.255.255.255:2021`
- mDNS to `224.0.0.251:5353`

As a result, **automatic discovery will typically find nothing** in this
deployment. Add printers by IP address instead:

1. Give each printer a DHCP reservation or static IP.
2. In the PancakeSlicer UI, add the printer with its IP and protocol details.
3. For Bambu Lab LAN-only mode, also enter the printer's LAN access code.

See [Printers](printers.md) for protocol-specific notes.

### Advanced: host networking

If automatic discovery is essential, you can run the container with host
networking instead. This is not shipped in the default template because it
removes network isolation and disables port mapping, and TrueNAS may have
conflicts on the chosen port.

To do it manually:

1. In `compose/compose.template.yaml`, remove the `ports:` block.
2. Add `network_mode: host` to the `pancakeslicer` service.
3. Keep `ORCA_WEB_LISTEN` at its image default (`0.0.0.0:6868`).
4. Re-render and redeploy.

With host networking the app binds directly on the TrueNAS host, and multicast
discovery can reach the LAN. Protect the UI with a bearer token and firewall
rules. The validation script intentionally rejects host networking in the
default template.

## Reverse proxy

The app is designed to run behind a proxy. If you add one:

- Set `PANCAKE_TRUSTED_PROXIES` to the proxy's source CIDR.
- Disable response buffering so Server-Sent Events (slice progress and printer
  status) stream promptly.
- Allow uploads up to 512 MiB.
- Use a long response-header timeout, because slicing can take a long time.

See [Reverse Proxy](reverse-proxy.md) for nginx, Caddy, and Traefik examples.

## Bearer token

`PANCAKE_BEARER_TOKEN` protects mutation requests. Set it if the UI is reachable
by anyone you do not trust. It does not replace authentication for public
Internet exposure; use an authenticating proxy for that.

## Firewall and VLANs

- Allow LAN clients to reach the TrueNAS host on `PANCAKE_PORT`.
- Allow the PancakeSlicer container's outbound traffic to printer IPs.
- If printers are on a separate VLAN, ensure routing and firewall rules permit
  TrueNAS to reach them.
- If the network blocks outbound DNS/HTTPS from containers, fix Docker's DNS
  configuration; the app itself does not require Internet access to slice.

## IPv6

`PANCAKE_PRINTER_NETWORK=lan` includes private IPv6 ULA ranges. If your printers
use IPv6, confirm the Docker network has IPv6 enabled and that the host can route
to the printer subnet.
