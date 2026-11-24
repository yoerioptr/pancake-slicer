# Custom Filament Profiles

This folder holds optional, user-importable filament profiles. PancakeSlicer does
not load this directory automatically; import the file through the UI.

## Extrudr GreenTEC Pro

| File | Purpose |
| :--- | :--- |
| `extrudr-greentec-pro.json` | JSON filament profile for the Voron 0.1 with a 0.4 mm nozzle |

The profile name in the library becomes **Extrudr GreenTEC Pro**.

### Import

1. Open PancakeSlicer.
2. Choose **File → Import profiles…**.
3. Select `extrudr-greentec-pro.json`.
4. Review the import preview and add or replace the profile.
5. Open **Library → Filaments**, select **Extrudr GreenTEC Pro**, and assign it to
   the slot you want.

The same JSON file can also be imported with OrcaSlicer or another compatible
slicer.

### Profile values

Base values taken from the
[Extrudr GreenTEC Pro product page](https://extrudr.com/en/inlt/products/greentec-pro/),
with the temperature, shrinkage, flow, and pressure-advance overrides noted
below:

| Setting | Value |
| :--- | :--- |
| Material | PLA |
| Vendor | Extrudr |
| Diameter | 1.75 mm |
| Density | 1.35 g/cm³ (ISO 1183) |
| Nozzle temperature | 210 °C first layer, 205 °C other layers — configured range 210–230 °C |
| Bed temperature | 60 °C — published range 20–90 °C |
| Shrinkage | 0.4 % (ISO 294-4), compensated as 100.4 % XY |
| Max volumetric speed | 16 mm³/s for a 0.4 mm nozzle |
| Flow ratio | 0.90 |
| Pressure advance | 0.02 (enabled) |
| Cooling fan | 30–80 % |
| Drying | 60 °C for 0–4 h |
| Heat resistance | Vicat A 160 °C (ISO 306), HDT/B 115 °C |
| Enclosure / hardened nozzle | Not required |

### Notes

- The profile inherits from `Generic PLA @System` and is not based on the
  downloaded `Extrudr PLA NX2 Matt` file, which declares a 2.85 mm filament
  diameter.
- The density, shrinkage, and Vicat values reflect the property table supplied
  for this spool: 1.35 g/cm³, 0.4 %, and 160 °C respectively.
- The nozzle range is set to 210–230 °C, matching Extrudr's published
  recommendation. The subsequent-layer temperature is 205 °C as configured for
  this profile.
- The profile is a starting point. Run a temperature tower and flow/pressure
  advance calibration for your printer and spool.
- No `pancake_record` or `pancake_values` fields are included. Those are
  PancakeSlicer export hashes; the importer creates a fresh record from the
  profile name and values.

## Adding another profile

1. Add the JSON file to this folder using a lowercase, hyphenated filename.
2. Run `./scripts/validate.sh` from the repository root.

## See also

- [Custom Printer Profiles](../printer/README.md)
