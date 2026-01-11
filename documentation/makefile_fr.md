# Référence du Makefile 🛠️

Le `Makefile` est le point d'entrée principal pour la gestion des clusters Galera et de Réplication.

## 🛠️ Commandes Globales

| Commande | Description |
| :--- | :--- |
| `make help` | Affiche le message d'aide pour toutes les tâches disponibles. |
| `make build-image` | Construit l'image de base `mariadb_ssh:004`. |
| `make install-client` | Installe le client MariaDB sur l'hôte (Ubuntu/Debian). |
| `make gen-ssl` | Génère les certificats SSL dans le répertoire `ssl/`. |
| `make renew-ssl-galera` | **Rotation à chaud** Galera : Régénérer et recharger SSL via `FLUSH SSL`. |
| `make renew-ssl-repli` | **Rotation à chaud** Replication : Régénérer et recharger SSL via `FLUSH SSL`. |
| `make clean-ssl` | Supprimer les certificats générés. |
| `make clean-reports` | Purge tous les rapports de test (`.md` et `.html`) du dossier `reports/`. |
| `make gen-profiles` | Générer des profils shell pour un accès rapide aux conteneurs. |
| `make clean-galera` | Arrêter Galera et supprimer toutes ses données/sauvegardes. |
| `make clean-repli` | Arrêter la Réplication et supprimer toutes ses données/sauvegardes. |
| `make full-repli` | Orchestration complète pour la Réplication : Nettoyage, Lancement, Configuration et Test. |
| `make full-galera` | Orchestration complète pour Galera : Nettoyage, Lancement (Bootstrap) et Test. |
| `make clean-data` | **DANGER** : Supprimer TOUTES les données, sauvegardes et répertoires SSL. |

## 🌐 Commandes pour le Cluster Galera

| Commande | Description |
| :--- | :--- |
| `make up-galera` | Démarre les nœuds du cluster Galera et HAProxy. |
| `make bootstrap-galera`| Initialise séquentiellement un nouveau cluster (assure que le nœud 1 est le primaire). |
| `make down-galera` | Arrête et supprime le cluster Galera. |
| `make logs-galera` | Affiche les logs en temps réel pour le cluster Galera. |
| `make test-galera` | Exécute la suite de tests avancés Galera (Réplication, DDL, Audit, SSL). |
| `make test-lb-galera` | Exécute la suite de validation HAProxy (Performance, Failover, Rapports). |
| `make backup-galera` | Effectuer une sauvegarde SQL logique. |
| `make backup-phys-galera`| Effectuer une sauvegarde physique (MariaBackup). |
| `make restore-galera` | Restaurer une sauvegarde SQL logique. |
| `make restore-phys-galera`| Restaurer une sauvegarde physique (MariaBackup). |
| `make test-perf-galera`| Exécuter les benchmarks Sysbench (Usage : `make test-perf-galera PROFILE=light ACTION=run`). |

## 💉 Injection de Données

Ces commandes automatisent le déploiement d'un cluster Galera propre suivi de l'injection de jeux de données exemples.

| Commande | Description |
| :--- | :--- |
| `make clone-test-db` | Cloner ou mettre à jour le dépôt `test_db` depuis GitHub. |
| `make inject-employee-galera`| **Full Cycle** : Réinitialise Galera et injecte la base `employees`. |
| `make inject-sakila-galera`  | **Full Cycle** : Réinitialise Galera et injecte la base `sakila` (MV Edition). |
| `make inject-employee-repli` | **Full Cycle** : Réinitialise la Réplication et injecte `employees`. |
| `make inject-sakila-repli`   | **Full Cycle** : Réinitialise la Réplication et injecte `sakila`. |

## 🔄 Commandes pour le Cluster de Réplication

| Commande | Description |
| :--- | :--- |
| `make up-repli` | Démarre les nœuds du cluster de réplication et HAProxy. |
| `make setup-repli` | Configure la relation Maître/Esclave et la synchronisation initiale. |
| `make down-repli` | Arrête et supprime le cluster de réplication. |
| `make logs-repli` | Affiche les logs en temps réel pour le cluster de réplication. |
| `make test-repli` | Exécute la suite de tests fonctionnels de réplication. |
| `make backup-repli` | Effectuer une sauvegarde SQL logique (sur un esclave). |
| `make backup-phys-repli`| Effectuer une sauvegarde physique (MariaBackup). |
| `make restore-repli` | Restaurer une sauvegarde SQL logique. |
| `make restore-phys-repli`| Restaurer une sauvegarde physique (MariaBackup). |
| `make test-perf-repli` | Exécuter les benchmarks Sysbench (Usage : `make test-perf-repli PROFILE=light ACTION=run`). |

## 🔍 Dépannage & Logs

Ces commandes permettent un accès ciblé aux journaux à l'intérieur des nœuds sans utiliser `docker compose logs`.

| Commande | Description |
| :--- | :--- |
| `make logs-error-galera` | Lire les 100 dernières lignes du log d'erreur MariaDB d'un nœud Galera. |
| `make follow-error-galera`| Suivre (tail -f) le log d'erreur MariaDB d'un nœud Galera. |
| `make logs-slow-galera` | Lire les 100 dernières lignes du slow query log MariaDB d'un nœud Galera. |
| `make follow-slow-galera` | Suivre (tail -f) le slow query log sur un nœud Galera. |
| `make logs-error-repli` | Lire les 100 dernières lignes du log d'erreur MariaDB d'un nœud de Réplication. |
| `make follow-error-repli` | Suivre (tail -f) le log d'erreur sur un nœud de Réplication. |
| `make logs-slow-repli` | Lire les 100 dernières lignes du slow query log MariaDB d'un nœud de Réplication. |
| `make follow-slow-repli` | Suivre (tail -f) le slow query log sur un nœud de Réplication. |

> **Astuce d'expert** : Utilisez `NODE=2` ou `NODE=3` (ex: `make logs-error-galera NODE=2`) pour cibler un nœud spécifique. Le nœud 1 est utilisé par défaut.
