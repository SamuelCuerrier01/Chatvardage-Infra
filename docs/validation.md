# Validation fonctionnelle et intégration

## Principe

Une commande réussie est une preuve uniquement pour la révision et l’environnement testés. Les suites unitaires qui simulent Prisma/Redis ne remplacent pas le scénario intégré. Les notifications natives et le rendu Electron doivent être observés sur le poste cible.

## Installation propre, sans effacer les données de travail

Cloner les révisions à valider dans un dossier distinct. Générer une configuration Compose de validation avec un nom de projet différent, des noms de conteneurs/réseaux uniques, des volumes neufs et des ports libres. Le `container_name` et le nom du réseau du Compose racine étant fixes, **`-p` seul ne suffit pas** à isoler deux stacks.

Suivre exactement le README (génération du `.env` incluse), construire les images, attendre les healthchecks, puis contrôler :

```bash
docker compose config -q
docker compose up --build -d --wait --wait-timeout 240
docker compose ps
./scripts/healthcheck.sh
docker compose logs --no-color --tail=100 postgres redis
```

Vérifier les migrations sur les quatre bases neuves. Redémarrer sans supprimer les volumes et confirmer la conservation des données. Supprimer uniquement les volumes de validation après les essais. Ne jamais utiliser `down -v` sur la stack de travail pour ce contrôle.

## Scénario fonctionnel

| Étape | Manipulation | Résultat attendu |
|---|---|---|
| 1 | Démarrer la stack depuis les README | Tous les services requis sains, quatre bases accessibles, Redis PONG |
| 2 | Ouvrir deux profils Electron; créer A et B | Comptes distincts, connexion réelle via Gateway |
| 3 | Changer alias/thème/langue de A | UI adaptée; mêmes valeurs après relance |
| 4 | A envoie un DM à B | Un seul message chez A et B; événement temps réel |
| 5 | Modifier puis supprimer un DM | Historique et événement cohérents des deux côtés |
| 6 | Déconnecter le socket B; A envoie/modifie/supprime | Au retour de B, REST rattrape l’état sans attendre un nouveau message |
| 7 | Redémarrer les services sans supprimer les volumes | Comptes, configuration et historique conservés |
| 8 | Ouvrir Dashboard sans session, puis avec un compte standard | Connexion demandée; utilisateur non-admin refusé |
| 9 | A crée un serveur privé, invite B puis le nomme modérateur | B gère les salons de ce serveur mais ni le serveur ni ses modérateurs; un simple membre n’a aucune action de gestion |
| 10 | Admin liste et supprime un utilisateur, un salon jetable et un message | Suppressions réelles; routes interdites à un compte standard |
| 11 | Admin crée un compte avec un courriel déjà utilisé | Erreur visible, aucun faux succès, formulaire conservé |
| 12 | B reçoit un DM avec sa fenêtre hors focus | Notification native ou repli annoncé; clic ouvre la bonne conversation |
| 13 | Mettre le mode notifications à aucune | Aucune notification système |
| 14 | A écrit à B (DM et salon commun) pendant que B est ailleurs | `GET /api/messages/unread` de B compte ces messages, pas ceux de B ; `PUT …/read` les remet à zéro |
| 15 | Redémarrer Message-Service sans supprimer les volumes | Mêmes compteurs de non-lus qu'avant le redémarrage |
| 16 | B cherche un mot présent dans un DM entre A et C et dans un salon commun | Seul le message du salon commun est trouvé ; pages suivantes sans doublon |
| 17 | A écrit à B ; B ouvre la conversation | Chez A, ✓ puis ✓✓ et « Lu à … » sans recharger ; chez B, « Nouveaux messages » au premier non-lu |

## Scénario mobile

Deux comptes sur deux téléphones (Expo Go), backend de la stack Infra. Les commandes et la cible déclarée sont dans le [README Mobile](https://github.com/Chatvardage/A26_5A6_01-Mobile#cible-test%C3%A9e). Les preuves d'exécution (captures, vidéo) ne sont pas versionnées : elles accompagnent la remise.

| Étape | Manipulation | Résultat attendu |
|---|---|---|
| M1 | `npx expo start`, connexion sur chaque téléphone | Listes de messages privés et de serveurs chargées |
| M2 | Ouvrir une conversation par sa route (`Conversation { conversationId }`) | Historique chargé ; un identifiant invalide affiche une erreur sans appel API |
| M3 | A écrit à B pendant que B est sur une autre conversation | Pastille de non-lus de B incrémentée ; notification (iPhone) ou pastille (Android Expo Go) ouvre la bonne conversation |
| M4 | Redémarrer l'application de B | Même compteur de non-lus |
| M5 | A modifie son message | B voit la nouvelle version et « modifié » sans recharger |
| M6 | Remonter une conversation de plus de 50 messages | Page plus ancienne chargée, ordre conservé, aucun doublon |
| M7 | Rechercher un mot | Seules les conversations accessibles sont trouvées ; toucher un résultat ouvre le message |
| M8 | Couper le réseau de B, A envoie, B tente d'envoyer | Bandeau hors ligne chez B, texte non envoyé conservé |
| M9 | Rétablir le réseau de B | Canal temps réel rétabli, messages manqués récupérés par REST |
| M10 | `npm test` et `npm run test:integration` dans Mobile | Tests verts, couverture à 100 % |

Utiliser des comptes et salons jetables pour les suppressions. La suppression du dernier salon et celle du serveur par défaut sont volontairement refusées.

## Résultats

Les résultats datés et les limites sont consignés dans [le rapport de validation](rapport-validation.md). Un élément non exécuté reste explicitement « à démontrer ».
