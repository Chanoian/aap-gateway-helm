#!/usr/bin/env bash
# Install local git hooks for this repo.
# Run once after cloning: bash hack/setup-hooks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

cp "$REPO_ROOT/hack/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "Installed pre-commit hook."
echo "  - runs helm-docs to keep README in sync with values.yaml"
echo "  - runs helm lint --strict against all examples"
