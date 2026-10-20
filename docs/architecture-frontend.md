# Architecture du Frontend ChatVardage

Application desktop Electron. Ce dépôt ne contient que le client : le
backend (Gateway + microservices) vit dans les autres dépôts `A26_5A6_01-*`
(voir `A26_5A6_01-Infra`). Le contrat HTTP/Socket.IO consommé est décrit
dans [le contrat frontend](api/frontend.md).

## Vue d'ensemble

```text
Pages (renderer, sans Node.js)
  connexion/ (React + Vite)     index.html / message-prive.html / profil.html (JS vanilla)
          │                                   │
          └──────── window.electronAPI / window.notifications ────────┘
                                   │  (preload.js, contextBridge)
                                   ▼
                    IPC Electron (canaux explicites, provenance vérifiée)
                                   │
                                   ▼
main.js + src/main/ ── état unique du processus : session, préférences, fenêtre
   │
   ▼
RealGatewayRuntime.js ── HTTP + Socket.IO ──► Serveur-API (Gateway, port 3000)
                                                ├─ Authentification
                                                ├─ Room-Service (serveurs, salons)
                                                ├─ Message-Service (messages, temps réel)
                                                └─ User-Config-Service (préférences, présence)
```

Un seul processus (`main.js` et ses modules `src/main/`) détient l'état métier et une **seule**
instance de `RealGatewayRuntime`, partagée par toutes les pages : naviguer
d'une page à l'autre ne perd ni la session ni les préférences.

### Une seule implémentation du gateway

Le processus principal crée une instance unique, `new RealGatewayRuntime(configurationApi)` (`src/main/gateway.js`), qui parle au Serveur-API en HTTP et Socket.IO. Les pages n'y accèdent que par les canaux IPC exposés par `preload.js` (`reseau:etat`, `presence:obtenir`, etc.). Les tests unitaires remplacent le réseau par des doublures.

## Arborescence

