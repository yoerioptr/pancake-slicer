# Custom Printer Profiles

This folder holds optional, user-importable printer (machine) profiles.
PancakeSlicer does not load this directory automatically; import the file through
the UI.

## Anet A8 Plus (Hemera, Klipper)

| File | Purpose |
| :--- | :--- |
| `anet-a8-plus-hemera-klipper.json` | Klipper machine preset for an Anet A8 Plus with an E3D Hemera V6 direct-drive extruder and a bed probe |

The profile appears in the library as **Anet A8 Plus (Hemera, Klipper)**.

This is a profile for a modified machine, not a stock A8 Plus. The stock printer
uses Marlin and a different toolhead; the profile assumes Klipper, a Hemera V6,
and a probe such as a BLTouch or CR Touch.

### Import

1. Open PancakeSlicer.
2. Choose **File → Import profiles…**.
3. Select `anet-a8-plus-hemera-klipper.json`.
4. Review the import preview. The profile is based on the catalog's
   **Generic Klipper Printer** template (`MyKlipper 0.4 nozzle`); the bed,
   motion limits, toolhead, and machine G-code are overridden for this build.
5. Add the printer. If a printer with the same name already exists, choose
   **Keep both** or **Replace**.
6. Open **Library → Printers**, select **Anet A8 Plus (Hemera, Klipper)**, and
   confirm the bed is 300 × 300 mm and the nozzle is 0.4 mm.
7. Add the printer connection separately if you use one. A Klipper printer is
   normally reached through Moonraker on TCP `7125`.

With PancakeSlicer `0.5.5`, this profile imports as a new printer with the basis
**MyKlipper 0.4 nozzle** and no ignored settings.

Importing a printer profile changes slicing settings only. It does not create a
network connection, flash firmware, or configure Klipper.

### Base printer specifications

| Setting | Value |
| :--- | :--- |
| Manufacturer | Anet |
| Model | A8 Plus |
| Year released | 2019 |
| Technology | FDM, Cartesian i3-style bed slinger |
| Build volume | 300 × 300 × 350 mm |
| Frame | Aluminum, open frame |
| Stock firmware | Marlin (replaced by Klipper on this machine) |
| Stock extruder | Direct drive, single gear |
| Stock nozzle | 0.4 mm |
| Filament diameter | 1.75 mm |
| Heated bed | Aluminum substrate with tempered glass; manual leveling from the factory, probe added on this build |
| Bed temperature | Up to about 100 °C; sources list 90–110 °C |
| Hotend temperature | Up to 250 °C with the stock hotend |
| Maximum speed | 120 mm/s nominal; 40–60 mm/s recommended |
| Layer range | 0.1–0.4 mm per the manual; 0.08–0.32 mm in this profile |
| Connectivity | microSD and USB-B; no built-in Wi-Fi or Ethernet |
| Power | 24 V, 360 W |
| Dimensions | 612 × 462 × 573 mm |
| Weight | 10 kg |

### Modifications assumed by this profile

| Modification | Value |
| :--- | :--- |
| Extruder | E3D Hemera, direct drive |
| Drive | Dual gear with adjustable tension idler |
| Reduction | 3.32:1 single-stage spur reduction |
| Steps per mm | 409 at 16× microstepping |
| Mass | 388 g including the V6 hotend |
| Hotend | E3D V6, 285 °C maximum |
| Nominal flow | 600 mm³/min, roughly 10 mm³/s |
| Motor current | 1.33 A |
| Firmware | Klipper |
| Probe | BLTouch, CR Touch, or another probe configured in Klipper |
| Host | Moonraker, commonly TCP `7125` |

The Hemera is heavier than the stock toolhead. Keep accelerations moderate until
you have run input shaping and confirmed the frame and belts are happy.

### Profile values

| Setting | Value |
| :--- | :--- |
| Template | Generic Klipper Printer (`MyKlipper 0.4 nozzle`) |
| G-code flavor | Klipper |
| Build area | 0,0 to 300,300 mm |
| Printable height | 350 mm |
| Nozzle | 0.4 mm |
| Layer height | 0.08–0.32 mm |
| Extruder | Direct drive, single extruder |
| Maximum speed X/Y/Z/E | 200 / 200 / 10 / 60 mm/s |
| Maximum acceleration X/Y/Z/E | 2000 / 2000 / 100 / 5000 mm/s² |
| Extruding / retracting / travel acceleration | 2000 / 3000 / 2000 mm/s² |
| Jerk X/Y/Z/E | 5 / 5 / 0.4 / 5 mm/s |
| Retraction | 0.8 mm at 30 mm/s |
| Deretraction speed | 30 mm/s |
| Minimum travel before retract | 1 mm |
| Z-hop | 0.4 mm |
| Wipe | Enabled, 70 % before wipe |
| Extruder clearance radius | 70 mm |

The motion limits are conservative starting points. If your Klipper
`printer.cfg` uses different `max_velocity`, `max_accel`, `max_z_velocity`, or
`square_corner_velocity` values, edit the profile to match. Klipper plans moves
using its own limits, and keeping the slicer and firmware values aligned avoids
surprises.

### Klipper requirements

This is a slicer preset, not a replacement for your Klipper `printer.cfg`. The
profile calls Klipper macros rather than embedding a full homing and probing
sequence.

Start G-code:

```gcode
M190 S[bed_temperature_initial_layer_single]
M109 S[nozzle_temperature_initial_layer]
PRINT_START EXTRUDER=[nozzle_temperature_initial_layer] BED=[bed_temperature_initial_layer_single]
```

End G-code:

```gcode
PRINT_END
```

