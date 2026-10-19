# AGENTS.md — A26_5A6_01-Infra

## Mission
Orchestrer l'environnement Chatvardage. Ce dépôt ne contient aucune logique métier et **ne possède aucun schéma métier**.

## Responsabilités d'Infra
- lancer PostgreSQL et Redis ;
- créer les quatre bases logiques et leurs utilisateurs/propriétaires SQL ;
- gérer réseaux, volumes, variables d'environnement et healthchecks ;
- fournir le Docker Compose racine et les scripts de santé/reset ;
- documenter l'orchestration, l'architecture, les contrats et les scénarios de validation de toute la plateforme (Electron, mobile, services).

## Règle impérative : propriété des schémas
Ne jamais créer dans `postgres/init` les tables métier, index métier ou données métier des services.
- Authentification possède ses tables/migrations.
- Room-Service possède serveurs/salons/membres/invitations et ses migrations Prisma.
- Message-Service possède messages, état de lecture et ses migrations.
- User-Config-Service possède configurations et ses migrations.

`postgres/init/00-create-databases.sh` peut créer les **bases, rôles et propriétaires**, rien de plus.

## Redis
Redis sert au transport temps réel et ne remplace jamais PostgreSQL. Le temps réel des messages appartient à Message-Service.

## Code et scripts
- Pas de commentaires dans les scripts, le Compose ni les Dockerfiles. Les explications vont dans le README, `docs/` ou ce fichier. Seules restent les directives d'outils (`# shellcheck disable=…`).
- Le projet Compose s'appelle `chatvardage` ; les volumes gardent leur nom explicite `chatvardage-c2_*` pour conserver les données des postes existants. Ne pas les renommer sans procédure de migration.

## Validation obligatoire avant PR
```bash
docker compose config -q
docker compose up -d --build --wait --wait-timeout 240
docker compose ps
./scripts/healthcheck.sh
./scripts/verifier-fichiers-partages.sh
docker compose logs --no-color --tail=100 postgres redis
```
`./scripts/healthcheck.sh` vérifie les 8 services essentiels (PostgreSQL, Redis, Auth, Room, Message, User-Config, Dashboard et Serveur-API), les quatre bases (présence et connexion), Redis, le Dashboard et `/api/health/upstreams`. `--infra` se limite à PostgreSQL, Redis et aux bases.

Après une modification d'initialisation PostgreSQL, valider sur un volume neuf dans une stack isolée (voir `docs/validation.md`) : `docker compose down -v` efface les données de travail. Valider au moins une migration réelle d'un microservice contre une base neuve.

Ne jamais déclarer la PR prête si une commande requise échoue.

## Variables et sécurité
- `.env` ne doit jamais être commité. `.env.example` contient seulement des valeurs de développement ; `generer-env` crée `.env` avec des secrets aléatoires au premier `docker compose up`.
- Un service utilise uniquement le compte SQL de sa propre base.
- Tout port publié dans `docker-compose.yml` est lié à `127.0.0.1` (ou à `API_BIND_ADDRESS` pour le Gateway), jamais à toutes les interfaces par défaut.
- Les origines CORS viennent d'une seule variable, `CORS_ORIGINS`, lue sous ce nom par tous les services, Auth compris.
- Les services runtime ne montent que leur `.runtime-env/<service>` en lecture seule et le script d'entrée ; seul le bootstrap voit le `.env` principal.

## Documentation centrale
Infra est la référence du démarrage complet, des architectures, contrats et scénarios de validation. Toute modification de contrat met à jour la référence centrale (`docs/api/`, `docs/services/`) et ses liens. Le diagramme `docs/architecture.svg` est la source de `docs/architecture.png` : régénérer le PNG après toute modification du SVG.

## Choix délibérés (ne pas « corriger »)

Secrets et Dashboard :
- **`DASHBOARD_SESSION_SECRET` reste vide dans `.env.example`** : `generer-env` le remplace par une valeur aléatoire ; le Dashboard en génère une en développement et refuse une valeur absente ou trop courte en production. Le CI valide Compose avec un secret temporaire (`openssl rand -hex 32`) ; ne jamais ajouter de valeur fixe au modèle pour le faire passer.
- **Pas de `USER_CONFIG_SESSION_SECRET` ni de secret de session partagé** : User-Config ne consomme pas `SESSION_SECRET`, son identité vient de `x-user-id` protégé par `INTERNAL_SERVICE_TOKEN`.
- **Le repli `DASHBOARD_COOKIE_SECRET` est un marqueur de développement**, remplacé par un secret aléatoire en développement/test et rejeté explicitement ailleurs.

Images et bootstrap :
- **`USER root` des images PostgreSQL/Redis conservé** : leurs entrypoints préparent les volumes puis abaissent les privilèges. Adminer se termine par `USER www-data`.
- **CLI Prisma appelé directement** (`node_modules/.bin/prisma` ou `build/index.js` de la version verrouillée) : npm/npx sont absents des images finales.
- **Bootstrap root puis opérateur** : les dérivés appartiennent à `LOCAL_UID:LOCAL_GID` ; modes 0755/0644 pour les dérivés (les UID des services ne coïncident pas avec l'opérateur), parent hôte en 0700, fichier source en 0600.
- **Gosu de l'image PostgreSQL** : limite amont documentée dans le rapport d'audit ; ne pas remplacer ce binaire à la main. `build --pull` puis rescan lors des mises à jour.
- **`.gitattributes` impose LF** aux fichiers texte et aux scripts shell.
- **URL de révocation Message-Service dans Compose** : elle décrit le service du réseau interne ; un deuxième réplica demanderait une revue d'architecture.
- **Format `CLÉ=valeur`** (sans `export` ni espace avant la clé) pour les fichiers d'environnement générés ; pas d'autre grammaire.

Documentation des contrats :
- **État de lecture d'un DM** : pas d'autorisation supplémentaire ; `lecteurDm` ne consulte que l'état de l'interlocuteur dont `targetId` est l'appelant.
- **Recherche** : pas de limite de fréquence spécifique (limite connue, documentée dans Message-Service). Aucun index ni schéma métier dans Infra.
- **« Vu par » au-delà de 100 lecteurs** : l'API renvoie au plus 100 lecteurs récents sans total ; afficher un nombre d'autres lecteurs inventerait une information.
- **Interlocuteur inexistant** : état vide, pas de 404 inventé ; 400 concerne un `messageId` hors conversation.
- **Couverture Auth** : seuil de 99 % ; aucun test artificiel pour combler l'écart restant.
- **`logout-others`** : un 401 reste possible après invalidation si le compte disparaît avant la relecture (`AuthService::deconnecter_autres`).

- **Prérequis AppArmor du job de revue** : le profil provient du paquet installé sur Ubuntu 24.04 et son chargement est vérifié avant toute restauration des identifiants. Un profil manquant doit faire échouer le job ; continuer sans lui affaiblirait l’isolation pour une panne amont hypothétique.
- **Revues sur dépôt public** : Codex doit prendre le relais pour les PR internes après échec de Copilot. Les forks restent exclus et les secrets restent dans l’environnement dédié ; une approbation manuelle systématique n’est pas imposée, car elle bloquerait le suivi automatique demandé.
