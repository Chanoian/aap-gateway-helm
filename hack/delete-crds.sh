#!/usr/bin/env bash
# Usage: ./hack/delete-crds.sh
# Deletes all AAP-related CRDs from the current oc context.
# Run this before installing a different AAP operator version so stale CRDs
# from the previous version do not conflict with the new operator's CRDs.
#
# WARNING: This will delete the CRD definitions AND all CR instances of those
# types in the cluster. Make sure the AAP operator is uninstalled first.

set -euo pipefail

if ! command -v oc &>/dev/null; then
  echo "ERROR: oc not found in PATH" >&2
  exit 1
fi

if ! oc whoami &>/dev/null; then
  echo "ERROR: not logged in to a cluster (run: oc login ...)" >&2
  exit 1
fi

echo "Cluster: $(oc whoami --show-server)"
echo ""
echo "WARNING: This will delete the following CRDs and all their CR instances."
echo ""

WANTED=(
  automationcontrollers.automationcontroller.ansible.com
  automationhubs.automationhub.ansible.com
  ansibleautomationplatforms.aap.ansible.com
  edas.eda.ansible.com
  ansiblelightspeeds.lightspeed.ansible.com
)

FOUND=()
for crd in "${WANTED[@]}"; do
  if oc get crd "$crd" &>/dev/null; then
    echo "  - $crd"
    FOUND+=("$crd")
  fi
done

if [[ ${#FOUND[@]} -eq 0 ]]; then
  echo "No AAP CRDs found on cluster. Nothing to delete."
  exit 0
fi

echo ""
read -r -p "Delete these ${#FOUND[@]} CRD(s)? [y/N] " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
for crd in "${FOUND[@]}"; do
  echo "  -> deleting $crd"
  oc delete crd "$crd" --ignore-not-found
done

echo ""
echo "Done. ${#FOUND[@]} CRD(s) deleted."
echo ""
echo "Next steps:"
echo "  1. Install the new AAP operator version"
echo "  2. Run ./hack/fetch-crds.sh to pull the new CRDs"
echo "  3. Run python3 hack/gen-schema.py to regenerate values.schema.json"
