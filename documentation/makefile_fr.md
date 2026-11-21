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
| `make build-image` / `gen-ssl` / `gen-profiles` / `clean-data` | Construit `mariadb_ssh:004`, génère SSL/profils, ou purge les données locales. |

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
> **Cibles EOL Décommissionnées** : Les anciennes cibles (`mysql57`, `mysql80`, `mysql96`, `mariadb106`, `percona80`) affichent la date officielle de fin de vie et la cible de remplacement recommandée, puis retournent `exit 1`. Voir [supported_products_fr.md](supported_products_fr.md#versions-décommissionnées-fin-de-vie--eol).

## 🌐 Commandes Cluster Galera

| Commande | Description |
| :--- | :--- |
| `make up-galera` / `make galera-up` | Démarre les nœuds Galera et HAProxy. |
| `make bootstrap-galera`| Bootstrap séquentiel d'un nouveau cluster. |
| `make down-galera` / `make galera-down` | Arrête le cluster Galera. |
| `make galera-status` / `galera-logs` | Statut WSREP et logs temps réel Galera. |
| `make test-galera` | Lance la suite de tests Galera. |

## 🔄 Commandes Cluster Réplication

| Commande | Description |
| :--- | :--- |
| `make up-repli` / `make repli-up` | Démarre les nœuds de réplication et HAProxy. |
| `make setup-repli` | Configure la relation Maître/Esclave. |
| `make down-repli` / `make repli-down` | Arrête le cluster de réplication. |
| `make repli-status` / `repli-logs` | Statut GTID et logs temps réel Réplication. |
| `make test-repli` | Lance la suite de tests de réplication. |

## 🐘 Piles PostgreSQL Compose (13 Topologies)

Les 13 piles (`pg17-baseline`, `pg-streaming`, `pg-logical`, `pg-birep`, `pgedge`, `bucardo`, `citus`, `cockroach`, `yugabyte`, `pg18-streaming`, `pg18-logical`, `pg18-birep`, `yt-cluster`) exposent `make up-<pile>`, `make setup-<pile>`, `make test-<pile>` et `make down-<pile>` ainsi que `<pile>-{up,down,status,logs,ps,test}`.

> **Astuce** : Utilisez `NODE=2` ou `NODE=3` (ex: `make logs-error-galera NODE=2`) pour cibler un nœud spécifique. Le défaut est le Nœud 1.
