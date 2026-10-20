# Versions et publication

## Versions des composants

| Dépôt | Version déclarée | Tag attendu |
|---|---|---|
| [Frontend](https://github.com/Chatvardage/A26_5A6_01-Frontend) | 2.1.0 | `v2.1.0` |
| [Serveur-API](https://github.com/Chatvardage/A26_5A6_01-Serveur-API) | 1.1.0 | `v1.1.0` |
| [Authentification](https://github.com/Chatvardage/A26_5A6_01-Authentification) | 1.1.0 | `v1.1.0` |
| [Room-Service](https://github.com/Chatvardage/A26_5A6_01-Room-Service) | 1.1.0 | `v1.1.0` |
| [Message-Service](https://github.com/Chatvardage/A26_5A6_01-Message-Service) | 1.1.0 | `v1.1.0` |
| [User-Config-Service](https://github.com/Chatvardage/A26_5A6_01-User-Config-Service) | 1.0.1 | `v1.0.1` |
| [Dashboard](https://github.com/Chatvardage/A26_5A6_01-Dashboard) | 1.0.1 | `v1.0.1` |
| [Mobile](https://github.com/Chatvardage/A26_5A6_01-Mobile) | 1.0.1 (`package.json` et `app.json`) | `v1.0.1` |
| [Infra](https://github.com/Chatvardage/A26_5A6_01-Infra) | sans package.json | `v1.1.1` |

Les tags indiqués sont les noms attendus pour les versions déclarées; cette table ne confirme pas leur publication. Infra possède un tag propre à la configuration et à la documentation, sans package.json ; `v1.0.0` existe déjà sur une version antérieure de la documentation et ne doit pas être déplacé.

## Cohérence des versions

Chaque dépôt évolue indépendamment. Les versions mineures regroupent les fonctionnalités compatibles ajoutées depuis `main`; les correctifs seuls changent la version de correction. Une version doit correspondre au contenu publié et rester reproductible.

Le script `scripts/verifier-version.mjs` vérifie la cohérence de package.json et package-lock.json, puis compare le tag `v<version>` lorsqu’il est exécuté sur un tag. Il est présent dans les CI des sept applications. Authentification déclare également la version du binaire dans Cargo.toml et Cargo.lock; conserver ces fichiers alignés avec les métadonnées npm.

Les tags historiques du client desktop `v1.0.0` et `v1.0.1` restent inchangés. Le second contient une version déclarée `1.0.0`; ne pas le déplacer pour masquer cette incohérence. Les nouvelles publications doivent passer la vérification de version.

## Publier une version

1. Valider les tests et la compilation dans chaque dépôt concerné.
2. Exécuter [le scénario d’intégration](validation.md) avec les révisions compatibles.
3. Fusionner les changements revus, puis créer les tags sur les commits validés.
4. Vérifier les exécutions CI déclenchées par les tags et conserver les révisions utilisées pour la stack complète.

## Références

- [Installation et exploitation locale](../README.md)
- [Architecture](architecture.md) et [schéma de déploiement](architecture.png)
- [Contrats API](api/README.md)
- [Validation intégrée](validation.md) et [rapport daté](rapport-validation.md)