```text
main.js                      Processus principal Electron : profil
                             (CHATVARDAGE_PROFIL), chargement des modules
                             ci-dessous, verrou d'instance, cycle de vie
src/main/                    Modules du processus principal (CommonJS)
  contexte.js                état partagé (`etat` : fenêtre, langue, thème,
                             préférences…), logDebugNotif,
                             envoyerVersRenderer
  gateway.js                 l'UNIQUE instance de RealGatewayRuntime
  securite.js                isAppUrl, exposerCanal + vérification de
                             provenance, CSP de la page de connexion (testé)
  menu.js                    menu natif traduit
  fenetre.js                 fenêtre sans cadre hors macOS,
                             agrandir/restaurer géré par l'app, zoom
                             adaptatif, navigation, canaux 'fenetre:*'
  notifications.js           notifications système (repli sans D-Bus),
                             badge, canaux 'notification*'
  preferences.js             copie locale des préférences (thème, langue,
                             notifications, alias, avatar), synchronisée
                             avec User-Config-Service et diffusée aux pages
                             ('preferences:change')
  session.js                 connexion, déconnexion, session expirée,
                             relais des événements temps réel vers la page
  canaux-donnees.js          canaux qui délèguent au gateway (serveurs,
                             salons, messages, profil, présence)
  reseau.js                  sonde de connectivité réseau du système

preload.js                   Seul pont vers les pages (contextBridge)
  - window.electronAPI       session, serveurs/salons, messages, profil,
                             préférences, i18n, réseau, présence
  - window.notifications     notifications système, badge, focus fenêtre
  - barre de titre           injecte .app-titlebar (logo, nom, boutons
                             réduire/agrandir/fermer → canaux 'fenetre:*')

scripts/start.js             Lance Vite + Electron (dev) ou Electron seul
                             après build (prod)

assets/                      Icônes de l'app (icon.png, icon.ico)

src/
  domain/entities/           Modèle métier, sans dépendance à l'UI ni au
                             réseau (TypeScript, testé) : Utilisateur,
                             Serveur (rôles et permissions d'affichage),
                             EtatConnexion

  infrastructure/
    config/ConfigurationApi.js   URL du Gateway (CHATVARDAGE_API_URL,
                                 CHATVARDAGE_SOCKET_URL)
    gateways/
      AuthGateway.ts                   Contrat consommé par l'écran de
                                       connexion React
      RealGatewayRuntime.js            Implémentation utilisée par main.js :
                                       appels HTTP, Socket.IO, reconnexion,
                                       jeton persisté. Lève des CODES
                                       d'erreur (ERR_*), jamais du texte.
                                       Ne garde que le constructeur, les
                                       événements et l'appel HTTP ; les
                                       méthodes sont dans runtime/
      runtime/                         Méthodes de RealGatewayRuntime par
                                       domaine, ajoutées à son prototype :
                                       utilisateurs, session, configuration,
                                       temps-reel, serveurs, messages,
                                       presence, reseau ; constantes.js et
                                       jeton.js (persistance chiffrée)

  i18n/
    translations.json        Seule source des textes (fr + en), y compris
                             les salons par défaut et le message de
                             bienvenue (channels.defaultAnnouncements,
                             channels.defaultGeneral, channels.welcomeMessage)
    i18n.js                  t() pour main.js (CommonJS)
    i18n-web.ts              t() pour la page React (ESM)

  presentation/pages/
    connexion/               Page React (build Vite → dist/login/)
      main.tsx               Composition : restauration de session, langue,
                             application du dernier thème connu
      LoginPage.tsx          Connexion (sélecteur de langue, pas de thème)
      InscriptionPage.tsx    Inscription
      PseudoChoicePage.tsx   « Choisis ton pseudo » après l'inscription
      connexion.css          Styles + barre de titre (.app-titlebar)
    index.html + javascript/salons/*.js + ../../../renderer.js
                             Serveurs et salons. Scripts classiques chargés
                             dans l'ordre (même portée globale) :
                               etat.js        DOM, état, stockage, réseau
                               historique.js  historique, messages non livrés
                               affichage.js   rendu salons/messages/actions
                               dialogues.js   créer, inviter, membres, menus
                               session.js     envoi, profil, initialiser()
                               temps-reel.js  notifications, messages reçus/
                                              modifiés/supprimés, saisie
                             renderer.js, chargé en dernier, lance la page.
    message-prive.html + javascript/messages-prives/*.js
                       + javascript/message-prive.js
                             Messages privés. Même principe que les salons
                             (scripts classiques, même portée globale) :
                               etat.js           dépendances, DOM, réseau,
                                                 présence, notifications
                               historique.js     non livrés, pagination
                               conversations.js  liste, saisie, messages
                                                 reçus, préférences
                               affichage.js      rendu liste/conversation
                               saisie.js         nouveau DM, filtres, envoi
                               rail.js           rail, pastilles, badge,
                                                 menu des notifications
                             message-prive.js, chargé en dernier, lance la
                             page au DOMContentLoaded.
    profil.html + javascript/profil.js
                             Profil : identité, compte, préférences (seul
                             endroit où changer le thème), suppression
    javascript/              Scripts classiques partagés (chargés avant la
                             page, exposent un global) :
      logique-interface.js   window.LogiqueInterface : logique PURE des deux
                             pages de chat (fusion/ajout/remplacement de
                             messages, règle de défilement, tris, contenu
                             du serveur par défaut), testée à 100 %
      i18n-browser.js        window.I18n
      theme-browser.js       window.ThemeManager (data-theme sur <html>)
      chat-ui-shared.js      window.ChatUiShared : réseau, présence,
                             avatars, actions de message, rôles,
                             dialogue de recherche de messages, fiche de
                             profil (ouvrirFicheProfil,
                             rendreAvatarCliquable)
      notif-prefs.js         window.NotifPrefs : compteurs de non-lus
                             (copie de l'état de Message-Service), mode
                             de notif.
    css/
      styles.css             Styles communs (variables de thème, barre de
                             titre, messages, dialogues, panneau des
                             membres, toasts)
      message-prive.css      Spécifique aux messages privés
      profil.css             Spécifique au profil
```

## Code partagé avec le client mobile (`src/partage/`)

`src/partage/` contient les hooks React et les règles pures communs au client Web et au client mobile
(`A26_5A6_01-Mobile`), identiques à l'octet près dans les deux dépôts :

| Fichier | Rôle |
|---|---|
| `useAsyncResource.ts` | Hook des cinq états d'une liste : chargement, erreur (raison + `retry`), vide, succès, rafraîchissement (liste gardée, `refreshError` si la mise à jour échoue) |
| `useSearch.ts` | `useSearchResults({ search, describeError, debounceMs? }, conversationId?)` : recherche de messages avec délai de frappe, annulation et pagination sans doublon |
| `search.ts`, `groupResults.ts`, `highlight.ts` | Types et règle de la recherche, regroupement des résultats (messages privés, puis par serveur), surlignage du texte cherché |

