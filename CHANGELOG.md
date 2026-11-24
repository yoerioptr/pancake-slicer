# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-11-24

### Added
- `config/printer/` for optional custom printer profiles.
- `Anet A8 Plus (Hemera, Klipper)` machine preset for a modified A8 Plus with an
  E3D Hemera V6 direct-drive extruder, a bed probe, and Klipper.
- Import instructions in `config/printer/README.md`, `docs/printers.md`, and
  `docs/usage.md`.
- Validation for custom printer JSON profiles.

### Notes
- The profile is based on the `Generic Klipper Printer` catalog template because
  the bundled catalog has no Anet model. The library name is
  `Anet A8 Plus (Hemera, Klipper)`.
- Build volume is `300 × 300 × 350 mm` with a `0.4 mm` nozzle.
- The profile calls `PRINT_START` and `PRINT_END` and uses a `0.8 mm @ 30 mm/s`
  direct-drive retraction.
- Motion limits are conservative starting points (`200 mm/s`, `2000 mm/s²`) for
  the heavier Hemera toolhead. The README explains how to align them with
  Klipper's `printer.cfg` and how to tune pressure advance and input shaping.

## [0.2.0] - 2026-11-23

### Added
- `config/filament/` for optional custom filament profiles.
- `Extrudr GreenTEC Pro` JSON profile for the Voron 0.1 with a 0.4 mm nozzle.
- Import instructions in `config/filament/README.md` and `docs/usage.md`.
- Validation for custom filament JSON profiles.

### Notes
- The profile inherits from `Generic PLA @System`. Material values are:
  `1.35 g/cm³` density (ISO 1183), `0.4 %` shrinkage (ISO 294-4) with `100.4 %`
  XY compensation, and `160 °C` Vicat A (ISO 306).
- Nozzle temperatures are `210 °C` for the first layer and `205 °C` for other
  layers, with a configured range of `210–230 °C`. Bed temperature is `60 °C`.
- Maximum volumetric flow is `16 mm³/s`. Flow ratio is `0.90` and pressure
  advance is `0.02`, with pressure advance enabled in the profile.

## [0.1.1] - 2026-11-23

### Added
- `LICENSE` under the MIT License for this repository's configuration, scripts,
  and documentation.
- `scripts/init-env.sh` to create `.env` with a generated bearer token and mode
  `600`.
- `docs/security.md` covering the threat model, authentication limits, exposure
  guidance, and secrets hygiene.
- `docs/usage.md` covering first-run setup, uploads, slicing, non-planar safety,
  data locations, and resetting the app.
- `truenas/pancake-slicer.example.yaml` as a static, ready-to-paste custom app
  example.
- An `x-portals` entry so TrueNAS shows an **Open** button for the app.
- Public-repository documentation links and a validation check for the complete
  documentation set.

### Changed
- Rewrote the README for public distribution and removed private/proprietary
  wording.
- Expanded `.gitignore` with secret, certificate, editor, and temporary-file
  patterns.
- Updated installation and TrueNAS packaging notes to use `init-env.sh` and the
  public clone URL.

## [0.1.0] - 2026-11-23

### Added
- Standardized repository structure (`compose/`, `docs/`, `scripts/`, `truenas/`).
- `compose/compose.template.yaml` for the single-container PancakeSlicer app.
- `.env.example` with host paths, port, memory/job tuning, printer network,
  optional bearer token, and reverse-proxy variables.
- `render-compose.sh` to generate `build/compose.yaml` for the TrueNAS Custom App
  YAML editor.
- `validate.sh` for structural, security, storage, networking, and documentation
  checks.
- `check-secrets.sh` to prevent bearer tokens, private keys, and `.env` files from
  being committed.
- Documentation for installation, configuration, storage, networking, printers,
  reverse proxies, upgrades, backup/restore, and troubleshooting.
- TrueNAS SCALE Custom App packaging notes.
- GitHub Actions workflows for validation and automatic semver tagging.

### Changed
- Adapted the upstream `deploy/docker-compose.yml` into an environment-driven
  template suitable for TrueNAS.
- Replaced the upstream named volume with explicit host paths so state is
  visible to TrueNAS datasets and snapshots.
- Split the disposable `/data/jobs/stage-cache` into its own configurable host
  path so it can be excluded from backups.
- Pinned the image to `0.5.5` instead of `latest`.

### Security
- Dropped all Linux capabilities and enabled `no-new-privileges`.
- Added an 8 GB memory limit and optional bearer-token configuration.
- Rendered deployment YAML is written with mode `600` and gitignored.
