#!/usr/bin/env bash
# Restores a backup into a THROWAWAY postgres container (never touches the live stack) and prints row counts.
# Usage: scripts/restore.sh backups/<timestamp>   (compare output with: scripts/restore.sh --live)
set -euo pipefail
cd "$(dirname "$0")/.."
DC="docker compose -f deploy/compose.yml --env-file deploy/.env"
counts() { # $1 = psql command prefix, $2 = db
  $1 -d "$2" -At -F ' ' -f - < scripts/rowcounts.sql | sed "s/^/$2 /"
}
if [ "${1:-}" = "--live" ]; then
  for db in twenty n8n orbit_ledger; do counts "$DC exec -T postgres psql -U postgres" "$db"; done
  exit 0
fi
B="${1:?usage: restore.sh backups/<dir> | --live}"
(cd "$B" && sha256sum -c SHA256SUMS >/dev/null) || { echo "checksum mismatch" >&2; exit 1; }
C=orbit-scratch-restore
docker rm -f $C >/dev/null 2>&1 || true
docker run -d --name $C -e POSTGRES_PASSWORD=scratch postgres:16-alpine@sha256:721873c34ceb9f8d8fc265984940dc982404c105f19ad51be9fdc5970a6080ea >/dev/null
trap 'docker rm -f $C >/dev/null 2>&1' EXIT
for i in $(seq 1 60); do docker exec $C pg_isready -U postgres >/dev/null 2>&1 && break; sleep 1; done
docker exec $C pg_isready -U postgres >/dev/null || { echo "scratch postgres did not start" >&2; exit 1; }
sleep 3  # the postgres image restarts once after its init phase
# roles referenced by the dumps' grants
for role in twenty n8n orbit_ledger; do docker exec $C psql -U postgres -c "CREATE ROLE \"$role\"" >/dev/null; done
for db in twenty n8n orbit_ledger; do
  docker exec $C psql -U postgres -c "CREATE DATABASE \"$db\"" >/dev/null
  docker exec -i $C pg_restore -U postgres --no-owner -d "$db" < "$B/$db.dump"
  counts "docker exec -i $C psql -U postgres" "$db"
done
