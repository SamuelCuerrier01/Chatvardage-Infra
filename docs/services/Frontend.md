# Chatvardage — Client desktop

Application de clavardage desktop réalisée avec Electron, connectée à
l'infrastructure ChatVardage réelle (Gateway + microservices — voir
`A26_5A6_01-Infra`) : authentification par mot de passe, salons et DM réels,
présence et messages de salon en temps réel via Socket.IO. Voir
[contrat frontend](../api/frontend.md) pour le détail du contrat HTTP/Socket.IO consommé.

## 1. Objectifs

- Authentification par courriel/pseudo + mot de passe, pseudo modifiable
  après l'inscription (unique, 3-20 caractères). Déconnexion depuis l'app, ou
  « Se déconnecter partout » (tous les jetons du compte invalidés).
- Alias (nom affiché, 50 caractères au plus) choisi dans le profil : il
  remplace le pseudo dans l'en-tête, la liste des DM et les messages de
  salon, chez soi comme chez les autres.
- Ouverture directe sur le clavardage quand une session valide est
  enregistrée ; le profil n'est ouvert qu'à la demande.
- Préférences (alias, avatar, thème, langue, notifications) enregistrées dans
  User-Config-Service et appliquées immédiatement à la page affichée.
- Serveurs publics et privés avec invitations. Dans chaque serveur, les
  modérateurs, le propriétaire et les admins gèrent les salons (créer,
  renommer, supprimer) et peuvent expulser un membre de rang inférieur ; le
  propriétaire nomme les modérateurs.
- Messages et conversations privées (DM), et messages de salon.
- Présence en ligne/hors ligne et indicateur « en train d'écrire ».
- Historique paginé (« charger les messages plus anciens »).
- États réseau : connecté, déconnecté et reconnexion (Socket.IO).
- Notifications système lorsqu'un message arrive hors focus.
- Compteur de messages non lus par salon et par conversation privée, tenu
  par Message-Service : identique après un redémarrage et sur le mobile.
- Recherche de messages dans le salon ou la conversation privée affichée.
- Ligne « Nouveaux messages » au premier non-lu d'une conversation ouverte.
- Accusés de lecture : ✓ distribué / ✓✓ lu et « Lu à … » dans les messages
  privés, « Vu par … » dans les salons, en temps réel.
- Modification et suppression de ses propres messages.
- Page de profil (pseudo, mot de passe, thème/langue/notifications). Le
  courriel est affiché mais n'est pas modifiable.
- Interface bilingue (fr/en), y compris les salons et le message de bienvenue
  du serveur par défaut.
- Application Electron sécurisée et multiplateforme, avec une barre de titre
  aux couleurs du thème et un zoom qui suit la taille de la fenêtre.

## 2. Choix techniques et architecture

- **Langages :** JavaScript + TypeScript.
- **Desktop :** Electron.
- **Connexion :** React + Vite.
- **Chat :** HTML/CSS/JavaScript vanilla.
- **Tests :** Vitest.
- **Qualité :** ESLint + Prettier.
- **Persistance :** accès et renouvellement chiffrés ensemble par `safeStorage` dans `app.getPath('userData')`, fichier `0600`. Aucun stockage en clair ; le backend Linux `basic_text` est refusé et, sans coffre, la session reste seulement en mémoire. Les données métier restent sur le backend.
- **Barre de titre personnalisée** : hors macOS, la fenêtre est sans cadre
  (`frame: false`) — le cadre natif laissait une barre et un contour blancs
  sous Linux/WSLg. `preload.js` injecte en haut de chaque page une bande
  glissable (`.app-titlebar` : logo, « ChatVardage », boutons réduire /
  agrandir / fermer) ; son style est dans `styles.css` et `connexion.css`.
  Sur macOS, les boutons natifs sont conservés (`titleBarStyle: 'hidden'`).
