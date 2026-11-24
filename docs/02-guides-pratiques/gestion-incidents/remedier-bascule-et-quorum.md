# Remédier à une bascule ou perte de quorum

## Prérequis

- Identifiez le cluster perturbé (`patroni`, `galera` ou `pg18-birep`).
- Vérifiez l'accès au démon Docker.

## Procédure

1. Relevez l'état des conteneurs et les journaux récents.

```bash
./mdb status all
./mdb logs patroni --tail 50
```

2. Examinez le leader Patroni dans `node1`.

```bash
docker exec node1 patronictl -c /etc/patroni.yml list
```

3. Si le quorum Galera disparaît, vérifiez le numéro de séquence puis réamorcez le cluster.

```bash
make bootstrap-galera
```

> [!CAUTION]
> Identifiez le nœud Galera le plus récent avant tout amorçage. Un amorçage sur un autre nœud supprime les dernières transactions locales.

## Vérification

Exécutez `bash ./tests/test_failover.sh patroni` et `./mdb status patroni`. Vérifiez la présence d'un leader unique.

## Retour arrière

Exécutez `./mdb down patroni` puis `./mdb up patroni`. Consultez [la documentation Patroni](../../../documentation/postgresql_support_fr.md).
