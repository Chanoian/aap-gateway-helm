# Changelog

All notable changes to this chart are documented here.
Versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] — 2026-04-02

### Added
- Initial chart release for AAP 2.6
- Full `AnsibleAutomationPlatform` CR rendering from `values.yaml`
- Support for external PostgreSQL and Redis via secret references
- Direct pass-through for all three components (Controller, EDA, Hub) — any CRD spec field can be set directly under the component key
- Top-level `extraSpec` override for arbitrary spec fields
- `values.schema.json` with type and enum validation
- GitHub Actions CI for `helm lint` and `helm template`