- **Agrandir / restaurer** est géré par l'app (`basculerAgrandissement` dans
  `main.js`) : la fenêtre prend la zone de travail de l'écran, puis retrouve
  sa taille d'avant. `maximize()` n'est pas fiable sous WSLg pour une
  fenêtre sans cadre. Double-cliquer sur la bande fait la même chose.
- **Zoom adaptatif** : 100 % jusqu'à la taille par défaut (1280 × 800), puis
  proportionnel à la fenêtre, plafonné à 135 % (`ZOOM_ADAPTATIF_MAX` dans
  `main.js`).
- **Thème** : choisi uniquement dans **Profil → Préférences**. Les écrans de
  connexion, d'inscription et « Choisis ton pseudo » n'ont plus de sélecteur
  et réutilisent le dernier thème connu.
- **Langue** : si elle est changée (FR/EN) sur l'écran de connexion ou
  d'inscription, elle est enregistrée dans le profil (User-Config-Service)
  dès l'ouverture de session. Sans choix explicite, c'est la langue du
  profil qui s'applique ; une reprise de session automatique la garde aussi.
- **Contenu du serveur par défaut traduit** : `#annonces`/`#announcements`,
  `#général`/`#general` et le message de bienvenue sont reconnus à leurs
  identifiants figés (`SALONS_PAR_DEFAUT`, `MESSAGE_BIENVENUE_ID` dans
  `logique-interface.js`) et affichés dans la langue de l'app, tant qu'ils n'ont pas
  été renommés/modifiés. Les salons créés par les utilisateurs ne sont
  jamais traduits.
- **Messages** : la bulle épouse son texte (75 % de la largeur au maximum) ;
  auteur, heure et « (modifié) » restent sur une seule ligne. La pastille de
  présence n'est affichée que dans l'en-tête d'une conversation privée, pas
  sur les avatars des messages.
- **Panneau « Membres de … »** : une carte par membre (avatar avec pastille
  de présence, nom, présence et badge de rôle, actions à droite), chargés
  par pages de 50 (« Afficher plus de membres ») dans l'ordre propriétaire →
  modérateurs → membres. La liste complète n'est plus chargée avec le
  serveur : tout le monde est membre du serveur par défaut.
- **Messages temporaires** (`#toast` : confirmations, « nouveau message »
  quand la notification système est indisponible) : en haut, centrés sous
  la barre de titre, pour ne pas masquer la zone de saisie.
- **Session :** l’accès de 15 minutes est renouvelé automatiquement ; un refus de renouvellement ramène à l’écran de connexion. La déconnexion efface les jetons et demande leur révocation auprès d’Auth ; une panne réseau peut empêcher cette révocation distante.
- **Aperçu dans les notifications** : menu des notifications → « Afficher le
  contenu » (activé par défaut). Désactivé, la notification système dit
  seulement « Nouveau message reçu » (utile sur un écran verrouillé).
- **Page des salons** : découpée en scripts `javascript/salons/*.js` (voir
  [architecture frontend](../architecture-frontend.md)), sa logique pure dans `javascript/logique-interface.js`.

## 3. Prérequis

- Node.js 22 recommandé.
- npm.
- Windows, macOS ou Linux.
- L'infrastructure ChatVardage démarrée (voir `A26_5A6_01-Infra`,
  `docker compose up`) — Gateway sur `http://localhost:3000` par défaut. Sans
  elle, l'app se lance normalement mais chaque appel réseau échoue avec
  `ERR_RESEAU_INDISPONIBLE` (connexion/inscription impossibles).

Installation :

```bash
npm install
```

## 4. Lancement

Mode développement (Vite + Electron) :

```bash
npm run dev
```

Backend visé par défaut : `http://localhost:3000` (voir [contrat frontend](../api/frontend.md)
pour le contrat complet). Surchargeable via `CHATVARDAGE_API_URL`/
`CHATVARDAGE_SOCKET_URL`.

Lancement normal :

```bash
npm start
```

Le script `prestart` construit automatiquement la page de connexion avant le lancement normal.

## 5. Qualité et tests

