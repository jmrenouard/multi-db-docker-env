# Référence CLI unifiée (`./mdb`) & Makefile 🛠️

> [!IMPORTANT]
> **`./mdb` (`mdb.cmd` sous Windows) est le point d'entrée unique unifié** pour toutes les opérations. `Makefile`, `interactive_runner.py` et `mysql_docker.py` servent de wrappers de compatibilité et d'helpers historiques déléguant à `./mdb`.

## 🚀 Commandes Unifiées `./mdb`

| Commande | Description |
| :--- | :--- |
| `./mdb help` | Affiche l'aide CLI catégorisée (`--help`, `-h`). |
| `./mdb catalog [--category ...] [--engine ...] [--eol] [--all] [--json]` | Liste les 31 environnements actifs + 5 EOL (`list`, `envs`, `topologies`). |
| `./mdb up <env>` / `./mdb start [env]` | Démarre un profil ou cluster (auto-PKI, rejette EOL, défaut `mariadb114`). |
| `./mdb setup <env>` | Exécute le script de setup d'une topologie (no-op si superflu). |
| `./mdb down [env\|all]` / `./mdb stop [env]` | Arrête l'environnement ou toutes les piles Compose actives. |
| `./mdb status [env\|all]` / `./mdb info` / `./mdb logs [env]` | Inspecte les conteneurs actifs et les journaux (`--tail N`, `-f`, `--json`). |
| `./mdb client [env]` / `./mdb mycnf` | Shell BDD adaptatif (`mariadb`/`psql`/`mongosh`/etc.) ou sauvegarde `~/.my.cnf.bak` + `~/.my.cnf` (`0600`). |
| `./mdb interactive [-a\|-i] [-l en\|fr]` | Assistant bilingue natif sur tout le catalogue (`alias` : `wizard`). |
| `./mdb lint` / `./mdb test <env> [--suite]` | Valide `.sh` + 21 Compose YAML (`lint`) et exécute les vérifications (`--suite` lance `tests/test_<env>.sh`). |
| `./mdb bench <env>` / `./mdb doctor` | Benchmarks multi-moteurs et diagnostic des dépendances OS/Docker/Go/`.env`/`ssl/`. |
| `./mdb pki <generate\|verify>` / `./mdb report` | PKI x509 native et export de rapports JSON/HTML. |

## 🛠️ Wrappers `Makefile` Globaux

| Commande | Description |
| :--- | :--- |
| `make stop` / `status` / `info` | 🛑 / 📊 / ℹ️ Délèguent à `./mdb stop` / `status` / `info` (scan multi-compose). |
| `make mycnf` / `client` | 🔑 / 💻 Délèguent à `./mdb mycnf` (`~/.my.cnf.bak` `0600`) et `./mdb client` (avertissement si `.env` absent). |
| `make catalog` / `doctor` / `interactive` | 📋 / 🩺 / 🚀 Délèguent à `./mdb catalog`, `doctor` et `interactive` (repli Python). |
| `make lint` / `test` / `verify` | 🔍 / 🧪 / ✅ Délèguent à `./mdb lint` et `test-config`. |
| `make start` / `help` | 🚀 / 📜 Démarre `mariadb114` / affiche `./mdb help` + alias Make. |
| `make build-go` / `test-go` | 🔨 / 🧪 Compile `bin/mdb` et exécute la suite de tests unitaires Go. |
| `make test-all-topologies` / `test-all-report` | 🧪 / 📊 Exécute les tests E2E et agrège les rapports HTML. |
| `make test-failover` / `test-backup-restore` | 🧪 Valide les tests de bascule et de sauvegarde/restauration. |
| `make gen-ssl-all` / `check-ssl-all` | 🔐 Génère et contrôle les certificats TLS de tous les clusters. |
| `make build-image` / `install-client` | Construit `mariadb_ssh:004` ou installe le client MariaDB hôte. |
| `make gen-ssl` / `clean-ssl` | Génère ou supprime les certificats dans `ssl/`. |
| `make renew-ssl-galera` / `renew-ssl-repli` | Régénère et recharge SSL sans arrêt avec `FLUSH SSL`. |
| `make clean-reports` / `gen-profiles` | Purge `reports/` ou génère les profils shell. |
| `make clean-galera` / `clean-repli` | **ATTENTION** : arrête le cluster et supprime données et sauvegardes. |
| `make check-galera` / `check-repli` | 📊 Affiche l'état WSREP Galera ou de réplication. |
| `make test-config` / `full-repli` / `full-galera` | Valide la configuration ou lance le cycle complet cluster. |
| `make clean-data` | **ATTENTION** : supprime toutes les données, sauvegardes et clés SSL. |
| `make inject` / `inject-employees` / `inject-sakila` | 💉 Injecte `employees` ou `sakila` avec détection automatique. |
| `make sync-test-db` | 🔄 Synchronise le sous-module `test_db`. |

