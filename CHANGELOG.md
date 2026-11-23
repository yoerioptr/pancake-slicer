# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
