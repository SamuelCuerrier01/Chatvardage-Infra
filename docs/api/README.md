# Contrats API et temps réel

Base d’entrée des clients Electron et mobile : `http://localhost:3000`. JSON sur HTTP, JWT dans `Authorization: Bearer <jeton>`. Socket.IO utilise le namespace `/messages`, chemin `/socket.io`, avec `auth: { token }`. Attendre `connexion.prete` avant les événements authentifiés.

- [Routage du Gateway et contrats publics](gateway.md)
- [Authentification : corps, réponses et permissions](authentification.md)
- [Serveurs/salons : routes, DTO et rôles](../services/Room-Service.md)
- [Messages : REST, pagination et administration](../services/Message-Service.md)
- [Recherche : comptes par personne, serveur et salon](recherche-resume.md)
- [Recherche : ouverture directe d'un message](recherche-pagination-directe.md)
- [Configuration : modèles et identité interne](../services/User-Config-Service.md)
- [Diffusion des DM](temps-reel-dm.md)
- [Diffusion des salons](temps-reel-salons.md)
- [Contrat consommé par Electron](frontend.md)

Room, Message et User-Config exposent Swagger (OpenAPI) sous `/docs` sur leurs ports locaux (3003/3004/3005). Le Gateway ne relaie pas ces pages. Auth fournit la documentation Markdown ci-dessus. Les schémas et migrations exécutables restent dans les dépôts propriétaires.
