#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
INFRA_DIR=$(dirname "$SCRIPT_DIR")
TEMPLATE="$INFRA_DIR/.env.example"
TARGET="$INFRA_DIR/.env"
FORCE=0

if [ "$#" -eq 1 ] && [ "${1:-}" = "--force" ]; then
  FORCE=1
elif [ "$#" -gt 0 ]; then
  echo "Usage: $0 [--force]" >&2
  exit 2
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "Erreur: openssl est requis pour générer des secrets cryptographiquement sûrs." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "Erreur: modèle introuvable: $TEMPLATE" >&2
  exit 1
fi

if [ -e "$TARGET" ] && [ "$FORCE" -ne 1 ]; then
  echo "Erreur: $TARGET existe déjà. Utilisez --force pour le remplacer." >&2
  exit 1
fi

secret() {
  openssl rand -hex 32
}

POSTGRES_SUPERPASS_VALUE=$(secret)
AUTH_DB_PASSWORD_VALUE=$(secret)
ROOMS_DB_PASSWORD_VALUE=$(secret)
MESSAGES_DB_PASSWORD_VALUE=$(secret)
CONFIG_DB_PASSWORD_VALUE=$(secret)
REDIS_PASSWORD_VALUE=$(secret)
JWT_SECRET_VALUE=$(secret)
INTERNAL_SERVICE_TOKEN_VALUE=$(secret)
DASHBOARD_COOKIE_SECRET_VALUE=$(secret)
DASHBOARD_SESSION_SECRET_VALUE=$(secret)

umask 077
TMP="$TARGET.tmp.$$"
trap 'rm -f "$TMP"' EXIT HUP INT TERM

seen=""
while IFS= read -r line || [ -n "$line" ]; do
  line=$(printf '%s' "$line" | tr -d '\r')
  case "$line" in
    POSTGRES_SUPERPASS=*) echo "POSTGRES_SUPERPASS=$POSTGRES_SUPERPASS_VALUE"; seen="$seen POSTGRES_SUPERPASS" ;;
    AUTH_DB_PASSWORD=*) echo "AUTH_DB_PASSWORD=$AUTH_DB_PASSWORD_VALUE"; seen="$seen AUTH_DB_PASSWORD" ;;
    ROOMS_DB_PASSWORD=*) echo "ROOMS_DB_PASSWORD=$ROOMS_DB_PASSWORD_VALUE"; seen="$seen ROOMS_DB_PASSWORD" ;;
    MESSAGES_DB_PASSWORD=*) echo "MESSAGES_DB_PASSWORD=$MESSAGES_DB_PASSWORD_VALUE"; seen="$seen MESSAGES_DB_PASSWORD" ;;
    CONFIG_DB_PASSWORD=*) echo "CONFIG_DB_PASSWORD=$CONFIG_DB_PASSWORD_VALUE"; seen="$seen CONFIG_DB_PASSWORD" ;;
    REDIS_PASSWORD=*) echo "REDIS_PASSWORD=$REDIS_PASSWORD_VALUE"; seen="$seen REDIS_PASSWORD" ;;
    JWT_SECRET=*) echo "JWT_SECRET=$JWT_SECRET_VALUE"; seen="$seen JWT_SECRET" ;;
    INTERNAL_SERVICE_TOKEN=*) echo "INTERNAL_SERVICE_TOKEN=$INTERNAL_SERVICE_TOKEN_VALUE"; seen="$seen INTERNAL_SERVICE_TOKEN" ;;
    DASHBOARD_COOKIE_SECRET=*) echo "DASHBOARD_COOKIE_SECRET=$DASHBOARD_COOKIE_SECRET_VALUE"; seen="$seen DASHBOARD_COOKIE_SECRET" ;;
    DASHBOARD_SESSION_SECRET=*) echo "DASHBOARD_SESSION_SECRET=$DASHBOARD_SESSION_SECRET_VALUE"; seen="$seen DASHBOARD_SESSION_SECRET" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$TEMPLATE" > "$TMP"

for name in POSTGRES_SUPERPASS AUTH_DB_PASSWORD ROOMS_DB_PASSWORD MESSAGES_DB_PASSWORD CONFIG_DB_PASSWORD REDIS_PASSWORD JWT_SECRET INTERNAL_SERVICE_TOKEN DASHBOARD_COOKIE_SECRET DASHBOARD_SESSION_SECRET; do
  case " $seen " in
    *" $name "*) ;;
    *) echo "Erreur: clé manquante dans le template : $name" >&2; exit 1 ;;
  esac
done

mv "$TMP" "$TARGET"
trap - EXIT HUP INT TERM

echo "OK: .env créé avec des secrets aléatoires distincts."
echo "Fichier: $TARGET"
echo "Ne jamais committer ni partager ce fichier."
