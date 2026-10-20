# Recherche et ouverture directe d’un message

### Recherche : pagination directe depuis un message

Les historiques DM (`GET /api/messages/history/:otherUserId`) et salons (`GET /api/messages/rooms/:roomId/history`) acceptent `around=<messageId>` : une page de 50 messages par défaut commence au message inclus, vers les messages plus anciens. Les pages intermédiaires ne sont pas chargées. `cursor=<messageId>&direction=after` charge ensuite les messages plus récents; `cursor` seul garde la pagination ancienne. Les réponses restent des tableaux chronologiques, avec un ordre stable `(createdAt, id)`. La limite reste bornée de 1 à 100.

`around` et `cursor` sont exclusifs. `direction=after` exige `cursor` et exclut `around`. Le message de départ est recherché dans la conversation autorisée : une cible absente ou étrangère répond 400; l’accès aux salons reste validé par Room-Service. Le Gateway transmet les paramètres sans changer le contrat.

Les clients affichent un indicateur de chargement puis positionnent le message instantanément. Une nouvelle recherche ou une navigation invalide les réponses précédentes. L’historique repart de cette page; les messages plus anciens et plus récents sont chargés à la demande.
