# Plan de Test Intégral: Multi-DB Docker Environment

## 🧠 Rationale

L'objectif de ce plan est de garantir la fiabilité architecturale, la cohérence fonctionnelle et les performances de l'ensemble des plateformes et versions supportées par le laboratoire.

---

## 📅 Matrice de Test

| Système DB | Version | Standalone | Galera | Réplication |
| :--- | :--- | :---: | :---: | :---: |
| **MariaDB** | 10.6 | ✅ | ❌ | ❌ |
| **MariaDB** | 10.11 | ✅ | ❌ | ❌ |
| **MariaDB** | 11.4 | ✅ | ❌ | ❌ |
| **MariaDB** | 11.8 (LTS) | ✅ | ✅ | ✅ |
| **MySQL** | 5.7 (Legacy) | ✅ | ❌ | ❌ |
| **MySQL** | 8.0 | ✅ | ❌ | ❌ |
| **MySQL** | 8.4 | ✅ | ❌ | ❌ |
| **MySQL** | 9.6 | ✅ | ❌ | ❌ |
| **Percona Server** | 8.0 | ✅ | ❌ | ❌ |

---

## 🛠️ Suites de Tests (Niveaux de Vérification)

### T1 : Audit d'Orchestration & Gouvernance

* **Commande** : `make test-config`
* **Vérifications** : Structure des répertoires, syntaxe Docker Compose, présence des certificats SSL, génération des profils Shell, cohérence des métadonnées.

### T2 : Cycle de Vie Standalone & Intégrité des Données

* **Commande** : `make test-all`
* **Workflow** :
    1. Provisionnement du conteneur via Traefik.
    2. Injection des jeux de données `employees` et `sakila`.
    3. Vérification du nombre d'enregistrements et de l'intégrité du schéma.
    4. Validation de la connectivité via le proxy inverse Traefik (port 3306).
    5. Nettoyage atomique.

### T3 : Topologie Cluster & Convergence

* **Commandes** : `make test-galera`, `make test-repli`
* **Spécificités Galera** :
  * Synchronisation des nœuds (`Synced`).
  * Validation du quorum (Cluster de 3 nœuds).
  * Cohérence de la séquence globale entre les nœuds.
* **Spécificités Réplication** :
  * Santé des threads IO et SQL (Master/Slave).
  * Cohérence GTID.
  * Respect du mode `read-only` sur les esclaves pour les utilisateurs non-SUPER.

### T4 : Haute Disponibilité & Répartition de Charge

* **Commande** : `make test-lb-galera`
* **Workflow** :
    1. Test de stress de la distribution HAProxy (vérification Round-Robin).
    2. Simulation de panne : Arrêt d'un nœud et vérification de la continuité de service.
    3. Vérification de la terminaison SSL au niveau du proxy.

### T5 : Analyse de Performance (Sysbench)

* **Commandes** : `make test-perf-galera`, `make test-perf-repli`
* **Profils** : `light`, `standard`, `read-only`, `write-only`.
* **Métriques** : TPS (Transactions/sec), Latence P95, Deltas de conflits (WSREP Aborts pour Galera).

---

## 🚀 Stratégie d'Exécution

### 1. Test Rapide (Smoke Test) - Quotidien

```bash
make test-config
make mariadb118  # Cible LTS par excellence
make inject
make info
make stop
```

### 2. Validation Pré-Release (Exhaustif)

```bash
# 1. Gouvernance
make test-config

# 2. Matrice Standalone
make test-all

# 3. Clusters
make full-galera
make full-repli

# 4. Baselines de Performance
make test-perf-galera PROFILE=standard ACTION=run
make test-perf-repli PROFILE=standard ACTION=run
```

---

## 📊 Rapports

Tous les tests génèrent des rapports dans le répertoire `reports/` :
* `reports/config_report.html` (T1)
* `reports/test_galera_*.html` (T3)
* `reports/test_repli_*.html` (T3)
* `reports/test_lb_galera_*.html` (T4)
* `reports/test_perf_*.html` (T5)
