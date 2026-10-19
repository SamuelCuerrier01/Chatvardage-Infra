Guide — Script pull-clone-all.sh
Ce guide explique comment utiliser le script pull-clone-all.sh du repo Infra pour synchroniser automatiquement les 9 repos du projet Chatvardage.

1. À quoi sert le script ?
Le script permet de gérer automatiquement les 9 repos suivants :
● A26_5A6_01-Infra
● A26_5A6_01-Frontend
● A26_5A6_01-Room-Service
● A26_5A6_01-Message-Service
● A26_5A6_01-Serveur-API
● A26_5A6_01-Authentification
● A26_5A6_01-User-Config-Service
● A26_5A6_01-Dashboard
● A26_5A6_01-Mobile
Pour chaque repo :
● s’il existe déjà, le script fait un git pull --ff-only;
● s’il n’existe pas, le script le clone automatiquement;
● si le remote origin utilise encore HTTPS, il est remplacé par l’URL SSH;
● les modifications locales sont détectées et affichées;
● un résumé est affiché à la fin.

2. Structure attendue
Tous les repos doivent être placés dans le même dossier parent.
Exemple :
chatvardage/
├── A26_5A6_01-Infra/
│   └── scripts/
│       └── pull-clone-all.sh
│
├── A26_5A6_01-Frontend/
├── A26_5A6_01-Room-Service/
├── A26_5A6_01-Message-Service/
├── A26_5A6_01-Serveur-API/
├── A26_5A6_01-Authentification/
├── A26_5A6_01-User-Config-Service/
└── A26_5A6_01-Dashboard/
Il n’est pas nécessaire que les 7 autres repos existent déjà. Le script les clonera automatiquement.

3. Prérequis
Avant d’utiliser le script, il faut avoir :
● Git installé;
● Bash ou WSL;
● accès aux repos privés de l’organisation GitHub Chatvardage;
● une clé SSH configurée sur GitHub.
Vérifier Git :
git --version
Vérifier la connexion SSH à GitHub :
ssh -T git@github.com
Une réponse semblable à celle-ci indique que la connexion fonctionne :
Hi utilisateur! You've successfully authenticated, but GitHub does not provide shell access.

4. Configurer une clé SSH
Cette étape est nécessaire seulement si aucune clé SSH GitHub n’est déjà configurée sur la machine.
Générer une clé
ssh-keygen -t ed25519
Appuyer sur Enter pour conserver l’emplacement proposé.
La clé privée est normalement créée ici :
~/.ssh/id_ed25519
La clé publique est normalement ici :
~/.ssh/id_ed25519.pub
Afficher la clé publique
cat ~/.ssh/id_ed25519.pub
Copier toute la ligne affichée.
Dans GitHub :
Settings
→ SSH and GPG keys
→ New SSH key
Coller la clé publique puis enregistrer.
Important
Ne jamais mettre la clé privée dans :
● le script;
● un repo Git;
● un fichier .env;
● Discord, Teams ou MIO.
Le script ne contient aucun mot de passe, token ou clé privée.

5. Emplacement du script
Le script doit être placé ici :
A26_5A6_01-Infra/scripts/pull-clone-all.sh

6. Première utilisation
Se placer dans le repo Infra :
cd /mnt/c/chatvardage/A26_5A6_01-Infra
Rendre le script exécutable :
chmod +x scripts/pull-clone-all.sh
Cette commande n’est normalement nécessaire qu’une seule fois.
Lancer le script :
./scripts/pull-clone-all.sh
Il est aussi possible de le lancer explicitement avec Bash :
bash scripts/pull-clone-all.sh

7. Ce que fait le script
Si le repo existe déjà
Le script :
1. vérifie que le dossier est bien un repo Git;
2. vérifie le remote origin;
3. remplace automatiquement l’URL HTTPS par SSH si nécessaire;
4. affiche la branche actuelle;
5. indique si des changements locaux existent;
6. exécute :
git pull --ff-only
Si le repo n’existe pas
Le script utilise une URL SSH de cette forme :
git@github.com:Chatvardage/NOM-DU-REPO.git
Puis exécute :
git clone git@github.com:Chatvardage/NOM-DU-REPO.git
Le repo est cloné à côté de A26_5A6_01-Infra.

