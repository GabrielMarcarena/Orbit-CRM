#!/usr/bin/env bash
# Exit 0 only if every container is healthy (twenty-worker has no healthcheck: must be running) and each route answers.
set -uo pipefail
cd "$(dirname "$0")/.."
DC="docker compose -f deploy/compose.yml --env-file deploy/.env --profile core --profile crm"
PORT=$(grep -E '^ORBIT_HTTP_PORT=' deploy/.env | cut -d= -f2)
fail=0
while IFS=$'\t' read -r svc state health; do
  if [ "$svc" = "twenty-worker" ]; then ok=$([ "$state" = running ] && echo 1 || echo 0)
  else ok=$([ "$health" = healthy ] && echo 1 || echo 0); fi
  [ "$ok" = 1 ] && echo "ok    $svc" || { echo "FAIL  $svc ($state/$health)"; fail=1; }
done < <($DC ps -a --format '{{.Service}}\t{{.State}}\t{{.Health}}')
for r in "crm.localhost /healthz" "flows.localhost /healthz" "mail.localhost /"; do
  set -- $r
  code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' -H "Host: $1" "http://127.0.0.1:$PORT$2")
  [ "$code" = 200 ] && echo "ok    route $1$2" || { echo "FAIL  route $1$2 ($code)"; fail=1; }
done
exit $fail
