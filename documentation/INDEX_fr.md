# Index de la Documentation MariaDB 📚

Bienvenue dans la documentation de l'environnement Docker MariaDB. Cet index fournit une vue d'ensemble structurée de tous les guides et références techniques disponibles.

---

## 📋 Table des Matières

- [Index de la Documentation MariaDB 📚](#index-de-la-documentation-mariadb-)
  - [📋 Table des Matières](#-table-des-matières)
  - [🚀 Documentation de Base](#-documentation-de-base)
  - [🛠️ Gestion \& Automatisation](#️-gestion--automatisation)
  - [🔄 Réplication \& Galera](#-réplication--galera)
  - [🧪 Tests \& Performance](#-tests--performance)
  - [🔗 Aperçu de la Réplication MariaDB](#-aperçu-de-la-réplication-mariadb)

---

## 🚀 Documentation de Base

| Document | Description |
| --- | --- |
| **[README Principal](../README_fr.md)** | Présentation générale, démarrage rapide, instructions de build et utilisation de base. |
| **[Architecture](architecture_fr.md)** | Topologie globale, plan réseau et schémas Mermaid détaillés. |

## 🛠️ Gestion & Automatisation

| Document | Description |
| --- | --- |
| **[Référence du Makefile](makefile_fr.md)** | Détail de toutes les commandes `make` pour le déploiement et la maintenance automatisés. |
| **[Scripts Utilitaires](scripts_fr.md)** | Guide approfondi des scripts de sauvegarde, restauration, sécurité (SSL) et installation. |

## 🔄 Réplication & Galera

| Document | Description |
| --- | --- |
| **[Bootstrap Galera](galera_bootstrap_fr.md)** | Guide étape par étape pour l'initialisation et l'extension des clusters Galera. |
| **[Installation de la Réplication](replication_setup_fr.md)** | Comment configurer et automatiser la réplication Maître/Esclave. |
| **[SSL & Sécurité](replication_ssl_fr.md)** | Configuration du SSL pour les connexions chiffrées et la réplication sécurisée. |

## 🧪 Tests & Performance

| Document | Description |
| --- | --- |
| **[Cas de Tests](tests_fr.md)** | Descriptions des tests fonctionnels automatisés, résultats attendus et détails des rapports. |

---

## 🔗 Aperçu de la Réplication MariaDB

L'installation de la Réplication dans ce projet implémente une architecture traditionnelle **Maître/Esclave**, optimisée pour les besoins de production modernes :

- **Basée sur le GTID** : Utilise les identifiants de transactions globaux (GTID) pour faciliter la promotion des esclaves et assurer une cohérence robuste.
- **Chiffrement SSL** : Tout le trafic de réplication entre le maître et les esclaves est entièrement chiffré.
- **Installation Automatisée** : La commande `make setup-repli` automatise l'ensemble du processus (création des utilisateurs, distribution des certificats SSL et mise en relation).
- **Esclaves en Lecture Seule** : Les esclaves sont configurés automatiquement en mode `read-only` pour éviter les dérives de données.
- **Protocole Proxy** : Préparé pour l'intégration de HAProxy afin de gérer la répartition intelligente des lectures/écritures.

---

*Note : La plupart des documents sont également disponibles en anglais. Voir [INDEX.md](INDEX.md).*
