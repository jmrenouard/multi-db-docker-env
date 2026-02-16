# Index de la Documentation MariaDB 📚

<p align="center">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="50" height="50">
  <img src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/percona.svg" alt="Percona" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefik/traefik-original.svg" alt="Traefik" width="50" height="50">
</p>

Bienvenue dans la documentation de l'environnement Docker MariaDB. Cet index fournit une vue d'ensemble structurée de tous les guides et références techniques disponibles.

---

## 📋 Table des Matières

1. [Documentation Centrale](#-documentation-centrale)
2. [Gouvernance & Orchestration](#-gouvernance--orchestration)
3. [Matrice Standalone](#-matrice-standalone)
4. [Gestion & Automatisation](#-gestion--automatisation)
5. [Réplication & Galera](#-réplication--galera)
6. [Tests & Performance](#-tests--performance)

---

## 🚀 Documentation Centrale

| Document | Description |
| --- | --- |
| **[README Principal](../README_fr.md)** | Présentation, démarrage rapide, instructions de build et utilisation de base. |
| **[Architecture](architecture.md)** | Topologie globale, schéma réseau et schémas Mermaid détaillés. |

## 🏛️ Gouvernance & Orchestration

| Document | Description |
| --- | ---|
| **[Constitution](../.agent/rules/00_constitution.md)** | Source unique de vérité pour les principes du projet et l'autorité opérationnelle. |
| **[Super Manager](../.agent/workflows/go-agent.md)** | Protocole d'orchestration pour coordonner les compétences, règles et workflows. |

## 🐬 Matrice Standalone

| Document | Description |
| --- | --- |
| **[Environnements Standalone](tests_fr.md#-00-matrice-standalone-niveau-t2)** | Aperçu des moteurs standalone supportés (MySQL, MariaDB, Percona, PostgreSQL). |
| **[Support PostgreSQL](postgresql_support_fr.md)** | Guide détaillé pour l'intégration de PostgreSQL 16 et 17. |

## 🛠️ Gestion & Automatisation

| Document | Description |
| --- | --- |
| **[Référence Makefile](makefile_fr.md)** | Détail de toutes les commandes `make` pour le déploiement et la maintenance. |
| **[Scripts Utilitaires](scripts.md)** | Approfondissement des scripts de sauvegarde, restauration, sécurité (SSL) et setup. |

## 🔄 Réplication & Galera

| Document | Description |
| --- | --- |
| **[Bootstrap Galera](galera_bootstrap.md)** | Guide étape par étape pour initialiser les clusters Galera. |
| **[Configuration Réplication](replication_setup.md)** | Comment configurer et automatiser la réplication Maître/Esclave. |
| **[SSL & Sécurité](replication_ssl.md)** | Configuration SSL pour les connexions chiffrées. |

## 🧪 Tests & Performance

| Document | Description |
| --- | --- |
| **[Cas de Test](tests_fr.md)** | Descriptions des suites de tests, résultats attendus et rapports. |

---

*Note : La version originale de cette documentation est en anglais. Voir [INDEX.md](INDEX.md).*
