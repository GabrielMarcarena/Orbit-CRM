#!/usr/bin/env bash
# Scans tracked + untracked-but-not-ignored files for secrets. Exit 1 on any finding.
set -euo pipefail
cd "$(dirname "$0")/.."
# copy only files git would commit, so ignored files (deploy/.env, backups/) are not scanned or leaked
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git ls-files -z --cached --others --exclude-standard | xargs -0 -I{} cp --parents {} "$TMP" 2>/dev/null || true
docker run --rm -v "$TMP":/repo zricethezav/gitleaks:v8.30.1 detect --no-git --source /repo --config /repo/.gitleaks.toml --redact --exit-code 1
