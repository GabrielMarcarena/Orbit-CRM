#!/usr/bin/env bash
# Applies unapplied ledger migrations (tracked in schema_migrations) and runs tests/ledger_test.sql.
# Usage: scripts/ledger-test.sh [--no-migrate]
set -euo pipefail
cd "$(dirname "$0")/.."
DC="docker compose -f deploy/compose.yml --env-file deploy/.env"
PSQL="$DC exec -T postgres psql -U postgres -d orbit_ledger -v ON_ERROR_STOP=1"
if [ "${1:-}" != "--no-migrate" ]; then
  $PSQL -q -c "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"
  for f in ledger/migrations/*.sql; do
    v=$(basename "$f" .sql)
    if [ "$($PSQL -At -c "SELECT count(*) FROM schema_migrations WHERE version='$v'")" = 0 ]; then
      echo "applying $v"; $PSQL -1 -q < "$f"
    fi
  done
fi
$PSQL < tests/ledger_test.sql
