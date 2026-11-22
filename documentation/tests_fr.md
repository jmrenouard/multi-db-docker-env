# Cas de Test & Résultats 🧪

Ce guide décrit les suites de tests automatisées pour valider les clusters et les instances standalone.

## 📊 Rapports de Tests

Tous les rapports (Galera, Réplication, Performance Sysbench et HAProxy) se trouvent dans `reports/` :

- **Markdown (.md)** : Pour une lecture CLI rapide ou l'intégration documentaire.
- **HTML (.html)** : Rapports interactifs (Tailwind CSS, Chart.js).

Les noms de fichiers suivent le modèle `test_<type>_<timestamp>.[md|html]`.

---

## 🏗️ Informations d'Architecture

Consultez la **[Documentation d'Architecture](architecture.md)** pour la topologie détaillée des clusters.

---

## 00. Matrice Standalone (Niveau T2)

| MySQL | MariaDB | Percona | PostgreSQL |
| :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="25" height="25"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="25" height="25"> | <img src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/percona.svg" alt="Percona" width="25" height="25"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="25" height="25"> |

Vérifiée le **29-01-2026**, cette suite valide tous les moteurs de base de données standalone.

### Cas de Test

1. **Cycle de Vie du Service** : Démarre chaque service et vérifie la santé des processus.
2. **Intégrité des Données** : Injecte les bases d'exemple `employees` et `sakila`.
3. **Audit d'Authentification** : Vérifie l'application du `DB_ROOT_PASSWORD`.
4. **Connectivité** : Vérifie le routage Traefik vers l'instance active sur le port `3306` (MySQL/MariaDB) ou `5432` (PostgreSQL).

---

## ⚙️ 0. Configuration & Sécurité (`make test-config`)

Valide l'intégrité de l'environnement avant le lancement des conteneurs.

### Cas de Test

1. **Cohérence de l'Environnement** : Vérifie la présence et le contenu de `.env`.
2. **Structure des Répertoires** : Vérifie la présence de `scripts/`, `conf/`, `tests/` et `documentation/`.
3. **Audit SSL** : Valide la chaîne de certificats et la cohérence des clés.

---

## 🌐 1. Suite de Tests Galera (`test_galera.sh`)

### Cas de Test

1. **Connectivité & État** : Vérifie que les 3 nœuds sont UP et synchronisés.
2. **Réplication Synchrone** : Écriture sur un nœud, lecture sur les autres.
3. **Cibles Multi-Maîtres** : Détection des conflits de certification.

---

## 🔄 2. Suite de Tests Réplication (`test_repli.sh`)

### Cas de Test

1. **Topologie** : Vérifie les threads IO/SQL et le statut GTID.
2. **Réplication des Données** : Écriture sur le Maître, vérification sur les Esclaves.

---

## 🏎️ 3. Tests de Performance (Sysbench)

Exécutez `test_perf_galera.sh` ou `test_perf_repli.sh`.
La suite génère des rapports HTML interactifs avec les métriques TPS et Latence.

---

## 🔵 4. Validation HAProxy (`test_haproxy_galera.sh`)

### Cas de Test

- Santé des Backends
- Benchmark de Latence
- Simulation de Failover réel
