#!/usr/bin/env bash
# Tests for the operator version extraction logic used in fetch-crds.sh,
# and the CRD directory version sort used in gen-schema.py.
# No oc or cluster required — tests pure parsing logic.
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

# ── Tests 5-7: CRD directory version sort (gen-schema.py version_key logic) ─
# Lexical sort would put 2.10 before 2.9; numeric sort must order it after.
version_key_sort() {
  python3 -c "
import sys
def version_key(name):
    try:
        return tuple(int(x) for x in name.split('.'))
    except ValueError:
        return (0,)
versions = sys.argv[1:]
print(sorted(versions, key=version_key)[-1])
" "$@"
}

RESULT=$(version_key_sort 2.5 2.6 2.9 2.10)
assert_eq "2.10 sorts after 2.9 (not before, as lexical sort would)" "2.10" "$RESULT"

RESULT=$(version_key_sort 2.5 2.6)
assert_eq "selects highest of two single-digit minor versions" "2.6" "$RESULT"

RESULT=$(version_key_sort 2.9 2.10 2.11)
assert_eq "multi-digit minor versions sort correctly across the board" "2.11" "$RESULT"

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
