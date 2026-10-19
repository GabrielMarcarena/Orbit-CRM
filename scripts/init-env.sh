#!/usr/bin/env bash
# Generates deploy/.env with random secrets. Refuses to overwrite an existing file.
set -euo pipefail
cd "$(dirname "$0")/../deploy"
[ -e .env ] && { echo "deploy/.env already exists; not overwriting" >&2; exit 1; }
r() { openssl rand -hex 24; }
sed -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(r)/" \
    -e "s/^TWENTY_DB_PASSWORD=.*/TWENTY_DB_PASSWORD=$(r)/" \
    -e "s/^N8N_DB_PASSWORD=.*/N8N_DB_PASSWORD=$(r)/" \
    -e "s/^LEDGER_DB_PASSWORD=.*/LEDGER_DB_PASSWORD=$(r)/" \
    -e "s/^TWENTY_ENCRYPTION_KEY=.*/TWENTY_ENCRYPTION_KEY=$(openssl rand -hex 32)/" \
    -e "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$(r)/" \
    .env.example > .env
chmod 600 .env
echo "wrote deploy/.env (back up N8N_ENCRYPTION_KEY and TWENTY_ENCRYPTION_KEY somewhere safe)"