ATTENTION : Sauvegardez les sauvegardes requises avant d'exécuter `make clean-data`, `make clean-galera` ou `make clean-repli`. Ces commandes suppriment définitivement toutes les données, sauvegardes et répertoires SSL.

## 🐬 Commandes Standalone

| Commande | Description |
| :--- | :--- |
| `make mysql97` | Démarre MySQL 9.7 LTS |
| `make mysql84` | Démarre MySQL 8.4 LTS |
| `make mariadb123` | Démarre MariaDB 12.3 LTS |
| `make mariadb118` | Démarre MariaDB 11.8 LTS |
| `make mariadb114` | Démarre MariaDB 11.4 LTS |
| `make mariadb1011` | Démarre MariaDB 10.11 LTS |
| `make percona84` | Démarre Percona Server 8.4 LTS |
| `make postgres18` | Démarre PostgreSQL 18 |
| `make postgres17` | Démarre PostgreSQL 17 |
| `make postgres16` | Démarre PostgreSQL 16 |
| `make postgres15` | Démarre PostgreSQL 15 |

> [!NOTE]
> **Cibles EOL Décommissionnées** : Les anciennes cibles (`mysql57`, `mysql80`, `mysql96`, `mariadb106`, `percona80`) affichent la date officielle de fin de vie et la cible de remplacement recommandée, puis retournent `exit 1`. Voir [supported_products_fr.md](supported_products_fr.md#-versions-décommissionnées-fin-de-vie--eol).

## 🌐 Commandes Cluster Galera

| Commande | Description |
| :--- | :--- |
| `make up-galera` / `make galera-up` | Démarre les nœuds Galera et HAProxy. |
| `make bootstrap-galera` | Bootstrap séquentiel d'un nouveau cluster. |
| `make emergency-galera` | Démarre un nœud Galera isolé (`make emergency-galera NODE=1`). |
| `make down-galera` / `make galera-down` | Arrête et supprime le cluster Galera. |
| `make galera-status` / `make check-galera` | Affiche la santé et le statut WSREP Galera. |
| `make logs-galera` / `make galera-logs` | Affiche les logs en temps réel du cluster Galera. |
| `make test-galera` / `make test-lb-galera` | Exécute la suite Galera et la validation HAProxy. |
| `make backup-galera` / `make restore-galera` | Exécute ou restaure une sauvegarde SQL logique. |
| `make backup-phys-galera` / `make restore-phys-galera` | Exécute ou restaure une sauvegarde physique MariaBackup. |
| `make test-perf-galera` | Lance Sysbench (`make test-perf-galera PROFILE=light ACTION=run`). |

## 💉 Injection de Données

Ces commandes déploient un cluster propre puis injectent les jeux de données d'exemple.

| Commande | Description |
| :--- | :--- |
| `make inject-data` | 💉 Injecte `employees` ou `sakila` sur un service actif. |
| `make test-all` | 🧪 Teste toutes les versions DB standalone actives. |
| `make sync-test-db` | 🔄 Synchronise le sous-module `test_db`. |
| `make inject-employee-galera` / `inject-sakila-galera` | Réinitialise Galera puis injecte `employees` ou `sakila`. |
| `make inject-employee-repli` / `inject-sakila-repli` | Réinitialise Réplication puis injecte `employees` ou `sakila`. |

## 🔄 Commandes Cluster Réplication

| Commande | Description |
| :--- | :--- |
| `make up-repli` / `make repli-up` | Démarre les nœuds de réplication et HAProxy. |
| `make setup-repli` | Configure la relation Maître/Esclave. |
| `make emergency-repli` | Démarre un nœud isolé (`make emergency-repli NODE=1`). |
| `make down-repli` / `make repli-down` | Arrête le cluster de réplication. |
| `make repli-status` / `make check-repli` | Affiche le statut GTID des esclaves. |
| `make logs-repli` / `make repli-logs` | Suit les logs temps réel du cluster Réplication. |
| `make test-repli` | Lance la suite de tests de réplication. |
| `make backup-repli` / `make restore-repli` | Exécute ou restaure une sauvegarde SQL logique. |
| `make backup-phys-repli` / `make restore-phys-repli` | Exécute ou restaure une sauvegarde physique MariaBackup. |
| `make test-perf-repli` | Lance Sysbench (`make test-perf-repli PROFILE=light ACTION=run`). |

## 🔍 Dépannage & Logs

Utilisez ces cibles pour lire les journaux sans appeler `docker compose logs`.

| Commande | Description |
| :--- | :--- |
| `make logs-error-galera` / `follow-error-galera` | Lit ou suit le journal d'erreurs Galera. |
| `make logs-slow-galera` / `follow-slow-galera` | Lit ou suit le journal des requêtes lentes Galera. |
| `make logs-error-repli` / `follow-error-repli` | Lit ou suit le journal d'erreurs Réplication. |
| `make logs-slow-repli` / `follow-slow-repli` | Lit ou suit le journal des requêtes lentes Réplication. |

> **Astuce** : Utilisez `NODE=2` ou `NODE=3` (exemple : `make logs-error-galera NODE=2`) pour cibler un nœud. Le défaut est le Nœud 1.

## 🐘 Commandes Cluster Patroni PostgreSQL HA

| Commande | Description |
| :--- | :--- |
| `make patroni-up` / `patroni-down` | Démarre ou arrête le cluster PostgreSQL 17 + ETCD + HAProxy. |
| `make patroni-status` / `patroni-ps` | Affiche l'état Patroni avec `patronictl` ou la liste des conteneurs. |
| `make patroni-logs` / `test-patroni` | Suit les logs temps réel ou lance la suite fonctionnelle Patroni. |

## 🐘 Commandes Cluster PgPool-II

| Commande | Description |
| :--- | :--- |
| `make pgpool-up` / `pgpool-down` | Démarre ou arrête le cluster PostgreSQL 17 + PgPool-II. |
| `make pgpool-status` / `pgpool-ps` | Affiche `SHOW pool_nodes` ou les conteneurs actifs. |
| `make pgpool-logs` / `test-pgpool` | Suit les logs temps réel ou lance la suite fonctionnelle PgPool-II. |

## 🐬 Commandes MySQL InnoDB Cluster

| Commande | Description |
| :--- | :--- |
| `make innodb-up` / `innodb-down` | Démarre ou arrête InnoDB Cluster (MySQL 8.4 LTS + HAProxy). |
| `make innodb-status` / `innodb-ps` | Affiche le statut Group Replication ou les conteneurs actifs. |
| `make innodb-logs` / `test-innodb` | Suit les logs temps réel ou lance la suite fonctionnelle InnoDB. |

## 🍃 Commandes MongoDB ReplicaSet

| Commande | Description |
| :--- | :--- |
| `make mongo-up` / `mongo-down` | Démarre ou arrête MongoDB 7 ReplicaSet (3 nœuds + HAProxy). |
| `make mongo-status` / `test-mongo` / `test-perf-mongo` | Affiche l'état MongoDB 7, teste le ReplicaSet ou lance le benchmark. |
| `make mongo8-up` / `mongo8-down` | Démarre ou arrête MongoDB 8 ReplicaSet (3 nœuds + HAProxy). |
| `make mongo8-status` / `test-mongo8` | Affiche l'état et exécute les tests fonctionnels MongoDB 8. |

## 🔍 Commandes d'Audit MySQLTuner

| Commande | Description |
| :--- | :--- |
| `make mysqltuner-galera` | Exécute l'audit MySQLTuner sur Galera Cluster. |
| `make mysqltuner-innodb` | Exécute l'audit MySQLTuner sur InnoDB Cluster. |
| `make mysqltuner-repli` | Exécute l'audit MySQLTuner sur MariaDB Réplication. |
| `make mysqltuner-all` | Exécute l'audit MySQLTuner sur toutes les topologies HA. |

## 🐘 Piles PostgreSQL Compose (13 Topologies)

Les 13 piles PostgreSQL Compose fournissent les cibles `<pile>-*` et les wrappers `up-`, `setup-`, `test-` et `down-`. Piles : `pg17-baseline`, `pg-streaming`, `pg-logical`, `pg-birep`, `pgedge`, `bucardo`, `citus`, `cockroach`, `yugabyte`, `pg18-streaming`, `pg18-logical`, `pg18-birep` et `yt-cluster`.

| Modèle de Commande | Description |
| :--- | :--- |
| `make <pile>-up` / `make <pile>-down` | Démarre (+ setup) ou arrête la topologie et ses volumes. |
| `make up-<pile>` / `setup-<pile>` / `down-<pile>` | Étapes séparées (exemple : `make up-yt-cluster && make setup-yt-cluster`). |
| `make <pile>-status` / `<pile>-ps` / `<pile>-logs` | Inspecte la santé du cluster, les conteneurs ou les logs. |
| `make test-<pile>` (alias `<pile>-test`) | Exécute la suite fonctionnelle (`./mdb test <pile> --suite`). |
| `make test-pg-extended` | Exécute la matrice étendue T11-T18 sur les topologies PostgreSQL. |
| `make bench-pg-multimaster` / `bench-pg-v2` / `bench-pg18` / `bench-yt-cluster` | Lance les campagnes V1, V2, PG 18.6 et YT Cluster 1.21.3. |

> Consultez [pg_multimaster_fr.md](pg_multimaster_fr.md) pour les ports, la topologie et les paramètres de benchmark.
