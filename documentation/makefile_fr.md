# Référence Makefile 🛠️

Le `Makefile` est le point d'entrée principal pour la gestion des environnements de base de données (Standalone, Galera et Réplication).

## 🛠️ Commandes Globales

| Commande | Description |
| :--- | :--- |
| `make stop` | 🛑 Arrête et supprime tous les conteneurs et réseaux. |
| `make start` | 🚀 Démarre le service par défaut (MariaDB 11.4). |
| `make status` | 📊 Affiche l'état des conteneurs actifs. |
| `make info` | ℹ️ Fournit des informations sur le service DB actif. |
| `make logs` | 📄 Affiche les logs du service actif. |
| `make mycnf` | 🔑 Génère le fichier `.my.cnf` pour les connexions sans mot de passe. |
| `make client` | 💻 Lance un client MySQL sur la base active. |
| `make verify` | ✅ Valide l'intégrité de l'environnement (`test-config`). |
| `make help` | Affiche l'aide pour toutes les tâches disponibles. |
| `make build-image` | Construit l'image de base `mariadb_ssh:004`. |
| `make gen-ssl` | Génère les certificats SSL dans le répertoire `ssl/`. |
| `make gen-profiles` | Génère les profils shell pour un accès rapide. |
| `make clean-data` | **DANGER** : Supprime TOUTES les données, sauvegardes et certificats. |

## 🐬 Commandes Standalone

| Commande | Description |
| :--- | :--- |
| `make mysql96` | Démarre MySQL 9.6 |
| `make mysql84` | Démarre MySQL 8.4 |
| `make mysql80` | Démarre MySQL 8.0 |
| `make mysql57` | Démarre MySQL 5.7 |
| `make mariadb118` | Démarre MariaDB 11.8 |
| `make mariadb114` | Démarre MariaDB 11.4 |
| `make mariadb1011`| Démarre MariaDB 10.11 |
| `make mariadb106` | Démarre MariaDB 10.6 |
| `make percona80` | Démarre Percona 8.0 |

## 🌐 Commandes Cluster Galera

| Commande | Description |
| :--- | :--- |
| `make up-galera` | Démarre les nœuds Galera et HAProxy. |
| `make bootstrap-galera`| Bootstrap séquentiel d'un nouveau cluster. |
| `make down-galera` | Arrête le cluster Galera. |
| `make test-galera` | Lance la suite de tests Galera. |

## 🔄 Commandes Cluster Réplication

| Commande | Description |
| :--- | :--- |
| `make up-repli` | Démarre les nœuds de réplication et HAProxy. |
| `make setup-repli` | Configure la relation Maître/Esclave. |
| `make down-repli` | Arrête le cluster de réplication. |
| `make test-repli` | Lance la suite de tests de réplication. |

> **Astuce** : Utilisez `NODE=2` ou `NODE=3` (ex: `make logs-error-galera NODE=2`) pour cibler un nœud spécifique. Le défaut est le Nœud 1.
