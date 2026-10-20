# Résumé de recherche par personne, serveur et salon

`GET /api/messages/search/summary?q=<texte>` exige un Bearer JWT. Le Gateway relaie cette route vers Message-Service sans transformation. `q` est normalisé comme dans la recherche de messages : espaces de bord retirés, 2 à 100 caractères, casse ignorée et `%`, `_`, `\` pris littéralement. Un texte invalide répond 400, une session invalide 401.

La réponse contient des comptes complets, indépendants de la pagination des messages :

```json
{
  "directMessages": [{ "conversationId": "dm:<interlocuteur>", "count": 6 }],
  "servers": [{
    "serverId": "<serveur>",
    "count": 8,
    "channels": [{ "conversationId": "room:<salon>", "count": 8 }]
  }]
}
```

Les deux sens d'un DM sont additionnés pour l'interlocuteur de l'utilisateur authentifié. Les serveurs additionnent seulement les salons lisibles fournis par Room-Service; aucun salon inaccessible n'est exposé. Une panne de Room-Service échoue en 503, sans résumé partiel. Les groupes sans correspondance sont absents. Les personnes, serveurs et salons sont classés par nombre décroissant, puis identifiant en cas d'égalité. Deux serveurs de même nom restent distincts grâce à `serverId`.

Les comptes sont calculés par agrégation PostgreSQL, sans transférer le contenu des messages. Le client résout séparément les pseudos et les noms des serveurs / salons avec les routes existantes. L'endpoint renvoie tous les groupes; le bouton « Voir plus » du mobile déplie huit groupes supplémentaires dans une catégorie, sans parcourir les messages pour compter.

Parcours mobile : recherche générale → personne → recherche dans le DM; recherche générale → serveur → salons avec comptes → recherche dans le salon. Le texte recherché est conservé à chaque étape. La page de messages reste celle de la recherche directe, avec `/api/messages/search?q=...&conversationId=...` et sa pagination par curseur. Les droits sont donc revérifiés lors de l'ouverture de chaque page. Les comptes peuvent évoluer si des messages changent entre deux pages.

Déploiement : reconstruire Message-Service pour exposer cette route avant d'utiliser le nouveau client mobile. Aucun changement de schéma ni de configuration de routage du Gateway n'est requis. Le client Electron conserve son parcours actuel.
