# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Production-grade Helm chart (`aap-gateway`) for deploying Ansible Automation Platform (AAP) 2.6 Gateway on Red Hat OpenShift. The chart lives at the repo root (not in a `charts/` subfolder). Releases follow the same versioned branch model as the main AAP operator (`release-2.6`, `release-2.7`, etc.).

## Commands

```bash
# Lint the chart
helm lint .

# Lint strictly (validates against values.schema.json)
helm lint . --strict -f ci/test-values.yaml

# Render templates with CI test values
helm template aap-gateway . -f ci/test-values.yaml

# Package the chart
helm package .
```

## Architecture

### Chart Structure
- `Chart.yaml` — `apiVersion: v2`, `name: aap-gateway`, `appVersion: "2.6"`
- `values.yaml` — single source of truth; every field has an inline comment; all optional features disabled by default (`eda.disabled: true`, etc.); required fields (`namespace`, `hostname`) are empty strings with `# REQUIRED` comments
- `values.schema.json` — JSON Schema (draft-07) for type and enum validation at `helm install`/`helm lint --strict` time
- `templates/_helpers.tpl` — labels helper, `aap-gateway.resourceRequirements` helper, `aap-gateway.storageRequirements` helper
- `ci/test-values.yaml` — all required fields populated; used by `helm template` in CI
- `crds/` — reference CRD definitions for development only; NOT packaged with the chart (AAP Operator installs these CRDs)

### Key Template
`templates/aap.yaml` renders the single `AnsibleAutomationPlatform` CR (`apiVersion: aap.ansible.com/v1alpha1, kind: AnsibleAutomationPlatform`). The spec is built as a Go dict so `.Values.extraSpec` can override any field cleanly. Per-component `extraSpec` maps in values.yaml pass arbitrary fields into each component (controller, eda, hub, lightspeed, mcp).

### values.yaml Conventions
- Use `{{- fail }}` for required field enforcement — missing values never silently produce broken manifests
- `extraSpec: {}` at both top-level and per-component provides escape hatches for fields not explicitly modeled
- Empty string values are omitted from the rendered CR (only non-empty values make it into the manifest)

### Release Strategy
- `main` holds latest development
- Each AAP minor version gets a `release-2.x` branch
- CI runs `helm lint --strict` and `helm template` on every PR

### Constraints
- No subcharts or Helm dependencies
- No Kustomize
- No hardcoded environment-specific values

## Later Goals (not yet implemented)
- OpenShift Route templates
- HashiCorp VSO (VaultConnection, VaultAuth, VaultStaticSecret)
- Per-component ResourceQuota and LimitRange (each component has its own per-module limits)
