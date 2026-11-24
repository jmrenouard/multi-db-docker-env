# Tutoriel 3 : Lab PostgreSQL multimaître

Exécutez une topologie PostgreSQL 18 bidirectionnelle (`pg18-birep`) et sa suite de tests.

## Prérequis

- `./mdb doctor` valide sans autre conteneur PostgreSQL actif.

## Étapes

1. Démarrez `pg18-birep` et vérifiez les nœuds.

```bash
./mdb up pg18-birep
./mdb status all
```

2. Exécutez la suite de tests puis un benchmark court.

```bash
./mdb test pg18-birep --suite
./mdb bench pg18-birep
```

Sortie attendue : réplication bidirectionnelle valide puis mesure de latence et débit.

3. Arrêtez l'environnement.

```bash
./mdb down pg18-birep
```

## Prochaine étape

Lisez la fiche [réplication multimaître](../../documentation/pg_multimaster_fr.md) ou [l'index des guides](../../documentation/INDEX_fr.md).
