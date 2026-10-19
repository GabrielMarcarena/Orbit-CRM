#!/usr/bin/env bash
# Applies ledger migrations and runs tests/ledger_test.sql against the running postgres container.
# Usage: scripts/ledger-test.sh [--no-migrate]
set -euo pipefail
cd "$(dirname "$0")/.."
DC="docker compose -f deploy/compose.yml --env-file deploy/.env"
PSQL="$DC exec -T postgres psql -U postgres -d orbit_ledger -v ON_ERROR_STOP=1"
if [ "${1:-}" != "--no-migrate" ]; then
  for f in ledger/migrations/*.sql; do $PSQL < "$f" >/dev/null; done
fi
$PSQL < tests/ledger_test.sql
