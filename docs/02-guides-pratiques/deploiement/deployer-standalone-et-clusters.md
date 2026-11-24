# Déployer les profils autonomes et clusters

## Prérequis

- Vérifiez le démon Docker et Docker Compose v2.
- Libérez les ports cibles (`3306`, `5432`, `27017`).

## Procédure

1. Exécutez la vérification locale avant chaque déploiement.

```bash
./mdb doctor
```

2. Listez les profils actifs pour empêcher les conflits de ports.

```bash
./mdb catalog --all
./mdb status all
```

3. Démarrez une base autonome puis arrêtez ce profil avant Galera.

```bash
./mdb up mariadb114
./mdb down mariadb114
```

4. Démarrez soit le cluster Patroni (`docker-compose-patroni.yml`), soit le cluster Galera (`docker-compose-galera.yml`).

```bash
./mdb up patroni
./mdb down patroni
make bootstrap-galera
```

> [!CAUTION]
> Arrêtez tous les services avant le nettoyage des volumes. La commande `make clean-data` supprime les répertoires de données locaux.

## Vérification

Exécutez `./mdb status all` et `./mdb test patroni --suite`. Vérifiez le statut `healthy` de chaque conteneur.

## Retour arrière

Exécutez `./mdb down all` pour arrêter tous les conteneurs du laboratoire. Consultez [l'index des guides](../../../documentation/INDEX_fr.md).
