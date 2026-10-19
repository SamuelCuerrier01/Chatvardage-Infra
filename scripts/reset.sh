#!/bin/sh

set -eu

cd "$(dirname "$0")/.."

force=0

for arg in "$@"; do
  case "$arg" in
    -y|--force)
      force=1
      ;;
    -h|--help)
      echo "Usage : $0 [-y|--force]"
      exit 0
      ;;
    *)
      echo "Option inconnue : $arg" >&2
      echo "Usage : $0 [-y|--force]" >&2
      exit 2
      ;;
  esac
done

if [ "$force" -ne 1 ]; then
  if [ ! -t 0 ]; then
    echo "Entrée non interactive : relancer avec -y/--force pour confirmer la suppression des volumes." >&2
    exit 1
  fi

  printf 'ATTENTION : cette commande va supprimer tous les volumes Docker et donc les données locales.\n'
  printf 'Continuer ? [y/N] '

  read -r ans

  case "$ans" in
    [yY])
      ;;
    *)
      echo "Annulé."
      exit 0
      ;;
  esac
fi

docker compose down -v --remove-orphans

if ! docker compose up -d --build; then
  echo "Échec du redémarrage : les volumes ont été supprimés mais la stack n'est pas relancée." >&2
  echo "Consulter 'docker compose logs' puis relancer 'docker compose up -d --build'." >&2
  exit 1
fi

echo "Environnement réinitialisé avec succès."
