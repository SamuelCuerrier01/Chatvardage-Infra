#!/bin/sh
set -eu

infra_only=0
for arg in "$@"; do
  case "$arg" in
    --infra) infra_only=1 ;;
    -h|--help) echo "Usage : $0 [--infra]"; exit 0 ;;
    *) echo "Option inconnue : $arg" >&2; echo "Usage : $0 [--infra]" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.."

if [ "$infra_only" -eq 1 ]; then
  required_services="postgres redis"
else
  required_services="postgres redis auth-service room-service message-service user-config-service dashboard serveur-api"
fi

failed=0
for service in $required_services; do
  if ! container_id=$(docker compose ps -q "$service" | head -n 1); then
    echo "$service : impossible de lire l'état" >&2
    failed=1
    continue
  fi
  if [ -z "$container_id" ]; then
    echo "$service : non démarré" >&2
    failed=1
    continue
  fi
  if ! status=$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}sans-healthcheck{{end}}' "$container_id"); then
    echo "$service : inspection impossible" >&2
    failed=1
    continue
  fi
  echo "$service : $status"
  if [ "$status" != "running healthy" ]; then
    failed=1
  fi
done
if [ "$failed" -ne 0 ]; then
  echo "Au moins un service requis n'est pas running/healthy." >&2
  exit 1
fi

echo "== PostgreSQL =="
if ! docker compose exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d postgres'; then
  echo "PostgreSQL n'est pas prêt." >&2
  exit 1
fi

echo "== Databases =="
if ! docker compose exec -T postgres sh -c '
set -eu
actual=$(psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -Atc "SELECT datname FROM pg_database ORDER BY datname;")
for db in "$AUTH_DB" "$ROOMS_DB" "$MESSAGES_DB" "$CONFIG_DB"; do
  if ! printf "%s\n" "$actual" | grep -Fxq "$db"; then
    echo "$db : absente" >&2
    exit 1
  fi
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$db" -Atc "SELECT 1" >/dev/null
  echo "$db : présente et accessible"
done
'; then
  echo "Une base configurée est absente, inaccessible, ou PostgreSQL a refusé la requête." >&2
  exit 1
fi

echo "== Redis =="
if ! redis_reply=$(docker compose exec -T redis sh -c \
  'set -a; . /run/chatvardage/.env; set +a; REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'); then
  echo "Impossible d'interroger Redis." >&2
  exit 1
fi
echo "$redis_reply"
if [ "$redis_reply" != "PONG" ]; then
  echo "Redis ne répond pas exactement PONG." >&2
  exit 1
fi

if [ "$infra_only" -eq 1 ]; then
  echo "Infrastructure OK"
  exit 0
fi

echo "== Dashboard =="
if ! docker compose exec -T dashboard node -e "
const signal = AbortSignal.timeout(5000);
fetch('http://localhost:3000/administration', { signal })
  .then((r) => process.exit(r.ok ? 0 : 1))
  .catch((e) => { console.error(e.message); process.exit(1); });
"; then
  echo "Le Dashboard ne répond pas correctement." >&2
  exit 1
fi

echo "== Gateway (upstreams) =="
if ! docker compose exec -T serveur-api node -e "
const signal = AbortSignal.timeout(5000);
fetch('http://localhost:3000/api/health/upstreams', { signal })
  .then(async (r) => {
    if (!r.ok) process.exit(1);
    let body;
    try { body = await r.json(); } catch { process.exit(1); }
    const u = body && body.upstreams;
    const ok = body?.status === 'ok' && body?.service === 'serveur-api' && u &&
      u.auth === 'ok' && u.room === 'ok' && u.message === 'ok' && u.userConfig === 'ok';
    if (!ok) console.error(JSON.stringify(body));
    process.exit(ok ? 0 : 1);
  })
  .catch((e) => { console.error(e.message); process.exit(1); });
"; then
  echo "Le Gateway signale un état invalide ou un upstream indisponible." >&2
  exit 1
fi

echo "Stack OK"
