## Summary

<!-- What does this PR change and why? -->

## Type of change

- [ ] Bug fix
- [ ] New feature / values addition
- [ ] Schema update (CRD change)
- [ ] Documentation
- [ ] CI / tooling

## Checklist

- [ ] `helm lint --strict` passes against all examples: `for f in examples/*.yaml; do helm lint . --strict -f "$f"; done`
- [ ] `helm template` renders cleanly: `for f in examples/*.yaml; do helm template aap-gateway . -f "$f" > /dev/null; done`
- [ ] `Chart.yaml` version bumped (if this should trigger a publish)
- [ ] `CHANGELOG.md` updated
