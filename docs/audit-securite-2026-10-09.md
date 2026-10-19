# Audit de sécurité — 9 octobre 2026

## Périmètre et conclusion

Revue des neuf dépôts locaux, des frontières Auth/Gateway/Room/Message/User-Config, des clients Electron et Expo, du Dashboard, des dépendances npm/Cargo, des images Docker, des secrets et de l'orchestration. Les correctifs ci-dessous sont vérifiés localement. Ce rapport ne certifie pas l'absence de toute vulnérabilité.

Le serveur, l'hébergeur et les domaines de production ne sont pas encore choisis. Aucun audit de SSH, pare-feu réel, TLS public, DNS, sauvegardes ou infrastructure distante n'a donc été effectué. Compose reste destiné au développement; une configuration de production doit être définie avant ouverture publique. Des audits restent en échec à cause d'avis sans correctif compatible; ils ne sont ni supprimés ni abaissés.

Les compteurs détaillés, avis directs et identifiants des images sont dans [le résultat JSON](audits/2026-10-09.json). Les compteurs npm comprennent les paquets dépendants : 49 paquets affectés ne représentent pas 49 failles distinctes. Les bases d'avis npm, RustSec et Trivy n'ont pas la même couverture.

## Problèmes corrigés

| Problème | Impact et correction | Vérification |
|---|---|---|
| Tous les conteneurs pouvaient lire le `.env` complet via le montage Infra | Une compromission de Gateway/Dashboard donnait accès aux secrets JWT et aux mots de passe de toutes les bases. Chaque service voit désormais uniquement son fichier dérivé et le script d'entrée en lecture seule. `.env` est privé, sans rotation de secrets existants. | Tests de séparation des secrets, bootstrap réel et migrations sur volumes isolés. |
| API publiée par défaut sur toutes les interfaces | Le poste pouvait exposer HTTP et ses identifiants sur le réseau. Liaison `127.0.0.1` par défaut; `API_BIND_ADDRESS` permet une ouverture explicite. | Configuration Compose et test du port publié. |
| Vérification fraîche Auth réutilisant une requête antérieure | Room/Message pouvaient réutiliser une validation commencée avant une révocation. La requête en cours est invalidée; sa réponse ne peut remplir le cache ni effacer une requête plus récente. | Régression avec ancienne réponse 200, nouvelle réponse 401 et contrôle du cache. Fichiers identiques dans les deux dépôts. |
| Calculs Argon2 sans borne globale | Des IP multiples pouvaient multiplier les calculs coûteux. Quatre calculs simultanés par instance, attente maximale de cinq secondes puis 503; permis conservé dans la tâche CPU après annulation du client. | Tests du sémaphore, des délais et de sa fermeture; suite Rust avec PostgreSQL réel. |
| Compteurs du limiteur Gateway non bornés | De nombreuses adresses pouvaient remplir la mémoire. Maximum 10 000 fenêtres; nettoyage des expirées puis refus 429 sans éviction des fenêtres actives. | Tests de capacité, de réutilisation et d'expiration. |
| Connexion Dashboard sans limite propre | Dix tentatives par minute et par adresse, compteurs bornés, HTTP 429 et Retry-After. Cookie HTTPS obligatoire hors dev/test, durée de trente minutes. | Tests de middleware/cookies et onzième tentative HTTP réellement refusée. |
| Jeton Electron persisté en clair sans chiffrement | Suppression du repli en clair et refus de `safeStorage` Linux `basic_text`. Sans coffre, session en mémoire; ancien fichier supprimé ou migré seulement avec un coffre réel. | Régressions de chiffrement absent, backend non sécurisé, migration et erreurs de fichier. |
| Clients configurables avec HTTP distant | Electron exige HTTPS hors développement; Mobile exige une origine HTTPS explicite en release. Refus des identifiants, chemins, paramètres et fragments. Socket utilise l'origine API par défaut. | Tests des origines et de la configuration release. |
| Divergences des hooks partagés | Synchronisation Electron/Mobile, annulation de la pagination remplacée et déduplication intra-page; conservation de l'alias de compteur au démontage. | Couverture 100 % des clients et vérification des fichiers partagés. |
| Dépendances et outils embarqués vulnérables | Mises à jour compatibles, Handlebars corrigé, YAML de l'outil de couverture isolé via override, liens Tiptap et backend i18next corrigés. npm/npx supprimés des images finales; migrations par CLI Prisma local. Binaire esbuild supprimé du Dashboard précompilé, wrappers conservés pour les imports statiques AdminJS. | Installations propres, tests/builds, génération du bundle et démarrage réel du Dashboard. |
| Images système anciennes | Adminer 4.8.1 remplacé par 6.1.1. Images Infra appliquant les mises à jour Alpine. Auth passe son runtime à Node 22/Trixie avec mises à jour Debian et remplace curl par le contrôle HTTP Node. PostgreSQL reste en version majeure 17, Redis en 7.4. | Rebuild avec pull, migrations/démarrage et scans des images finales. |