```bash
npm run format
npm run lint
npm test
npm run test:coverage
```

`test:coverage` exige **100 %** (instructions, branches, fonctions, lignes)
sur `src/**/*.ts`, `RealGatewayRuntime.js` et `runtime/` (le vrai client réseau) et
`logique-interface.js` (logique pure des pages de chat) et
`src/main/securite.js` (provenance des URL et des appels IPC) — voir
`vitest.config.ts`. Les pages de chat sont en plus testées de bout en bout
dans jsdom (`*.chargement.test.ts` : tous leurs scripts, dans l'ordre réel,
avec une fausse API Electron). Le reste du processus main
(`main.js`, `src/main/`) et `preload.js` ne sont pas mesurés : ils ne se
testent qu'en lançant l'app.

Le warning éventuel de `@typescript-eslint` concernant la version de TypeScript est un avertissement de compatibilité de l'outil et non une erreur ESLint.

## 6. Builds de production

Chaque build commence par compiler la page de connexion avec Vite. Les artifacts Electron sont générés dans `release/`.

```bash
npm run build:win
npm run build:mac
npm run build:linux
```

Un build macOS doit être produit sur macOS. Le workflow `.github/workflows/builds.yml` exécute automatiquement les builds sur les bons runners Windows, macOS et Linux lors d'un tag `v*` ou manuellement avec **Run workflow**. Le lint et les tests (couverture à 100 %) tournent en plus à chaque PR et à chaque push sur `main` ou `develop`, sans lancer les builds.

Artifacts attendus :

- Windows : installateur NSIS.
- macOS : DMG.
- Linux : AppImage.

## 7. Scénarios de test pour la validation

### Authentification, pseudo et messages

1. Lancer l'application (stack ChatVardage démarrée, voir `A26_5A6_01-Infra`).
2. S'inscrire avec un courriel + mot de passe, puis choisir/confirmer son
   pseudo sur l'écran qui suit (unique, 3-20 caractères, modifiable plus tard
   depuis le profil).
3. Rejoindre un salon public.
4. Envoyer un message et vérifier l'horodatage.
5. Modifier puis supprimer un de ses propres messages.
6. Ouvrir les messages privés et envoyer un DM.
7. Fermer puis relancer l'application : vérifier que la session est reprise
   automatiquement (jeton persisté) sans repasser par l'écran de connexion.

### Serveur privé, invitation et modération

1. Avec le compte A, créer un serveur privé : A en devient propriétaire.
2. Inviter B depuis ce serveur.
3. Avec B (sur une autre instance de l'app), ouvrir **Invitations** puis
   accepter ou refuser. Après un refus, le serveur reste inaccessible.
4. Tant que B est simple membre, il ne voit ni le bouton « Créer un salon »
   ni les actions de gestion.
5. A nomme B modérateur depuis le panneau des membres. B peut alors créer,
   renommer et supprimer un salon, et expulser un simple membre ; il ne peut
   ni renommer ni supprimer le serveur.
6. A retire le rôle de modérateur à B : ces actions disparaissent chez B.

### Deux comptes en parallèle

Une seule instance est autorisée par dossier de données. Pour une deuxième
fenêtre (autre compte), lancer la seconde avec un profil distinct :

```bash
npm start                                   # terminal 1
CHATVARDAGE_PROFIL=2 node scripts/start.js  # terminal 2 (sans rebuild)
```

Chaque profil a sa propre session, son `localStorage` et son verrou
d'instance (`~/.config/chatvardage-2`, etc.).

### Présence et typing

1. Changer sa présence dans **Profil → Préférences** : la pastille de son
   avatar (panneau du bas) passe au vert/rouge.
2. Depuis un second compte, vérifier le reflet dans la liste des membres et
   les DM (délai ≤ 20 s), et qu'après fermeture de l'app du premier compte,
   il apparaît hors ligne au bout de ~90 s.
3. Ajouter une photo de profil : elle apparaît dans les messages, la liste
   des membres et les DM de l'autre compte (≤ 2 min, immédiat pour un
   nouvel interlocuteur).
