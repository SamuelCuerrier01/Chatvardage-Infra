# Rapport de validation

Vérifications automatisées refaites le 20 octobre 2026 sur le code publié pour Mobile, Serveur-API et Message-Service, le 19 octobre 2026 pour Frontend, le 18 octobre 2026 pour les autres dépôts ; validation de la stack intégrée du 1er octobre 2026. Les résultats ci-dessous distinguent les vérifications exécutées des éléments restant à démontrer.

## Vérifications automatisées

| Application | Résultat |
|---|---|
| Mobile | 1111 tests (98 suites) ; couverture de 100 % ; types et lint réussis ; bundle Android exporté ; parcours `test:integration` (19 vérifications) réussi contre la stack locale |
| Frontend | 481 tests ; couverture de 100 % sur le périmètre configuré ; types et lint réussis |
| Dashboard | 83 tests ; couverture de 99,7 % (lignes) ; types et lint réussis |
| Authentification | 185 tests sur une base PostgreSQL migrée ; format et Clippy réussis |
| Room-Service | 205 tests unitaires et 14 tests e2e ; couverture de 100 % |
| Message-Service | 403 tests unitaires ; couverture de 100 % |
| User-Config-Service | 83 tests unitaires et 24 tests e2e ; couverture de 100 % |
| Serveur-API | 137 tests unitaires et 8 tests e2e ; couverture de 100 % |

Les vérifications npm de compilation et de lint des services passent. Les couvertures reflètent les exclusions et seuils de chaque dépôt; elles ne signifient pas que toutes les interactions système sont couvertes. Le test des notifications exécute le module principal avec Electron simulé.

Les sept vérificateurs de versions acceptent le tag correspondant et rejettent un tag incohérent. Les workflows passent actionlint et les cinq scripts shell Infra passent ShellCheck. `npm audit` (dépendances de dev comprises), relancé le 2 octobre 2026, ne signale aucune vulnérabilité dans six des sept dépôts Node (Authentification compris, pour sa CLI Prisma), et aucune de sévérité haute ou critique dans le Dashboard. Le Dashboard garde des avis de sévérité modérée ou faible sur `@tiptap/*` 2.1.13, épinglé par AdminJS et sans correctif compatible ; le bundle précompilé que sert AdminJS au navigateur embarque aussi toujours `tinymce` 6.8.2 (voir le [guide Dashboard](services/Dashboard.md#dépendances-et-audit)). Les CI des dépôts Node exécutent `npm audit --audit-level=high` (à titre informatif pour Mobile, dont les avis viennent du SDK Expo). L’audit Message-Service ne signale aucune vulnérabilité, y compris après l’ajout de Swagger (`js-yaml` forcé en 5.4.2 pour `@nestjs/swagger`).

## Stack et intégration réelle

Une stack Docker isolée a été construite depuis les sources avec des volumes vierges, des ports locaux attribués automatiquement et un secret de session temporaire. Les ressources de la stack habituelle sont préservées.

- Swagger de Message-Service servi sur `/docs` (14 routes REST, version 1.0.0), comme ceux de Room et User-Config.
- Construction et démarrage des neuf conteneurs réussis; PostgreSQL, Redis, les services et le Dashboard sont en santé.
- Connexion SQL vérifiée à chacune des quatre bases. Migrations appliquées : Authentification 4, Room 3, Message 3, Configuration 3. La migration Authentification `retirer_role_moderateur_global`, ajoutée ensuite, s’applique au démarrage (5 migrations) et convertit un ancien compte `moderateur` en `utilisateur`; `PATCH /api/users/:id/role` refuse désormais `moderateur` (400).
- Le healthcheck réussit avec la stack complète et échoue lorsque le Dashboard est arrêté; il réussit de nouveau après restauration.
- Deux clients Socket.IO authentifiés reçoivent le même DM; lecture REST, modification et suppression vérifiées.
- Un message envoyé pendant une déconnexion revient dans l’historique REST après reconnexion. Le test de page du desktop vérifie aussi le déclenchement de la relecture et l’affichage du message manqué.
- Historique et configuration conservés après redémarrage de PostgreSQL, Redis et des services.
- Accès administrateur refusé à un utilisateur ordinaire; accès anonyme au Dashboard redirigé vers la connexion.
- L’action réelle AdminJS de création renvoie une erreur pour un courriel déjà utilisé, sans redirection de réussite. Une création valide réussit.
- Suppression d’un utilisateur, d’un salon et d’un message par les actions du Dashboard vérifiée auprès des API; refus des opérations non autorisées vérifié.
- Rôles par serveur, par l’API du Gateway : dans un serveur privé, un simple membre invité ne peut pas créer de salon (403). Nommé modérateur par le propriétaire, il crée, renomme et supprime un salon, mais ne peut ni renommer ni supprimer le serveur (403). Rétrogradé, il perd de nouveau ces droits.
- Pagination des messages du Dashboard : avec 250 DM en base, l’API AdminJS annonce un total de 250 et sert des pages de 10 jusqu’à la 25e (auparavant, seuls les 50 plus récents étaient chargés).

## Parcours mobile sur appareil

Le parcours mobile a été enregistré en vidéo sur deux téléphones Android physiques (Samsung S25 Ultra sous Android 16 et Samsung S9 sous Android 10), dans Expo Go (SDK 57), avec deux comptes et le backend de la stack Infra : connexion, profil, serveurs et salons, rôles et modération, messages privés, compteurs de non-lus, accusés, présence, modification d'un message, recherche et historique, perte puis reprise du réseau. La vidéo et les captures accompagnent la remise et ne sont pas versionnées.

## Portée et vérifications complémentaires

- Vérifier les notifications natives hors focus avec deux fenêtres Electron sur chaque système cible. Les clients réseau automatisés ne remplacent pas cette observation.
- Vérifier les notifications locales du mobile sur Android dans une development build : Expo Go Android ne les charge pas, seuls les badges dans l'application y sont observables.
- Valider les installateurs desktop sur les plateformes supportées. Une compilation locale réussie ne prouve pas leur installation sur chaque système.
- Vérifier les exécutions GitHub Actions après publication des commits et des tags. Les résultats décrits ici proviennent de validations locales.

Le [scénario fonctionnel](validation.md) décrit les manipulations reproductibles; le [guide des versions](versions.md) décrit les règles de publication. Ce rapport consigne un état daté et ne garantit pas les révisions ultérieures.
