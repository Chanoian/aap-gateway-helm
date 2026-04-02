# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Production-grade Helm chart (`aap-gateway`) for deploying Ansible Automation Platform (AAP) 2.6 Gateway on Red Hat OpenShift. The chart lives at the repo root (not in a `charts/` subfolder). Releases follow the same versioned branch model as the main AAP operator (`release-2.6`, `release-2.7`, etc.).

## Commands

```bash
# Lint the chart
helm lint .

# Lint strictly against all examples (what CI does)
for f in examples/*.yaml; do helm lint . --strict -f "$f"; done

# Render a specific example
helm template aap-gateway . -f examples/full-stack.yaml

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
`templates/aap.yaml` renders the single `AnsibleAutomationPlatform` CR (`apiVersion: aap.ansible.com/v1alpha1, kind: AnsibleAutomationPlatform`). The spec is built as a Go dict so `.Values.extraSpec` can override any field cleanly. Each component section (controller, eda, hub) uses a direct pass-through loop: every key set under the component in `values.yaml` is emitted as-is into the component sub-spec, so any CRD field can be set without needing an explicit `extraSpec` block. The top-level `extraSpec` provides a final override layer for spec fields not tied to a specific component.

### values.yaml Conventions
- Use `{{- fail }}` for required field enforcement — missing values never silently produce broken manifests
- `extraSpec: {}` at top-level provides an escape hatch for spec fields not explicitly modeled
- Empty string values are omitted from the rendered CR (only non-empty values make it into the manifest)

### Release Strategy
- `main` is a read-only pointer to the latest release branch — **never commit directly to `main`**
- Each AAP minor version gets a `release-2.x` branch (`release-2.5`, `release-2.6`, etc.)
- All work (fixes, schema updates, CRD updates) goes to the appropriate release branch first
- `main` is fast-forward merged from the latest release branch after changes land there:
  ```bash
  git checkout main
  git merge --ff-only release-2.6
  git push origin main
  ```
- Bug fixes that apply to older branches are cherry-picked: `git cherry-pick <sha>`
- CI runs `helm lint --strict` and `helm template` on every PR against `main` and `release-*`

### Per-Build Release Workflow
When AAP ships a new build (e.g. `2.6.0+0.1774648945`):
1. `git checkout release-2.6`
2. Update `appVersion` in `Chart.yaml` to the new build string
3. Run `./hack/fetch-crds.sh` to pull fresh CRDs from a live cluster (or drop them manually into `crds/`)
4. Update `values.schema.json` and `values.yaml` if the CR spec changed
5. `helm lint . --strict -f examples/*.yaml` — must pass
6. Commit, tag (`chart-2.6.0-0.1774648945`), push
7. Fast-forward `main`: `git checkout main && git merge --ff-only release-2.6 && git push origin main`

### Constraints
- No subcharts or Helm dependencies
- No Kustomize
- No hardcoded environment-specific values

## Later Goals (not yet implemented)
- OpenShift Route templates for LTM Purpose in case of Active Passive 
- HashiCorp VSO (VaultConnection, VaultAuth, VaultStaticSecret)
