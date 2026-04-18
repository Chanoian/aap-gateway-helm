#!/usr/bin/env bash
# Usage: ./hack/fetch-vso-crds.sh [vso-version]
#   vso-version: VSO release tag (e.g. 0.9.0). Defaults to main.
# Fetches VSO CRDs from the hashicorp/vault-secrets-operator GitHub repo
# and saves them to crds/vso/
# Run this whenever you upgrade VSO or need to refresh the CRD reference files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION="${1:-main}"
REF="$VERSION"
[[ "$REF" != "main" ]] && REF="v$VERSION"

CRDS_DIR="$REPO_ROOT/crds/vso"
BASE_URL="https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/${REF}/chart/crds"

WANTED=(
  secrets.hashicorp.com_vaultconnections.yaml
  secrets.hashicorp.com_vaultauths.yaml
  secrets.hashicorp.com_vaultstaticsecrets.yaml
)

if ! command -v curl &>/dev/null; then
  echo "ERROR: curl not found in PATH" >&2
  exit 1
fi

echo "Fetching VSO CRDs (ref: ${REF}) into crds/vso/"
echo ""

mkdir -p "$CRDS_DIR"

for filename in "${WANTED[@]}"; do
  url="$BASE_URL/$filename"
  echo "  -> $filename"
  if ! curl -fsSL "$url" -o "$CRDS_DIR/$filename"; then
    echo "ERROR: failed to fetch $url" >&2
    exit 1
  fi
done

echo ""
echo "Done. ${#WANTED[@]} CRD(s) saved to crds/vso/"
echo ""
echo "Next steps:"
echo "  1. Run: python3 hack/gen-schema.py"
echo "  2. Commit: git add crds/vso/ values.schema.json && git commit -m 'crds: update VSO CRDs to ${VERSION}'"
