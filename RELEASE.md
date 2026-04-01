# Release Process

## Branch Strategy

- **`main`** — active development, unreleased
- **`release-2.6`** — AAP 2.6 stable releases
- **`release-2.7`** — AAP 2.7 stable releases (future)

Each AAP minor version gets its own release branch. Patch releases are tagged on that branch.

## Cutting a Release

1. Create a release branch (first time for a new AAP version):
   ```bash
   git checkout -b release-2.6
   ```

2. Bump `version` in `Chart.yaml` (e.g. `0.1.0` → `0.1.1` for patches, `0.1.0` → `0.2.0` for minor chart changes).

3. Update `CHANGELOG.md` — move unreleased items under the new version heading with today's date.

4. Commit and tag:
   ```bash
   git add Chart.yaml CHANGELOG.md
   git commit -m "chore: release v0.1.0"
   git tag v0.1.0
   git push origin release-2.6 --tags
   ```

5. GitHub Actions will lint the release branch automatically on push.

## Versioning

Chart `version` is independent of `appVersion` (AAP version). Use:
- Patch bump (`0.1.x`) for bug fixes and documentation updates
- Minor bump (`0.x.0`) for new values or template features
- Major bump (`x.0.0`) for breaking changes to values structure
