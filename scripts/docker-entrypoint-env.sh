#!/bin/sh
set -eu

ENV_FILE=/run/chatvardage/.env
if [ ! -f "$ENV_FILE" ]; then
  echo "Erreur: $ENV_FILE absent; le service generer-env doit terminer avant ce service." >&2
  exit 1
fi
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

case "${1:-}" in
  postgres)
    export POSTGRES_USER="$POSTGRES_SUPERUSER"
    export POSTGRES_PASSWORD="$POSTGRES_SUPERPASS"
    export POSTGRES_DB=postgres
    exec docker-entrypoint.sh postgres
    ;;
  redis)
    exec redis-server --appendonly yes --requirepass "$REDIS_PASSWORD"
    ;;
  auth)
    export DATABASE_URL="postgresql://${AUTH_DB_USER}:${AUTH_DB_PASSWORD}@postgres:5432/${AUTH_DB}"
    exec sh -c 'node node_modules/prisma/build/index.js migrate deploy && exec ./chatvardage-auth'
    ;;
  room)
    export DATABASE_URL="postgresql://${ROOMS_DB_USER}:${ROOMS_DB_PASSWORD}@postgres:5432/${ROOMS_DB}?schema=public"
    exec sh -c 'node node_modules/prisma/build/index.js migrate deploy && exec node dist/main'
    ;;
  message)
    export DATABASE_URL="postgresql://${MESSAGES_DB_USER}:${MESSAGES_DB_PASSWORD}@postgres:5432/${MESSAGES_DB}?schema=public"
    export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379"
    exec sh -c 'node node_modules/prisma/build/index.js migrate deploy && exec node dist/main.js'
    ;;
  user-config)
    export DATABASE_URL="postgresql://${CONFIG_DB_USER}:${CONFIG_DB_PASSWORD}@postgres:5432/${CONFIG_DB}?schema=public"
    exec sh -c 'node node_modules/prisma/build/index.js migrate deploy && exec node dist/main'
    ;;
  dashboard)
    export COOKIE_SECRET="$DASHBOARD_COOKIE_SECRET"
    export SESSION_SECRET="$DASHBOARD_SESSION_SECRET"
    exec node dist/main.js
    ;;
  serveur-api)
    exec node dist/main
    ;;
  *)
    echo "Usage: $0 {postgres|redis|auth|room|message|user-config|dashboard|serveur-api}" >&2
    exit 2
    ;;
esac
