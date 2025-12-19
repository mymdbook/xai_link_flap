#!/usr/bin/env bash
set -euo pipefail

if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "Not inside a git repository."
  exit 1
fi

cd "$repo_root"

if ! command -v mdbook >/dev/null 2>&1; then
  echo "mdbook not found in PATH."
  exit 1
fi

if [[ "${1:-}" == "serve" ]]; then
  shift
  mdbook serve --open
  exit 0
fi

if [[ $# -gt 0 ]]; then
  msg="$*"
else
  msg="Update book"
fi

rm -rf book
mdbook build

if [[ -z "$(git status --porcelain)" ]]; then
  echo "No changes to commit."
  exit 0
fi

git add -A
git commit -m "$msg"
git push
