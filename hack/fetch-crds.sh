#!/usr/bin/env bash
# Usage: ./hack/fetch-crds.sh
# Fetches all AAP-related CRDs from the current oc context and saves them to crds/
# Run this whenever a new AAP build ships and you need to update the CRD reference files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRDS_DIR="$REPO_ROOT/crds"

if ! command -v oc &>/dev/null; then
  echo "ERROR: oc not found in PATH" >&2
  exit 1
fi

if ! oc whoami &>/dev/null; then
  echo "ERROR: not logged in to a cluster (run: oc login ...)" >&2
  exit 1
fi

echo "Cluster: $(oc whoami --show-server)"
echo "Fetching AAP CRDs into $CRDS_DIR/"
echo ""

mkdir -p "$CRDS_DIR"

WANTED=(
  automationcontrollers.automationcontroller.ansible.com
  automationhubs.automationhub.ansible.com
  ansibleautomationplatforms.aap.ansible.com
  edas.eda.ansible.com
  ansiblelightspeeds.lightspeed.ansible.com
)

CRDS=()
for crd in "${WANTED[@]}"; do
  if oc get crd "$crd" &>/dev/null; then
    CRDS+=("customresourcedefinition.apiextensions.k8s.io/$crd")
  else
    echo "  WARNING: $crd not found on cluster, skipping" >&2
  fi
done

if [[ ${#CRDS[@]} -eq 0 ]]; then
  echo "No CRDs matching *.ansible.com found. Is the AAP operator installed?" >&2
  exit 1
fi

for crd_ref in "${CRDS[@]}"; do
  crd_name="${crd_ref#customresourcedefinition.apiextensions.k8s.io/}"
  # Use the resource plural name (first segment) as filename
  filename="${crd_name%%.*}.yaml"
  echo "  -> $crd_name"
  oc get crd "$crd_name" -o yaml | python3 -c "
import sys, yaml
doc = yaml.safe_load(sys.stdin)
meta = doc.get('metadata', {})
for field in ('uid', 'resourceVersion', 'generation', 'creationTimestamp', 'managedFields', 'annotations'):
    meta.pop(field, None)
doc.pop('status', None)
print(yaml.dump(doc, default_flow_style=False, allow_unicode=True))
" > "$CRDS_DIR/$filename"
done

# ── Extract operator version from live cluster annotation ──────────────────
echo ""
OPERATOR_VERSION=""
if oc get crd ansibleautomationplatforms.aap.ansible.com &>/dev/null; then
  OPERATOR_VERSION=$(oc get crd ansibleautomationplatforms.aap.ansible.com \
    -o json 2>/dev/null | python3 -c "
import sys, json
try:
    crd = json.loads(sys.stdin.read())
    annotations = crd.get('metadata', {}).get('annotations', {})
    for k, v in annotations.items():
        if 'installed-alongside' in k and '.v' in v:
            print(v.split('.v', 1)[1])
            break
except Exception:
    pass
" 2>/dev/null || true)
fi

# ── Idempotency check and Chart.yaml patch ────────────────────────────────
if [[ -n "$OPERATOR_VERSION" ]]; then
  CURRENT_VERSION=$(grep '^appVersion:' "$REPO_ROOT/Chart.yaml" | sed 's/appVersion: *//;s/"//g')
  if [[ "$CURRENT_VERSION" == "$OPERATOR_VERSION" ]]; then
    echo "Already up to date: $OPERATOR_VERSION — no publish required."
  else
    python3 -c "
import sys, re
path = sys.argv[1]; ver = sys.argv[2]
content = open(path).read()
content = re.sub(r'^appVersion:.*\$', f'appVersion: \"{ver}\"', content, flags=re.MULTILINE)
open(path, 'w').write(content)
" "$REPO_ROOT/Chart.yaml" "$OPERATOR_VERSION"
    echo "Updated appVersion in Chart.yaml: $OPERATOR_VERSION (was: $CURRENT_VERSION)"
  fi
else
  echo "  WARNING: Could not detect operator version from CRD annotations — appVersion in Chart.yaml unchanged." >&2
fi

echo ""
echo "Done. ${#CRDS[@]} CRD(s) saved to crds/"
echo ""
echo "Next steps:"
echo "  1. Review the files in crds/"
echo "  2. Run: python3 hack/gen-schema.py"
echo "  3. Commit: git add crds/ Chart.yaml values.schema.json && git commit -m 'crds: update for <aap-version>'"