Règle : ces fichiers n'importent que `react` et leurs voisins (chemins relatifs) ; chaque application fournit
l'appel REST et les textes d'erreur. Le Frontend les teste avec Vitest et `@testing-library/react` (couverture à 100 %) ;
le Mobile avec Jest. Toute modification se reporte à l'identique dans les deux dépôts, puis
`A26_5A6_01-Infra/scripts/verifier-fichiers-partages.sh` le vérifie (aussi en CI). Les pages de chat actuelles
(JS vanilla) ne les utilisent pas encore : seules les pages React (connexion) pourraient les importer.

## Flux importants

**Ouverture de session.** La page de connexion appelle
`session:authentifier` ou `session:inscription`. `main.js` charge les
serveurs, récupère les préférences depuis User-Config-Service, puis y
enregistre la langue si elle a été explicitement changée sur l'écran de
connexion (`langueChoisieAvantConnexion`,
`apresOuvertureSessionAvecLangueChoisie`). La reprise automatique d'une
session (`session:restaurer`) garde la langue du profil.

**Préférences.** Thème et langue sont modifiés depuis la page profil
(`preferences:modifier`, `theme:definir`, `langue:definir`). `main.js` met
à jour sa copie, enregistre sur le serveur et diffuse
`preferences:change` à la page affichée.

**Traductions.** Les pages vanilla reçoivent tout le dictionnaire une fois
(`i18n:dictionnaires`). Les textes sont traduits à l'affichage, jamais
stockés déjà traduits. Les données saisies par les utilisateurs (noms de
serveurs et de salons, messages) ne sont pas traduites, sauf le contenu
créé par migration du serveur par défaut, reconnu à ses identifiants figés
tant qu'il n'a pas été renommé ou modifié.

**Fenêtre.** Hors macOS, `frame: false`. `preload.js` ajoute la barre de
titre à chaque page ; sa place (`--titlebar-height`) est réservée en CSS
dès le premier affichage (bordure haute du `body`), pour que la page ne
se décale pas quand la barre apparaît. Les boutons appellent
`fenetre:reduire`, `fenetre:agrandir` et `fenetre:fermer` ; `main.js`
renvoie `fenetre:maximisee` pour l'icône agrandir/restaurer. À chaque
redimensionnement, `appliquerZoomAdaptatif` ajuste le zoom (100 % à
135 %).

**Renouvellement de session.** Les jetons d’accès (15 minutes) et de renouvellement restent dans le processus principal et sont persistés ensemble, chiffrés par `safeStorage`. Sur un 401, le client partage une seule rotation via `POST /api/auth/refresh` entre les requêtes concurrentes, puis rejoue chaque requête une fois avec le nouvel accès. Un refus de renouvellement ferme la session et émet `session-expiree`. Un ancien fichier contenant seulement l’accès reste lisible ; la prochaine connexion ajoute le renouvellement. Sans coffre sécurisé, aucun jeton n’est conservé sur disque.

**Déconnexion et changement de compte.** Le client efface immédiatement sa session locale et demande la révocation de sa famille via `POST /api/auth/logout`, même si cet appel peut échouer hors ligne. Les réponses HTTP et événements du socket précédent ne modifient pas la session suivante. « Déconnecter les autres appareils » conserve les deux nouveaux jetons reçus d’Auth.

**Messages non lus.** Les compteurs viennent de Message-Service
(`messages:non-lus` → `GET /api/messages/unread`), chargés à l'ouverture de
chaque page et après chaque `connexion.prete`. Un message reçu d'autrui
incrémente le compteur de sa conversation ; l'affichage de la conversation
active, fenêtre au premier plan, la marque lue (`messages:marquer-lu` →
`PUT …/read`) et remet son compteur à zéro. Salons et conversations privées
affichent un compteur (« 99+ » au-delà), les serveurs du rail une pastille,
l'icône de l'app le total. Le mode de notification « aucune » les masque.

**Accusés de lecture.** À l'ouverture d'une conversation, la page retient
son nombre de non-lus (avant de la marquer lue) pour placer la ligne
« Nouveaux messages » au-dessus du premier non-lu, et charge les lectures des
autres (`messages:lectures`). Messages privés : ✓ (distribué, enregistré par
le serveur) ou ✓✓ (lu) sur chacun de mes messages, « Distribué » / « Lu à … »
sous mon dernier message s'il termine la conversation. Salons : « Vu par … »
sous le dernier message. L'événement Socket.IO `read-state.updated`, relayé
par `messages:lecture-change`, les met à jour en direct ; lu depuis un autre
de mes appareils, il fait relire les compteurs de non-lus.

