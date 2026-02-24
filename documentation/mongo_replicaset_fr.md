# MongoDB ReplicaSet

Cluster MongoDB 7.0 ReplicaSet avec HAProxy pour le routage des connexions.

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                    Réseau : 10.10.0.0/24                      │
│                                                               │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                  │
│  │  mongo1  │   │  mongo2  │   │  mongo3  │                   │
│  │ PRIMAIRE │   │SECONDAIRE│   │SECONDAIRE│                   │
│  │10.10.0.11│   │10.10.0.12│   │10.10.0.13│                   │
│  │  :27411  │   │  :27412  │   │  :27413  │                   │
│  └────┬─────┘   └─────┬────┘   └─────┬────┘                  │
│       │  ReplicaSet    │              │                       │
│       │    rs0         │              │                       │
│       ▼                ▼              ▼                       │
│  ┌─────────────────────────────────────────┐                  │
│  │           HAProxy                       │                  │
│  │    RW :27100  │  Stats :8408           │                   │
│  │         10.10.0.20                      │                  │
│  └─────────────────────────────────────────┘                  │
└───────────────────────────────────────────────────────────────┘
```

### Composants

| Composant | Image | IP | Rôle |
| :--- | :--- | :--- | :--- |
| `mongo1` | `mongo:7.0` | `10.10.0.11` | Primaire (lecture/écriture) |
| `mongo2` | `mongo:7.0` | `10.10.0.12` | Secondaire (lecture seule) |
| `mongo3` | `mongo:7.0` | `10.10.0.13` | Secondaire (lecture seule) |
| `haproxy_mongo` | `haproxy:lts` | `10.10.0.20` | Routage des connexions |

## Démarrage Rapide

### 1. Démarrer le Cluster

```bash
make mongo-up
```

Cette commande :
- Démarre 3 nœuds MongoDB 7.0 + HAProxy
- Attend l'initialisation de tous les nœuds
- Initie le ReplicaSet (`rs.initiate()` avec 3 membres)
- Crée l'utilisateur admin avec les privilèges root
- HAProxy détecte automatiquement les backends

### 2. Vérifier le Statut

```bash
make mongo-status
make mongo-ps
make mongo-logs
```

## Détails de Connexion

| Rôle | Port | Description |
| :--- | :--- | :--- |
| HAProxy RW | `27100` | Trafic d'écriture routé vers le primaire. |
| Stats HAProxy | `8408` | Tableau de bord statistiques HAProxy. |
| MongoDB Nœud 1 (Primaire) | `27411` | Accès direct au nœud primaire. |
| MongoDB Nœud 2 (Secondaire) | `27412` | Accès direct au nœud secondaire 2. |
| MongoDB Nœud 3 (Secondaire) | `27413` | Accès direct au nœud secondaire 3. |

### Exemple de Connexion

```bash
# Via HAProxy (recommandé)
mongosh --host 127.0.0.1 --port 27100 -u root -p "$DB_ROOT_PASSWORD" --authenticationDatabase admin

# Directement au nœud primaire
mongosh --host 127.0.0.1 --port 27411 -u root -p "$DB_ROOT_PASSWORD" --authenticationDatabase admin

# Chaîne de connexion ReplicaSet
mongosh "mongodb://root:$DB_ROOT_PASSWORD@127.0.0.1:27411,127.0.0.1:27412,127.0.0.1:27413/?replicaSet=rs0&authSource=admin"
```

## Configuration ReplicaSet

| Paramètre | Valeur |
| :--- | :--- |
| Nom du ReplicaSet | `rs0` |
| Méthode d'auth | keyFile (interne) |
| Priorité primaire | `2` (mongo1) |
| Priorité secondaire | `1` (mongo2, mongo3) |
| Write Concern | Par défaut (majority) |

## Tests Automatisés

```bash
make test-mongo
```

La suite de tests valide **12 vérifications réparties en 8 groupes** :

| # | Test | Description |
| :--- | :--- | :--- |
| 1 | Statut des Nœuds | 3 nœuds MongoDB UP avec info version |
| 2 | Membres ReplicaSet | 3 membres actifs |
| 3 | HAProxy | Connectivité RW (27100) |
| 4 | Réplication Écriture | Écriture sur primaire, vérification sur secondaires |
| 5 | Isolation Écriture | Les secondaires rejettent les écritures |
| 6 | Opérations CRUD | Insert, update, delete sur le primaire |
| 7 | Cohérence Version | Même version MongoDB sur tous les nœuds |
| 8 | Config RS | Nom du ReplicaSet et nombre de membres |

Rapports générés dans `./reports/` (Markdown + HTML).

## Nettoyage

```bash
make mongo-down
```

Supprime tous les conteneurs, réseaux et volumes pour un redémarrage propre.