8. Pourquoi utiliser git pull --ff-only ?
Le script utilise :
git pull --ff-only
au lieu de simplement :
git pull
Cela empêche Git de créer automatiquement un merge commit si la branche locale et la branche distante ont divergé.
Si un fast-forward est impossible, le script affiche une erreur et laisse l’utilisateur régler la situation manuellement.

9. Modifications locales
Si le script affiche :
⚠️ Modifications locales détectées.
cela signifie qu’il existe des fichiers modifiés, ajoutés ou supprimés qui ne sont pas encore commités.
Vérifier avec :
git status
Le script ne supprime pas les modifications locales.

10. Vérifier le remote Git
Pour vérifier qu’un repo utilise bien SSH :
git remote -v
Le résultat attendu ressemble à :
origin  git@github.com:Chatvardage/A26_5A6_01-Infra.git (fetch)
origin  git@github.com:Chatvardage/A26_5A6_01-Infra.git (push)
Si une URL HTTPS est détectée, le script essaiera automatiquement de la remplacer par l’URL SSH correspondante.

11. Résultat attendu
Exemple :
==================================================
      SYNCHRONISATION DES REPOS CHATVARDAGE
==================================================
📦 A26_5A6_01-Infra
🌿 Branche : develop
✅ Aucun changement local.
⬇️ Pull...
Already up to date.
✅ A26_5A6_01-Infra est à jour.
📦 A26_5A6_01-Frontend
📥 Repo absent.
Cloning into 'A26_5A6_01-Frontend'...
✅ A26_5A6_01-Frontend cloné avec succès.
...
==================================================
                    TERMINÉ
==================================================
📥 Repos clonés : 7
⬇️ Repos mis à jour : 1
✅ Succès : 8
❌ Erreurs : 0

12. Problèmes fréquents
Permission denied (publickey)
La clé SSH n’est pas configurée correctement ou n’est pas associée au bon compte GitHub.
Tester :
ssh -T git@github.com

Repository not found
Vérifier :
● que le nom du repo est correct;
● que le compte GitHub possède l’accès au repo privé;
● que la clé SSH est associée au bon compte GitHub.

fatal: Not possible to fast-forward
La branche locale et la branche distante ont divergé.
Commencer par vérifier :
git status
git log --oneline --graph --decorate --all -20
Ne pas forcer un reset sans vérifier les commits locaux.

The authenticity of host 'github.com' can't be established
Lors de la première connexion SSH, GitHub peut demander :
Are you sure you want to continue connecting (yes/no/[fingerprint])?
Vérifier l’empreinte officielle GitHub si nécessaire, puis répondre :
yes

Le script ne se lance pas
Vérifier les permissions :
chmod +x scripts/pull-clone-all.sh
Puis :
./scripts/pull-clone-all.sh
Pour voir l’exécution ligne par ligne :
bash -x scripts/pull-clone-all.sh

13. Utilisation quotidienne
Une fois la configuration terminée, il suffit normalement de faire :
cd /mnt/c/chatvardage/A26_5A6_01-Infra
./scripts/pull-clone-all.sh
Le script s’occupe ensuite de synchroniser les 9 repos automatiquement.

14. Ajouter un nouveau repo
Pour ajouter un repo au script, ajouter simplement son nom dans le tableau REPOS.
Exemple :
REPOS=(
   "A26_5A6_01-Infra"
   "A26_5A6_01-Frontend"
   "A26_5A6_01-Nouveau-Service"
)
Le nouveau repo sera automatiquement cloné s’il n’existe pas encore.

Sécurité
Le script peut être commit dans le repo Infra.
Il ne doit contenir :
● aucun mot de passe;
● aucun Personal Access Token GitHub;
● aucune clé SSH privée;
● aucun secret de production.
Chaque membre de l’équipe doit utiliser sa propre clé SSH et posséder les permissions GitHub nécessaires.