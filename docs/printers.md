# Printer Connections

PancakeSlicer supports a range of printers. See the upstream
[Supported Printers](https://github.com/ZimengXiong/PancakeSlicer#supported-printers)
table for the current list and non-planar caveats.

> **Safety:** Non-planar slicing is experimental. Review the G-code preview and
> supervise the first print on any printer. The upstream project warns that
> incorrect non-planar paths can damage a printer.

## Why manual IP entry

The default TrueNAS deployment uses Docker bridge networking. Printer discovery
via SSDP, UDP broadcast, and mDNS does not cross the bridge. Add printers by IP.
See [Networking](networking.md) for the protocol details.

Give printers a DHCP reservation so their addresses do not change.

## Bambu Lab (LAN-only mode)

1. On the printer, enable **LAN Only** mode and note the **LAN Access Code**.
2. Give the printer a static IP or DHCP reservation.
3. In PancakeSlicer, add the printer by IP and enter the access code.
4. Ensure TrueNAS can reach the printer on the LAN.

Bambu printers commonly use TCP `8883` for MQTT over TLS and TCP `990` for file
transfer, plus vendor-specific camera ports. The app handles the protocol; you
only need routable LAN connectivity.

Bambu cloud accounts are not required for LAN-only operation.

## Klipper / Moonraker

Add the printer using the Moonraker host and port (commonly `7125`). Ensure
Moonraker is reachable from the TrueNAS host.

## PrusaLink / Prusa Connect

Add the printer using its PrusaLink host and port (commonly `80` or `8080`).
Credentials are configured in the printer entry.

## Elegoo, Flashforge, Qidi, RepRap, Duet, and others

Use the printer's LAN IP and the protocol-specific port requested by the
PancakeSlicer UI. Consult the upstream project and your printer documentation for
the correct host/protocol combination.

## Connectivity checks

Run these from the TrueNAS shell (not inside the container, which has a minimal
userland):

```bash
ping -c 3 <printer-ip>
nc -vz <printer-ip> 8883    # Bambu MQTT example
nc -vz <printer-ip> 7125    # Moonraker example
```

If the host can reach the printer but the app cannot:

- Confirm `PANCAKE_PRINTER_NETWORK` allows the printer's address or subnet.
- Confirm the printer is on a network routable from TrueNAS.
- Check the container logs for connection errors.
- Check firewall rules between the TrueNAS host/VLAN and the printer VLAN.

## Access codes and credentials

Printer access codes are sensitive. They are stored in the application's data
directory, so protect `PANCAKE_DATA_PATH` with appropriate permissions and
backups. Do not paste access codes into tickets, chat, or committed files.

## Changing printer addresses

If a printer's IP changes, update it in the PancakeSlicer UI. Prefer DHCP
reservations to avoid this.
