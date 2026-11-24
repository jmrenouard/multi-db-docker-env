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

2. Exécutez la suite de tests puis arrêtez la pile avant le benchmark.

```bash
./mdb test pg18-birep --suite
./mdb down pg18-birep
```

Sortie attendue : la réplication bidirectionnelle réussit avant l'arrêt des nœuds.

3. Lancez le benchmark isolé puis vérifiez l'absence de conteneur résiduel.

```bash
./mdb bench pg18-birep
./mdb status all
```

Sortie attendue : `./mdb bench` gère le cycle de vie complet et affiche latence et débit.

## Prochaine étape

Lisez la fiche [réplication multimaître](../../documentation/pg_multimaster_fr.md) ou le [guide d'exploitation](../02-guides-pratiques/exploitation/sauvegarder-restaurer-et-changer-moteur.md).
