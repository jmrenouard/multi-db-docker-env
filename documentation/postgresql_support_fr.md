# Support PostgreSQL 🐘

Ce document décrit l'intégration de PostgreSQL dans l'environnement multi-db-docker-env.

## Versions Supportées

- **PostgreSQL 17** (Dernière version stable)
- **PostgreSQL 16**

## Démarrage Rapide

Pour démarrer une instance PostgreSQL, utilisez les commandes Makefile suivantes :

```bash
# Démarrer PostgreSQL 17
make postgres17

# Démarrer PostgreSQL 16
make postgres16
```

## Accès et Connectivité

### Routage Traefik

Tout comme MySQL/MariaDB, PostgreSQL est accessible via le proxy inverse Traefik. Cependant, il utilise un port différent :

- **Hôte** : `localhost`
- **Port** : `5432`
- **Utilisateur** : `postgres`
- **Mot de passe** : Défini par `DB_ROOT_PASSWORD` dans votre fichier `.env`.

### Commandes Makefile Dédiées

| Commande | Description |
| :--- | :--- |
| `make pgpass` | Génère automatiquement un fichier `~/.pgpass` local avec les informations d'identification appropriées pour permettre des connexions sans mot de passe depuis l'hôte. |
| `make pgclient` | Ouvre une session `psql` interactive à l'intérieur du conteneur PostgreSQL actif. |

## Vérification

Vous pouvez vérifier la connectivité via le proxy en utilisant `psql` (si installé sur votre hôte) :

```bash
psql -h localhost -U postgres -p 5432
```

Ou en utilisant la cible de test globale :

```bash
make test-all
```

## Persistence des Données

Les données PostgreSQL sont stockées dans des volumes Docker nommés pour assurer la persistence entre les redémarrages :

- `postgres_17_data`
- `postgres_16_data`

Pour réinitialiser complètement les données, vous devez supprimer ces volumes (`docker volume rm ...`).