4. Commencer à écrire dans un salon ou un DM depuis un second compte.
5. Vérifier que l'indicateur « en train d'écrire » apparaît puis disparaît.

### Réseau

1. Couper le Wi‑Fi / débrancher le réseau : l'indicateur passe à
   **Déconnecté · Pas de connexion Internet** en ~3 à 6 s, sans tentatives
   (même avec un serveur local : la connectivité est vérifiée par une sonde
   `HEAD https://www.gstatic.com/generate_204`, remplaçable ou désactivable
   via `CHATVARDAGE_CONNECTIVITY_URL`).
2. Envoyer un message : il s'affiche **Non livré** (réessayer/supprimer).
3. Rétablir le réseau : **Reconnexion… → Connecté** immédiatement.
4. Arrêter le Serveur-API (réseau toujours actif) : l'indicateur affiche
   **Reconnexion… · Serveur injoignable · nouvelle tentative dans X s**
   (délai 1 s → 15 s max) et un bouton **Réessayer** qui saute l'attente.
5. Relancer le serveur : retour à **Connecté** à la tentative suivante.
6. Mise en veille puis réveil : reconnexion immédiate sur un socket neuf.

### Historique / pagination

1. Ouvrir une conversation contenant plusieurs messages.
2. Remonter en haut de la liste ou cliquer **Charger les messages plus anciens**.
3. Vérifier que les anciens messages sont ajoutés sans perdre la position de scroll.

### Notifications

1. Choisir le mode de notification souhaité.
2. Mettre la fenêtre hors focus ou afficher une autre conversation.
3. Recevoir un message d'un second compte et vérifier la notification
   système et le compteur non lu de la conversation (pastille du serveur
   pour un salon, rond du bouton des messages privés pour un DM).
4. Ouvrir la conversation : le compteur disparaît. Relancer l'app avant de
   l'ouvrir : le compteur est toujours là (état tenu par le serveur).

### Accusés de lecture

1. A envoie deux messages privés à B, fenêtre de B ailleurs : chez A, ✓ et
   « Distribué » sous son dernier message.
2. B ouvre la conversation : la ligne « Nouveaux messages » précède les deux
   messages ; chez A, sans recharger, ✓✓ et « Lu à … ».
3. Dans un salon commun, A écrit, B et C l'ouvrent : chez A, « Vu par B, C »
   sous le dernier message.

### Recherche

1. Ouvrir un salon, cliquer sur **Rechercher** (barre du haut) : le titre
   indique « Rechercher dans # salon ». Taper au moins 2 caractères.
2. Vérifier que seuls des messages de ce salon apparaissent (un mot présent
   dans un autre salon ou un DM n'est pas trouvé), le terme surligné, puis
   **Plus de résultats** s'il y en a d'autres.
3. Cliquer un résultat ancien : la conversation remonte jusqu'à ce message,
   mis en évidence quelques secondes.
4. Changer de salon : le dialogue repart de zéro. Même vérification dans
   une conversation privée.

### Langue et thème

1. Sur l'écran de connexion, passer en **EN**, puis se connecter.
2. Vérifier que l'app est en anglais (salons `#announcements`/`#general`,
   message de bienvenue traduit) et que **Profile → Preferences** indique
   **English**.
3. Se déconnecter puis se reconnecter sans toucher à la langue : l'app reste
   en anglais.
4. Vérifier que les écrans de connexion/inscription n'ont pas de sélecteur
   de thème et reprennent le thème choisi dans le profil.

### Fenêtre

1. Déplacer la fenêtre en glissant la barre de titre.
2. Cliquer sur **Agrandir** (ou double-cliquer sur la barre) : la fenêtre
   occupe l'écran et l'interface grossit ; cliquer de nouveau la ramène à sa
   taille précédente.
3. Changer de thème : la barre de titre change de couleur.

### Profil

