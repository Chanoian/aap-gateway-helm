# Changelog

All notable changes to this chart are documented here.
Versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `helm-docs` integration — `values.yaml` comments (`# --`) now drive the README values table automatically
- `README.md.gotmpl` template separates custom content from the auto-generated values section
- Pre-commit hook runs `helm-docs` and `helm lint --strict` before every commit
- GitHub PR template and issue templates (bug report, feature request)

### Changed
- `helm-lint.yml` CI trigger cleaned up — `release-*` branch patterns removed (single `main` branch model)
- CHANGELOG brought up to date with 1.0.0 and 1.0.1 entries

## [1.0.1] — 2026-04-07

### Fixed
- Remove `app.kubernetes.io/version` label — `appVersion` is now `>=2.5` and not a valid Kubernetes label value
- Use chart `version` (not `appVersion`) for `helm package` and Quay tags

### Changed
- Publish workflow now only produces two tags: exact version (`1.0.1`) and minor alias (`1.0`) — removed `latest`
- Publish triggers automatically when `Chart.yaml` changes on `main`

## [1.0.0] — 2026-04-07

### Added
- Versioned CRD directories (`crds/2.5/`, `crds/2.6/`) — single chart now supports both AAP 2.5 and 2.6+
- `hack/fetch-crds.sh` now requires an explicit `<version>` argument and saves to `crds/<version>/`
- `hack/gen-schema.py` accepts `--version` flag; defaults to latest version directory
- OCI publish to `quay.io/achanoia/aap-gateway` via GitHub Actions
- README: OCI install instructions, full values reference, status badges

### Changed
- Retired `release-2.5` and `release-2.6` branches — all development on `main`
- `appVersion` is now `>=2.5` (informational only); chart `version` is independent semver
- `fetch-crds.sh` no longer auto-patches `Chart.yaml` — operator build version is reported only
- Schema generated from latest CRDs (`crds/2.6/` superset covers 2.5 users)

## [0.1.0] — 2026-04-02

### Added
- Initial chart release for AAP 2.5 and 2.6
- Full `AnsibleAutomationPlatform` CR rendering from `values.yaml`
- Support for external PostgreSQL and Redis via secret references
- Direct pass-through for all three components (Controller, EDA, Hub)
- Top-level `extraSpec` deep-merge override for arbitrary spec fields
- `values.schema.json` with type and enum validation
- GitHub Actions CI for `helm lint` and `helm template`
