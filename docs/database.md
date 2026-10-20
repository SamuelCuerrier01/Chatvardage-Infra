# Bases de données

## Principe
Infra lance une seule instance PostgreSQL et crée quatre bases logiques avec un propriétaire distinct. **Les bases sont vides après l'initialisation d'Infra.** Chaque microservice applique ensuite ses propres migrations.

Chaque base est fermée aux autres comptes (`REVOKE CONNECT, TEMPORARY ... FROM PUBLIC`) : le compte d'un service ne peut ouvrir que **sa** base (par défaut, PostgreSQL laisse tout compte se connecter à toutes les bases). Seuls le propriétaire et le superutilisateur (Adminer) y accèdent. Comme tout le script d'initialisation, cela ne s'applique qu'à un volume neuf : sur un volume existant, `docker compose down -v` (efface les données) ou exécuter une fois `REVOKE CONNECT, TEMPORARY ON DATABASE <base> FROM PUBLIC;` pour chaque base en superutilisateur.

| Base | Propriétaire | Schéma métier géré par |
|---|---|---|
| `chatvardage_auth` | `auth_service` | Authentification |
| `chatvardage_rooms` | `room_service` | Room-Service |
| `chatvardage_messages` | `message_service` | Message-Service |
| `chatvardage_config` | `config_service` | User-Config-Service |

Les identifiants d'utilisateurs peuvent être référencés comme chaînes entre domaines, sans clé étrangère SQL entre deux bases de microservices.

## Pourquoi Infra ne crée pas les tables
Les migrations doivent vivre avec le code qui utilise les données. Cela évite deux sources de vérité pour le schéma et les erreurs Prisma `P3005` (« database schema is not empty ») lors du déploiement sur une base neuve.

## Pas de données de démonstration
Infra ne seede aucune donnée, et l'application n'a pas de mode simulé (mock) : toutes les données viennent des microservices. Les seules données créées automatiquement le sont par les migrations des services (par exemple le serveur par défaut et son message de bienvenue).

## Temps réel
PostgreSQL est la source de vérité. Redis Pub/Sub/WebSocket sert à diffuser les événements après persistance réussie. Après reconnexion, le client récupère l'état durable via REST. Les messages privés et de salon sont réels et persistés par Message-Service.

## Schémas métier de référence

Modèles Prisma de chaque service (sans les blocs `generator` et `datasource`). Les migrations SQL des dépôts propriétaires restent exécutables et font autorité (notamment l’index fonctionnel de courriel Auth). Aucune clé étrangère ne traverse les bases.

### Authentification

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-Authentification/tree/main/prisma)

```prisma
model Utilisateur {
  id                 String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  pseudo             String   @unique
  courriel           String   @unique
  mot_de_passe_hache String
  version_auth       Int      @default(0)
  role               String   @default("utilisateur")
  cree_le            DateTime @default(now()) @db.Timestamptz
  modifie_le         DateTime @default(now()) @db.Timestamptz
  sessions           SessionRefresh[]

  @@index([cree_le(sort: Desc)], map: "utilisateurs_cree_le_idx")
  @@map("utilisateurs")
}

model SessionRefresh {
  hache String @id
  famille String @db.Uuid
  utilisateur_id String @db.Uuid
  utilisateur Utilisateur @relation(fields: [utilisateur_id], references: [id], onDelete: Cascade)
  version_auth Int
  expire_le DateTime @default(dbgenerated("(now() + interval '30 days')")) @db.Timestamptz
  consomme Boolean @default(false)
  revoque Boolean @default(false)
  @@index([utilisateur_id], map: "sessions_refresh_utilisateur_id_idx")
  @@index([famille], map: "sessions_refresh_famille_idx")
  @@index([expire_le], map: "sessions_refresh_expire_le_idx")
  @@map("sessions_refresh")
}
```

### Room-Service

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-Room-Service/tree/main/prisma)

```prisma
enum ServerRole {
  membre
  moderateur
}

enum ChannelAccess {
  tous
  moderateurs
}

enum ChannelWrite {
  tous
  moderateurs
}

model Server {
  id          String             @id @default(uuid())
  name        String
  icon        String?
  ownerId     String?
  isPublic    Boolean            @default(false)
  isDefault   Boolean            @default(false)
  createdAt   DateTime           @default(now())
  updatedAt   DateTime           @updatedAt
  members     ServerMember[]
  invitations ServerInvitation[]
  channels    Room[]

  @@index([ownerId])
  @@index([isPublic])
}

model ServerMember {
  serverId String
  userId   String
  role     ServerRole @default(membre)
  joinedAt DateTime   @default(now())
  server   Server     @relation(fields: [serverId], references: [id], onDelete: Cascade)

  @@id([serverId, userId])
  @@index([userId])
}

model ServerInvitation {
  serverId  String
  userId    String
  invitedBy String
  invitedAt DateTime @default(now())
  server    Server   @relation(fields: [serverId], references: [id], onDelete: Cascade)

  @@id([serverId, userId])
  @@index([userId])
}

model Room {
  id          String        @id @default(uuid())
  serverId    String
  name        String
  position    Int           @default(0)
  access      ChannelAccess @default(tous)
  writePolicy ChannelWrite  @default(tous)
  createdBy   String?
  createdAt   DateTime      @default(now())
  updatedAt   DateTime      @updatedAt
  server      Server        @relation(fields: [serverId], references: [id], onDelete: Cascade)

  @@index([serverId, position])
}
```

### Message-Service

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-Message-Service/tree/main/prisma)

```prisma
model PrivateMessage {
  id          String   @id @default(uuid())
  senderId    String
  recipientId String
  content     String
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  deliveredAt DateTime?

  @@index([senderId, recipientId, createdAt])
  @@index([recipientId, senderId, createdAt])
}

model RoomMessage {
  id        String   @id @default(uuid())
  roomId    String
  authorId  String
  content   String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([roomId, createdAt])
}

enum ConversationKind {
  dm
  room
}

model ConversationReadState {
  userId            String
  kind              ConversationKind
  targetId          String
  lastReadAt        DateTime
  lastReadMessageId String?
  updatedAt         DateTime         @updatedAt

  @@id([userId, kind, targetId])
  @@index([kind, targetId])
}
```

### User-Config-Service

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-User-Config-Service/tree/main/prisma)

```prisma
enum Theme {
  sombre
  clair
}

enum Langue {
  fr
  en
}

enum StatutPresence {
  enLigne
  horsLigne
}

enum ModeNotification {
  systeme
  discret
  aucune
}

model ConfigUtilisateur {
  idUtilisateur    String            @id
  alias            String?
  theme            Theme             @default(sombre)
  langue           Langue            @default(fr)
  statutPresence   StatutPresence    @default(horsLigne)
  vuLaDerniereFois DateTime?
  modeNotification ModeNotification  @default(systeme)
  avatar           String?
  creeLe           DateTime          @default(now())
  misAJourLe       DateTime          @default(now()) @updatedAt
}
```
