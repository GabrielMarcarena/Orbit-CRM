#!/bin/sh
# Creates one role + database per app. Runs once, on first start of an empty data volume.
set -eu
create() {
  role="$1"; pass="$2"; db="$3"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres <<SQL
CREATE ROLE "$role" LOGIN PASSWORD '$pass';
CREATE DATABASE "$db" OWNER "$role";
SQL
}
create twenty "$TWENTY_DB_PASSWORD" twenty
create n8n "$N8N_DB_PASSWORD" n8n
create orbit_ledger "$LEDGER_DB_PASSWORD" orbit_ledger