1. Ouvrir la page profil depuis le tableau de bord.
2. Changer son pseudo, vérifier l'unicité (409 si déjà pris).
3. Définir un alias : il s'affiche aussitôt à la place du pseudo, puis chez
   le second compte dans les messages et la liste des DM.
4. Changer son thème/langue/mode de notification : l'interface change sans
   rechargement ; vérifier la persistance après reconnexion.
5. Changer son mot de passe (mot de passe actuel requis) : l'app reste
   connectée. Authentification révoque tous les jetons existants à ce
   moment-là ; l'app se reconnecte d'elle-même avec le nouveau mot de passe
   (`renouvelerJetonApresChangementMotDePasse`). Vérifier aussi qu'un mot de
   passe actuel erroné affiche « Mot de passe actuel incorrect. » et que le
   courriel est en lecture seule.

## 8. Sécurité Electron vérifiée

Dans la `BrowserWindow` :

```text
contextIsolation: true
nodeIntegration: false
```

Autres mesures :

- API limitée via `contextBridge` dans `preload.js`.
- Canaux IPC explicites plutôt qu'un passthrough générique.
- Validation de la provenance des appels IPC dans `main.js`.
- CSP appliquée à la page de connexion.
- Affichage des messages par `textContent` / création DOM, sans injection HTML utilisateur.
- Aucun secret requis ou commité.
- Menu Electron applicatif contrôlé et icône personnalisée.
- Boutons de la barre de titre : canaux IPC dédiés (`fenetre:reduire`,
  `fenetre:agrandir`, `fenetre:fermer`, `fenetre:est-maximisee`), appelés
  depuis `preload.js` uniquement et soumis à la même validation de
  provenance que les autres canaux — aucune API de fenêtre n'est exposée à
  la page.

## 9. Limites connues et pistes d'amélioration

- La présence des autres est poussée en temps réel (`presence.changed`),
  seulement pour les utilisateurs connus de l'app (500 au plus : ceux
  affichés), auxquels elle s'abonne avec `presence.suivre` ; elle est
  réconciliée par un sondage toutes les 20 s (sans les photos). Les photos
  ne sont rechargées que sur `profil.changed` et après une reconnexion du
  socket, pour rattraper les changements manqués pendant la coupure.
- Un message reçu dans un salon du serveur affiché est ajouté directement à
  l'écran (sans rechargement) ; un rechargement complet n'a lieu que si son
  auteur n'est pas encore connu (pseudo et photo à résoudre).
- Même principe pour les messages privés : un message reçu, envoyé, modifié
  ou supprimé est appliqué à sa conversation déjà chargée ; les
  conversations ne sont rechargées (une requête d'historique par
  interlocuteur) qu'au chargement de la page ou pour un nouvel
  interlocuteur.
- La liste ne descend sur un nouveau message que s'il est dans la
  conversation affichée et qu'on en est l'auteur ou qu'on était déjà en bas.
- Aucun répertoire/annuaire global d'utilisateurs n'existe côté backend pour
  un compte non-admin ; la liste de candidats à l'invitation ne montre donc
  sans rien taper que des suggestions (participants de DM déjà ouverts et
  premiers membres de chacun de ses serveurs) ; les autres se trouvent par
  la recherche par pseudo (`GET /api/users/search`).
- La signature/code signing des builds n'est pas configurée.
- La fenêtre sans cadre ne propose pas le menu système natif (clic droit
  sur la barre de titre) ; les raccourcis clavier du système restent actifs.
- Les builds macOS/Windows/Linux sont générés par leurs runners respectifs dans GitHub Actions.

La déconnexion locale et le retour à la connexion n’attendent pas la révocation HTTP, envoyée en arrière-plan. Les requêtes de fond ne déclenchent pas de renouvellement pendant une rotation explicite, mais la requête initiale de cette rotation peut renouveler un accès expiré avant de réessayer ; une réponse de renouvellement antérieure ne remplace pas les jetons issus de cette rotation.