Your `printer.cfg` should therefore provide:

- a `PRINT_START` macro that accepts `EXTRUDER` and `BED` parameters;
- homing and any probe or bed-mesh routine inside `PRINT_START`;
- a priming move before the first extrusion;
- a `PRINT_END` macro that retracts, lifts, parks, and turns off heaters and
  motors;
- `max_extrude_only_velocity` of at least 30 mm/s so retractions are not
  artificially slowed;
- `max_extrude_only_accel` of at least 1000 mm/s²;
- pressure advance tuned for the filament and hotend;
- input shaping calibrated for the Hemera toolhead.

If your macros use different names or parameters, edit the start and end G-code
in the profile to match. A mismatch produces an `Unknown command` or
`Missing parameter` error at the start of a print.

Example macro shape, not a replacement for your working config:

```ini
[gcode_macro PRINT_START]
gcode:
    {% set bed = params.BED|default(60)|float %}
    {% set extruder = params.EXTRUDER|default(200)|float %}
    G28
    BED_MESH_CALIBRATE
    M190 S{bed}
    M109 S{extruder}
    ; add your prime line here
```

If you probe once and save a mesh instead of probing every print, replace
`BED_MESH_CALIBRATE` with `BED_MESH_PROFILE LOAD=default`.

### Recommended starting settings

| Material | Nozzle | Bed | Fan | Print speed | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| PLA | 200–215 °C | 60 °C | 100 % | 50–80 mm/s | Start here; no enclosure needed |
| PETG | 230–245 °C | 70–80 °C | 50–80 % | 40–60 mm/s | Dry the filament if stringing is excessive |
| ABS | 240–260 °C | 100 °C | 0–20 % | 40–50 mm/s | Use an enclosure; the A8 Plus is open frame |
| TPU | 220–235 °C | 50–60 °C | 30–50 % | 20–30 mm/s | The Hemera's dual drive handles flexibles well |

General process starting points:

- 0.20 mm layers for everyday prints; 0.12–0.16 mm for detail.
- 20 mm/s first layer.
- 30–50 mm/s outer walls; 50–80 mm/s inner walls and infill.
- 150–200 mm/s travel.
- Maximum volumetric speed around 10–12 mm³/s for the V6; begin at 8 and run a
  volumetric-flow calibration.
- Pressure advance around 0.03–0.05 for a direct-drive Hemera; calibrate it for
  each filament.
- Keep `max_accel` at 2000 mm/s² or lower until input shaping and belt tension
  are verified. Raise it only after test prints show no ringing or layer shifts.
- Calibrate the probe Z offset and first layer before trusting a long print.

### Notes and caveats

- PancakeSlicer's bundled catalog has no Anet printer model. The profile must use
  the **Generic Klipper Printer** template, so its internal vendor/model metadata
  remains `Custom / Generic Klipper Printer`. The library name is still
  **Anet A8 Plus (Hemera, Klipper)**.
- The profile does not include a `pancake_record` or `pancake_values` field. Those
  are PancakeSlicer export hashes; the importer creates a fresh record from the
  profile name and values, like the custom filament profiles.
- The A8 Plus is not on PancakeSlicer's collision-checked supported-printer list.
  Non-planar slicing is checked against a generic oversized head. The Hemera and
  the probe change the real toolhead shape, so review the G-code preview from
  several angles and supervise the first non-planar print.
- Build height is 350 mm in this profile, matching the Anet manual and 3DPros.
  Marlin's A8 Plus example lists 370 mm; if your machine truly has the extra
  travel, raise `printable_height` after checking the physical limit.
- If your Klipper `position_max` is lower than 300 mm on X or Y, for example to
  account for probe offsets, reduce `printable_area` to match.
- If you later fit a different nozzle, change `nozzle_diameter` and the
  `printer_settings_id`/`name` together, then re-import the profile.
- Maximum bed temperature sources vary. This guide uses a conservative 100 °C.
- The stock A8 Plus profile is not included. This folder targets the modified
  Hemera/Klipper machine.

## Adding another printer

1. Export a machine preset from OrcaSlicer, or start from a nearby catalog model.
2. Include `printer_settings_id` (or `"type": "machine"`), `inherits`,
   `nozzle_diameter`, `printable_area`, `printable_height`, and `gcode_flavor`.
3. Name the file with lowercase, hyphenated words and add it to this folder.
4. Run `./scripts/validate.sh` from the repository root.

## Sources

- [3DPros: Anet A8 Plus specifications](https://3dpros.com/printers/anet-a8-plus)
- [Anet A8 Plus user manual](https://m.media-amazon.com/images/I/A10IK3ZotGL.pdf)
- [E3D Hemera datasheet](https://e3d-online.zendesk.com/hc/en-us/article_attachments/360018157138)
- [Klipper configuration reference](https://www.klipper3d.org/Config_Reference.html)
- [Klipper slicer guidance](https://www.klipper3d.org/Slicers.html)
- [UltiMaker Cura Anet A8 Plus definition](https://github.com/Ultimaker/Cura/blob/main/resources/definitions/anet3d_a8_plus.def.json)
- [All3DP: Anet A8 Plus review](https://all3dp.com/1/anet-a8-plus-review-3d-printer-specs)
- [SimplyPrint: Anet A8 Plus specs](https://simplyprint.io/compatibility/anet-a8-plus)
- [Endurancelasers: Anet A8 Plus settings](https://endurancelasers.com/data/anet-a8-plus)
- [Anet A8 Plus Klipper configuration example](https://gist.github.com/jeanfbrito/88a561b58b85a0c6a46da9389ec2197c)
