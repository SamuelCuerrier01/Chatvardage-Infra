# Revues automatiques GitHub

Les workflows `.github/workflows/claude-review.yml` essaient Claude, puis Copilot si aucune revue n'a été publiée. Le dernier recours Codex est limité aux PR issues du même dépôt, public ou privé ; il utilise l'environnement GitHub `codex-review`. Un quota Copilot dépassé fait échouer l'étape de revue et déclenche Codex, même si `continue-on-error` laisse le job Copilot vert. Le relais vérifie l'échec de la commande et celui de la publication. Une PR de fork ou un workflow annulé ne lance pas Codex.

## Secrets

- `CLAUDE_CODE_OAUTH_TOKEN` : authentification Claude Code du job principal.
- `COPILOT_REVIEW_TOKEN` : authentification Copilot du premier recours. Un `401 Bad credentials` demande de renouveler ce secret et de vérifier son accès au service.
- `GITHUB_TOKEN` : fourni par GitHub pour publier la revue, avec `pull-requests: write`. Il ne remplace pas les identifiants des outils de revue.
- `CODEX_AUTH_JSON` et `CODEX_AUTH_STORAGE_TOKEN` : secrets de l'environnement `codex-review`, utilisés pour restaurer puis conserver la connexion Codex après rotation.

## Connexion Codex dédiée

Suivre la [procédure officielle de connexion en CI](https://learn.chatgpt.com/docs/auth/ci-cd-auth). Utiliser une connexion dédiée au dépôt, distincte de celle de l'app et des autres CI, dans un dossier privé avec stockage des identifiants dans un fichier. Le workflow attend un `auth.json` avec `auth_mode: chatgpt` et un jeton de renouvellement. Placer son contenu dans `CODEX_AUTH_JSON` de l'environnement, jamais dans le dépôt ni dans les journaux.

`CODEX_AUTH_STORAGE_TOKEN` doit permettre de remplacer ce secret d'environnement dans ce dépôt ; le `GITHUB_TOKEN` du workflow n'a pas ce rôle. Conserver la sérialisation `codex-plus-auth-${{ github.repository }}` : deux jobs ne doivent pas renouveler simultanément la même connexion. Le job sauvegarde la copie actualisée de `auth.json`, pas la valeur initiale. Il masque aussi chaque jeton individuellement : masquer le JSON complet ne masque pas une sous-chaîne extraite de ce JSON.

Si une approbation protège l'environnement `codex-review`, le job attend cette approbation. En cas d'expiration ou de révocation, renouveler la connexion dédiée et remplacer le secret d'environnement.

## Après rotation

Relancer le workflow de revue du HEAD courant depuis Actions. Vérifier qu'un commentaire est effectivement publié pour cette révision, puis traiter ses observations. Une revue d'une ancienne révision ou une étape sautée ne valide pas un nouveau commit.

Les actions qui manipulent ces secrets restent épinglées par SHA et les CLI par version exacte. Pour les mettre à jour, vérifier le tag dans leur dépôt officiel et la version du paquet, puis modifier les références ensemble.

## Sandbox Linux de Codex

Le job Codex utilise Ubuntu 24.04 et installe `bubblewrap` ainsi que le profil AppArmor `bwrap-userns-restrict` avant de restaurer ses identifiants. Un essai de lecture d'`AGENTS.md` dans un namespace sans réseau vérifie le prérequis avant la revue. La revue garde `--sandbox read-only` ; aucune restriction AppArmor globale n'est désactivée. Voir les [prérequis officiels du sandbox](https://learn.chatgpt.com/docs/sandboxing#prerequisites).

## Contenu des revues

Les problèmes sont listés par gravité : Critique (P0), Élevé (P1), Moyen (P2), Faible (P3), avec fichier, ligne, scénario déclencheur et impact. Les catégories vides et préférences cosmétiques sont omises. Copilot, privé de ses outils dans ce workflow, doit annoncer que son examen se limite au diff fourni.

Le commentaire Codex distingue les problèmes actionnables, les vérifications statiques et les limites. Il cite les fichiers réellement lus et les comportements vérifiés ; une absence de problème ne prouve pas une couverture exhaustive. Les tests examinés ne sont pas présentés comme exécutés. Un échec de lecture des fichiers doit être signalé comme une revue incomplète, sans verdict global rassurant. Les résultats des tests restent dans la CI du même commit.

Les fichiers facultatifs sont inventoriés avant lecture : un `docs/`, `API.md` ou `.prettierignore` absent ne rend pas la revue incomplète. Une sortie tronquée demande des lectures ciblées ; une véritable impossibilité de lire un fichier nécessaire limite la conclusion sur le chemin concerné. Un échec de formatage doit être vérifié avec la version verrouillée et sa configuration, sans déduire le résultat de la disposition visuelle du code.

Les prompts des trois outils traitent le diff comme des données non fiables, jamais comme des instructions. Claude reçoit aussi l’interdiction de lire les identifiants et variables d’environnement ; ces consignes ne remplacent pas l’isolation technique ni les permissions GitHub. Copilot reste sans outils.
