#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
INFRA_DIR=$(dirname "$SCRIPT_DIR")
SOURCE="$INFRA_DIR/.env"
RUNTIME="$INFRA_DIR/.runtime-env"
[ -f "$SOURCE" ] || { echo 'Erreur: .env absent.' >&2; exit 1; }
umask 077
mkdir -p "$RUNTIME"
chmod 700 "$RUNTIME"

preparer() {
  service=$1
  cles=$2
  mkdir -p "$RUNTIME/$service"
  chmod 755 "$RUNTIME/$service"
  temporaire="$RUNTIME/$service/.env.tmp"
  awk -F= -v cles="$cles" '
    BEGIN { n = split(cles, noms, " "); for (i = 1; i <= n; i++) permis[noms[i]] = 1 }
    permis[$1] { sub(/\r$/, ""); print }
  ' "$SOURCE" > "$temporaire"
  chmod 644 "$temporaire"
  mv "$temporaire" "$RUNTIME/$service/.env"
}

commun='CORS_ORIGINS'
preparer postgres 'POSTGRES_SUPERUSER POSTGRES_SUPERPASS AUTH_DB AUTH_DB_USER AUTH_DB_PASSWORD ROOMS_DB ROOMS_DB_USER ROOMS_DB_PASSWORD MESSAGES_DB MESSAGES_DB_USER MESSAGES_DB_PASSWORD CONFIG_DB CONFIG_DB_USER CONFIG_DB_PASSWORD'
preparer redis 'REDIS_PASSWORD'
preparer auth "$commun AUTH_DB AUTH_DB_USER AUTH_DB_PASSWORD JWT_SECRET JWT_DUREE_DE_VIE_HEURES RUST_LOG INTERNAL_SERVICE_TOKEN"
preparer room "$commun ROOMS_DB ROOMS_DB_USER ROOMS_DB_PASSWORD INTERNAL_SERVICE_TOKEN AUTH_SERVICE_URL AUTH_SERVICE_TIMEOUT_MS AUTH_CACHE_TTL_MS MESSAGE_SERVICE_URL"
preparer message "$commun MESSAGES_DB MESSAGES_DB_USER MESSAGES_DB_PASSWORD REDIS_PASSWORD INTERNAL_SERVICE_TOKEN AUTH_SERVICE_URL AUTH_SERVICE_TIMEOUT_MS AUTH_CACHE_TTL_MS ROOM_SERVICE_URL ROOM_SERVICE_TIMEOUT_MS ROOM_ACCESS_CACHE_TTL_MS"
preparer user-config "$commun CONFIG_DB CONFIG_DB_USER CONFIG_DB_PASSWORD INTERNAL_SERVICE_TOKEN"
preparer dashboard "$commun DASHBOARD_COOKIE_SECRET DASHBOARD_SESSION_SECRET AUTH_SERVICE_URL ROOM_SERVICE_URL MESSAGE_SERVICE_URL"
preparer serveur-api "$commun INTERNAL_SERVICE_TOKEN AUTH_SERVICE_URL ROOM_SERVICE_URL MESSAGE_SERVICE_URL USER_CONFIG_SERVICE_URL PROXY_TIMEOUT_MS MAX_PROXY_BODY_BYTES AUTH_RATE_LIMIT_WINDOW_MS AUTH_RATE_LIMIT_MAX TRUST_PROXY AUTH_CACHE_TTL_MS"

chmod 600 "$SOURCE"
if [ "$(id -u)" = 0 ]; then
  chown "${LOCAL_UID:-1000}:${LOCAL_GID:-1000}" "$SOURCE"
  chown -R "${LOCAL_UID:-1000}:${LOCAL_GID:-1000}" "$RUNTIME"
fi
echo 'OK: environnements séparés par service; secrets existants conservés.'
