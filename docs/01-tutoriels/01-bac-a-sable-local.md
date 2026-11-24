# Tutoriel 1 : Bac à sable local

Démarrez une base MySQL 8.4 isolée avec `./mdb`.

## Prérequis

- Docker Engine ou Docker Desktop actif avec Compose v2 et port `3306` libre.

## Étapes

1. Vérifiez Docker, Compose et le réseau local.

```bash
./mdb doctor
./mdb catalog --category standalone
```

Sortie attendue : `./mdb doctor` affiche `OK` pour Docker et Compose.

2. Démarrez MySQL 8.4 et vérifiez l'état sain du conteneur.

```bash
./mdb up mysql84
./mdb status mysql84
```

Sortie attendue : `mysql84` passe à `Up (healthy)`.

3. Ouvrez le client SQL puis arrêtez le lab.

```bash
./mdb client mysql84
./mdb down mysql84
```

## Prochaine étape

Passez au [tutoriel Patroni HA](02-premier-lab-bascule-ha.md) ou à [l'index des guides](../../documentation/INDEX_fr.md).
