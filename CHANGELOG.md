# Changelog

All notable changes to this chart are documented here.
Versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial chart release for AAP 2.6
- Full `AnsibleAutomationPlatform` CR rendering from `values.yaml`
- Support for external PostgreSQL and Redis via secret references
- Per-component `extraSpec` passthrough for all five components
- Top-level `extraSpec` override for arbitrary spec fields
- `values.schema.json` with type and enum validation
- GitHub Actions CI for `helm lint` and `helm template`
