#!/usr/bin/env bash
# Dumps twenty, n8n and orbit_ledger, plus Twenty's file volume.
# deploy/.env (all passwords + the encryption keys needed to decrypt n8n/Twenty data) is included ONLY when
# ORBIT_BACKUP_PASSPHRASE is set, and then only encrypted (AES-256). The dumps contain customer data in clear text:
# encrypt or protect the whole folder before copying it off this machine.
set -euo pipefail
cd "$(dirname "$0")/.."
DC="docker compose -f deploy/compose.yml --env-file deploy/.env"
OUT="backups/$(date -u +%Y%m%dT%H%M%SZ)"
umask 077; mkdir -p "$OUT"
for db in twenty n8n orbit_ledger; do
  $DC exec -T postgres pg_dump -U postgres -Fc "$db" > "$OUT/$db.dump"
  [ -s "$OUT/$db.dump" ] || { echo "empty dump for $db" >&2; exit 1; }
done
docker volume inspect orbit_twenty-files >/dev/null || { echo "volume orbit_twenty-files missing" >&2; exit 1; }
docker run --rm -u "$(id -u):$(id -g)" -v orbit_twenty-files:/data:ro -v "$PWD/$OUT":/out alpine:3@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 tar czf /out/twenty-files.tgz -C /data .
if [ -n "${ORBIT_BACKUP_PASSPHRASE:-}" ]; then
  openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:ORBIT_BACKUP_PASSPHRASE -in deploy/.env -out "$OUT/env.backup.enc"
else
  echo "WARNING: deploy/.env NOT included (set ORBIT_BACKUP_PASSPHRASE to include it encrypted). Back it up separately, or encrypted data cannot be recovered." >&2
fi
chmod 600 "$OUT/twenty-files.tgz"
(cd "$OUT" && sha256sum * > SHA256SUMS)
echo "$OUT"