## Audits des dépendances

| Dépôt | npm avant | npm après | État du seuil high |
|---|---:|---:|---|
| Authentification | 0 | 0 | Passe |
| Dashboard | 78 (1 critique, 36 élevées) | 71 (36 élevées, 35 modérées) | Échoue : braces |
| Frontend | 8 modérées | 8 modérées | Passe |
| Infra | 0 | 0 | Pas de package applicatif npm; lockfile vide |
| Message-Service | 21 (1 critique) | 0 | Passe |
| Mobile | 54 (49 élevées) | 49 élevées | Échoue : braces et node-forge |
| Room-Service | 21 (1 critique) | 0 | Passe |
| Serveur-API | 21 (1 critique) | 0 | Passe |
| User-Config-Service | 20 (1 critique) | 0 | Passe |

Les mises à jour forcées proposées par npm rétrogradent parfois Jest, AdminJS ou Expo et ne constituent pas une correction compatible. Aucun `audit fix --force` n'a été utilisé. Expo reste aligné sur le SDK 57, contrôlé avec `expo install --check`.

Exceptions restantes :

- [braces GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm), gravité élevée : pas de version corrigée publiée au moment de l'audit; présent dans les chaînes Dashboard et Metro/Jest. Éviter les motifs de compilation non fiables. Réexaminer dès publication d'un correctif compatible.
- [node-forge GHSA-86w9-cpqp-85rv](https://github.com/advisories/GHSA-86w9-cpqp-85rv), gravité élevée : pas de correctif publié pour l'avis RSA signalé, via les outils Expo. Ne pas considérer les validations cryptographiques concernées comme sûres; réexaminer la chaîne Expo dès correction amont.
- [Tiptap core GHSA-cp6q-959q-f8rh](https://github.com/advisories/GHSA-cp6q-959q-f8rh), modérée : correction en 3.30.4+, alors qu'AdminJS utilise Tiptap 2. Une substitution isolée de core casserait ses extensions. Les ressources actuelles n'importent pas d'attributs de documents riches non fiables. Toute activation d'un éditeur/import nécessite d'abord une migration cohérente de la chaîne AdminJS/Tiptap. L'avis distinct sur extension-link est corrigé dans la version 2 compatible.
- Frontend : `sprintf-js` via electron-builder/global-agent/roarr, huit alertes modérées de la chaîne d'outillage; pas de modification forcée du packager.
- Cargo : l'audit configuré passe. Sans exclusion, il signale `RUSTSEC-2023-0071` sur `rsa 0.9.10`, présent dans les métadonnées SQLx/MySQL du lockfile. `cargo tree -e normal` confirme son absence du graphe compilé de ce service PostgreSQL. L'exclusion existante doit être revue si MySQL/RSA est activé.

## Images finales — Trivy 0.75.0

| Service/image | Critiques | Élevées | Modérées | Remarque |
|---|---:|---:|---:|---|
| Auth (bilan initial; voir actualisation en fin de document) | 0 | 43 | 58 | Alertes Debian Trixie sans version corrigée disponible dans le scan; détail par paquet/CVE dans le JSON. |
| PostgreSQL | 1 | 21 | 22 | Alertes Go du binaire gosu; aucune alerte élevée/critique Alpine restante. |
| Redis | 0 | 0 | 0 | Image corrigée. |
| Adminer | 0 | 0 | 0 | Ancienne image : 78 critiques et 274 élevées; nouvelle image corrigée. |
| Dashboard | 0 | 0 | 3 | Le résultat npm reste distinct et conserve ses avis braces/Tiptap. |
| Room, Message, User-Config, Gateway (chacun) | 0 | 0 | 1 | Une alerte modérée par image. |
| Bootstrap alpine:3.22 | 0 | 0 | 1 | Service temporaire, terminé avant le runtime. |

Pour PostgreSQL, les alertes de bibliothèque Go ne démontrent pas que les fonctions vulnérables sont atteignables dans gosu. Le [mainteneur décrit les exclusions et le contrôle govulncheck](https://github.com/tianon/gosu/blob/master/SECURITY.md). Les alertes brutes sont conservées : aucun filtre global ne les masque et la validation de chaque chemin reste à compléter avant d'exiger un résultat scanner nul. Auth conserve des avis système réellement signalés sans patch disponible; une future mise à jour de distribution/image doit être rescannée. Il serait incorrect d'annoncer « zéro vulnérabilité » pour l'ensemble des images.

## Validation réalisée

- npm ci, audits, lint, builds et suites de couverture des services; Room/User-Config/Gateway : tests E2E. Les quatre services NestJS atteignent les seuils 100 %; Dashboard dépasse ses seuils 90 % (82 tests).
- Frontend : lint, types, build et 400 tests, couverture 100 %. Mobile : lint, types, 1 044 tests, couverture 100 %, alignement Expo validé. Aucun artefact mobile de diffusion n'est construit sans domaine HTTPS de production.
- Auth : fmt, clippy sans avertissement, tests avec PostgreSQL migré, couverture des lignes 99,77 % hors main, build release et audits npm/Cargo configurés.
- Infra : 73 tests, ShellCheck, syntaxe shell, configuration Compose et comparaison de tous les fichiers partagés.
- Construction des neuf images concernées et démarrage isolé : tous les services essentiels healthy, Adminer prêt, quatre bases accessibles, Redis PONG, Dashboard et health/upstreams Gateway valides.
- Contrôles HTTP réels : Room/Message sans JWT refusés; User-Config et Gateway avec identité forgée refusés; utilisateur ordinaire refusé sur l'administration Auth; compte de test supprimé avec confirmation du mot de passe; son JWT refusé ensuite par Auth et Room; onzième connexion Dashboard refusée.

Les essais utilisent le projet Docker `chatvardage-security-review` avec volumes temporaires et sans ports publics. La stack courante et ses volumes n'ont pas été arrêtés ni supprimés. Les logs techniques restent dans `.security-results` à la racine locale de travail; le résultat JSON versionné ne contient pas les secrets générés.

## Conditions avant ouverture publique

1. Définir hôte, domaine, reverse proxy et certificats, puis auditer TLS et les ports depuis l'extérieur. Seuls les points d'entrée HTTPS nécessaires doivent être publics; PostgreSQL/Redis/services internes/Adminer/Dashboard restent filtrés.
2. Définir un Compose de production : NODE_ENV=production, CORS exact, aucun secret de démonstration, stockage des secrets protégé et confiance proxy explicite. Room/Message exigent actuellement une URL Auth HTTPS en production; les URLs HTTP internes du Compose de développement ne satisfont pas ce contrat. Prévoir TLS interne ou une terminaison contrôlée compatible et testée.
3. Prévoir sauvegardes PostgreSQL/Redis et tester leur restauration, protéger les volumes, configurer SSH/pare-feu/mises à jour de l'hôte, surveiller erreurs et saturation. Aucun de ces contrôles distants n'a pu être réalisé ici.
4. Examiner les exceptions npm et système ci-dessus, rescanner au moment du déploiement. Les audits high bloqués ne sont pas considérés comme passants. La limitation par instance doit être partagée en cas de plusieurs réplicas; les caches Auth ordinaires gardent leur fenêtre de dix secondes configurée, tandis que les vérifications explicitement fraîches contournent le cache.

## Remise en service ciblée

Depuis Infra, utiliser les commandes documentées dans le README : bootstrap des fichiers dérivés, build --pull des neuf services affectés, up --wait en respectant les dépendances puis healthcheck. Aucun down ni retrait des volumes n'est requis. Les clients Electron/Mobile doivent être reconstruits et distribués séparément avec leur configuration HTTPS définitive.

## Image Auth Alpine (rescan)

La ligne Auth/Trivy du tableau initial concerne l'ancienne image Debian. L'image actuelle compile Rust avec musl et tourne sur Node 22 Alpine sous l'utilisateur `node`, sans npm ni npx ; elle applique les migrations par `./node_modules/.bin/prisma migrate deploy`.

| Outil | Résultat (9 octobre 2026) |
|---|---|
| Docker Scout, sans filtre | 64 paquets indexés, aucune vulnérabilité |
| Trivy 0.75.0, base actualisée le même jour | 0 critique, 0 élevée, 0 modérée, 0 faible |

Les deux outils n'ont pas la même base : leurs totaux ne se comparent pas directement. Migrations, santé, refus sans JWT et exécution sans root ont été vérifiés sur un conteneur et une base de test isolés. La couverture Rust est de 99,75 % des lignes hors `main.rs`, pour un seuil de 99 %.
