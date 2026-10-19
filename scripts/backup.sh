#!/usr/bin/env bash
# Dumps twenty, n8n and orbit_ledger, plus Twenty's file volume and deploy/.env (needed to decrypt n8n/Twenty data).
# Output: backups/<timestamp>/ (mode 700, git-ignored). Copy it OFF this machine for real protection.
set -euo pipefail
cd "$(dirname "$0")/.."
DC="docker compose -f deploy/compose.yml --env-file deploy/.env"
OUT="backups/$(date -u +%Y%m%dT%H%M%SZ)"
umask 077; mkdir -p "$OUT"
for db in twenty n8n orbit_ledger; do
  $DC exec -T postgres pg_dump -U postgres -Fc "$db" > "$OUT/$db.dump"
  [ -s "$OUT/$db.dump" ] || { echo "empty dump for $db" >&2; exit 1; }
done
docker run --rm -v orbit_twenty-files:/data:ro -v "$PWD/$OUT":/out alpine:3@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 tar czf /out/twenty-files.tgz -C /data .
cp deploy/.env "$OUT/env.backup"
(cd "$OUT" && sha256sum * > SHA256SUMS)
echo "$OUT"