**Synchronisation des compteurs et des lectures.** Le serveur fait foi :

- Après chaque message reçu d'autrui et chaque suppression, les deux pages relisent les non-lus par HTTP ; l'incrément local n'est que provisoire et aucun décrément local n'est fait. Une réponse dépassée par une requête plus récente est ignorée.
- Le marquage comme lu transmet l'identifiant du dernier message enregistré **affiché** (jamais un brouillon non livré) : un message arrivé côté serveur mais pas encore rendu reste non lu. Il n'a lieu que si la conversation est affichée au premier plan.
- La position de lecture `(lastReadAt, lastReadMessageId)` est fusionnée de façon monotone entre réponses HTTP et événements temps réel, pour les coches comme pour « Vu par ». À date égale, les identifiants sont comparés dans l'ordre du serveur `(createdAt, id)`. Un événement dont la date n'est pas interprétable est ignoré.
- Chaque ouverture de conversation a son propre état d'historique : les réponses, erreurs et pagination d'une ouverture précédente sont ignorées. Un saut vers un résultat de recherche attend la page en cours et s'arrête si la conversation change.
- L'interface affiche « Lu », pas une heure : le contrat expose la position du dernier message lu, pas l'heure de l'action de lecture.

**Recherche.** Le bouton « Rechercher » des deux pages ouvre le dialogue
`#search-dialog` (`ChatUiShared.brancherRechercheMessages`,
`messages:rechercher` → `GET /api/messages/search?conversationId=…`). La
recherche porte uniquement sur la conversation affichée : le salon actif, ou
la conversation privée ouverte. Changer de conversation remet le dialogue à
zéro ; sans conversation affichée, le champ est désactivé. Un clic sur un
résultat charge directement la page qui commence au message (`around`), fait
défiler jusqu'à lui et le met en évidence quelques secondes
(`ChatUiShared.allerAuMessageAffiche`) ; la pagination reprend ensuite vers
les messages plus anciens (`cursor`) ou plus récents (`direction=after`).

**Fiche de profil.** Un clic (ou Entrée/Espace) sur la photo d'un autre
utilisateur ouvre sa fiche (`ChatUiShared.ouvrirFicheProfil`, contenu calculé
par `LogiqueInterface.ficheProfil`) : photo ou initiale, nom affiché (alias,
sinon pseudo), `@pseudo`, présence, et un bouton « Message privé ». Photos
concernées : auteurs des messages d'un salon, liste des membres d'un serveur,
liste des messages privés, barre du haut et messages d'une conversation privée.
Pas de bouton sur sa propre fiche ni vers la conversation privée déjà affichée.
Depuis la page des salons, le bouton crée la conversation
(`demarrerConversationPrivee`) puis navigue vers `message-prive.html` avec la
cible `{ type: 'prive' }` ; depuis la page des messages privés, il l'ouvre sur
place. Le dialogue est créé à la demande et retiré à sa fermeture : il
s'ouvre aussi par-dessus le dialogue des membres.

**Temps réel sans rechargement.** Un message reçu, modifié ou supprimé (salon
ou privé) est appliqué à l'état déjà affiché ; les listes ne défilent vers
le bas que si on suit la conversation. Le sondage de présence (20 s) ne
réinterroge pas les autres utilisateurs tant que le temps réel est actif.

## Tests

- `src/**/*.test.ts` (Vitest, jsdom) ; couverture 100 % exigée sur
  `src/**/*.ts`, `RealGatewayRuntime.js` et `logique-interface.js`.
- `salons/salons.chargement.test.ts` et `message-prive.chargement.test.ts` :
  les pages de chat chargées avec tous leurs scripts dans l'ordre réel et
  une fausse API Electron (contrat du découpage, messages reçus/modifiés/
  supprimés, rechargements évités, droits d'invitation).

## Sécurité

`contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`,
`webviewTag: false`. Jetons d’accès et de renouvellement chiffrés par le système
(`safeStorage`) dans un fichier `0600`. Chaque canal IPC est déclaré explicitement dans
`preload.js` et `main.js`, qui vérifie la provenance de l'appel. Les
messages sont affichés par `textContent` / création DOM, jamais par
injection HTML.
