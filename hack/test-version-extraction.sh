#!/usr/bin/env bash
# Tests for the version extraction and Chart.yaml patching logic used in fetch-crds.sh.
# No oc or cluster required — tests pure parsing and file-patching logic.
# Run: bash hack/test-version-extraction.sh

set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
    FAIL=$((FAIL + 1))
  fi
}

# ── Shared extraction snippet (mirrors fetch-crds.sh implementation) ───────
# Input: full CRD JSON object (from oc get crd -o json)
extract_version() {
  echo "$1" | python3 -c "
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
"
}

# ── Test 1: parse version from annotation ──────────────────────────────────
RESULT=$(extract_version '{"metadata": {"annotations": {"operatorframework.io/installed-alongside-abc123": "aap/aap-operator.v2.6.0-0.1774648945"}}}')
assert_eq "extracts version from annotation" "2.6.0-0.1774648945" "$RESULT"

# ── Test 2: empty annotations object returns nothing ───────────────────────
RESULT=$(extract_version '{"metadata": {"annotations": {}}}')
assert_eq "returns empty when annotations absent" "" "$RESULT"

# ── Test 3: annotation present but no .v marker returns nothing ────────────
RESULT=$(extract_version '{"metadata": {"annotations": {"operatorframework.io/installed-alongside-abc123": "aap/aap-operator"}}}')
assert_eq "returns empty when .v marker absent" "" "$RESULT"

# ── Test 4: Go-style map output (old jsonpath bug) returns nothing safely ──
RESULT=$(extract_version 'map[operatorframework.io/installed-alongside-abc123:aap/aap-operator.v2.6.0-0.1774648945]')
assert_eq "Go-style map input returns empty (not a crash)" "" "$RESULT"

# ── Test 4: idempotency — versions match, Chart.yaml is not touched ────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/Chart.yaml" << 'YAML'
apiVersion: v2
name: aap-gateway
version: 0.1.0
appVersion: "2.6.0-0.1774648945"
YAML
BEFORE=$(cat "$TMPDIR/Chart.yaml")

OPERATOR_VERSION="2.6.0-0.1774648945"
CURRENT=$(grep '^appVersion:' "$TMPDIR/Chart.yaml" | sed 's/appVersion: *//;s/"//g')
if [[ "$CURRENT" != "$OPERATOR_VERSION" ]]; then
  python3 -c "
import sys, re
path = sys.argv[1]; ver = sys.argv[2]
content = open(path).read()
content = re.sub(r'^appVersion:.*$', f'appVersion: \"{ver}\"', content, flags=re.MULTILINE)
open(path, 'w').write(content)
" "$TMPDIR/Chart.yaml" "$OPERATOR_VERSION"
fi

AFTER=$(cat "$TMPDIR/Chart.yaml")
assert_eq "Chart.yaml unchanged when version matches" "$BEFORE" "$AFTER"

# ── Test 5: version mismatch — Chart.yaml is patched ──────────────────────
cat > "$TMPDIR/Chart.yaml" << 'YAML'
apiVersion: v2
name: aap-gateway
version: 0.1.0
appVersion: "2.6.0-0.1234567890"
YAML

OPERATOR_VERSION="2.6.0-0.1774648945"
CURRENT=$(grep '^appVersion:' "$TMPDIR/Chart.yaml" | sed 's/appVersion: *//;s/"//g')
if [[ "$CURRENT" != "$OPERATOR_VERSION" ]]; then
  python3 -c "
import sys, re
path = sys.argv[1]; ver = sys.argv[2]
content = open(path).read()
content = re.sub(r'^appVersion:.*$', f'appVersion: \"{ver}\"', content, flags=re.MULTILINE)
open(path, 'w').write(content)
" "$TMPDIR/Chart.yaml" "$OPERATOR_VERSION"
fi

RESULT=$(grep '^appVersion:' "$TMPDIR/Chart.yaml" | sed 's/appVersion: *//;s/"//g')
assert_eq "Chart.yaml patched when version changes" "2.6.0-0.1774648945" "$RESULT"

# ── Test 6: surrounding Chart.yaml content is preserved after patch ─────────
cat > "$TMPDIR/Chart.yaml" << 'YAML'
apiVersion: v2
name: aap-gateway
description: Helm chart for deploying AAP
version: 0.1.0
appVersion: "2.6.0-0.0000000000"
keywords:
  - ansible
YAML

OPERATOR_VERSION="2.6.0-0.1774648945"
python3 -c "
import sys, re
path = sys.argv[1]; ver = sys.argv[2]
content = open(path).read()
content = re.sub(r'^appVersion:.*$', f'appVersion: \"{ver}\"', content, flags=re.MULTILINE)
open(path, 'w').write(content)
" "$TMPDIR/Chart.yaml" "$OPERATOR_VERSION"

grep -q "apiVersion: v2" "$TMPDIR/Chart.yaml" && \
grep -q "keywords:" "$TMPDIR/Chart.yaml" && \
SURROUNDING_OK=true || SURROUNDING_OK=false
assert_eq "surrounding Chart.yaml content preserved after patch" "true" "$SURROUNDING_OK"

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
