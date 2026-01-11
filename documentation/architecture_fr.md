# Architecture Globale 🏗️

Ce document décrit la topologie réseau et serveur de l'environnement Docker MariaDB.

## 🌐 1. Architecture du Cluster Galera

Le cluster Galera fournit une réplication multi-maître synchrone.

### Topologie Réseau

- **Sous-réseau** : `10.6.0.0/24`
- **Répartiteur de charge (LB)** : `10.6.0.100` (HAProxy)

### Schéma

```mermaid
graph TD
    Client[Client / App] -->|Port 3306| LB[HAProxy LB<br/>10.6.0.100]
    
    subgraph Galera_Cluster [Cluster Galera : 10.6.0.0/24]
        LB -->|LB / Health Check| G1["mariadb-g1 (Nœud 1)<br/>10.6.0.11:3306"]
        LB -->|LB / Health Check| G2["mariadb-g2 (Nœud 2)<br/>10.6.0.12:3306"]
        LB -->|LB / Health Check| G3["mariadb-g3 (Nœud 3)<br/>10.6.0.13:3306"]
        
        G1 <-->|Sync : 4567, 4568, 4444| G2
        G2 <-->|Sync : 4567, 4568, 4444| G3
        G3 <-->|Sync : 4567, 4568, 4444| G1
    end
```

### Détails des Accès

| Nom Logique | Nœud | Rôle | Adresse IP | Port MariaDB | Port SSH |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `mariadb-g1` | Nœud 1 | Multi-Maître | `10.6.0.11` | 3511 | 22001 |
| `mariadb-g2` | Nœud 2 | Multi-Maître | `10.6.0.12` | 3512 | 24002 |
| `mariadb-g3` | Nœud 3 | Multi-Maître | `10.6.0.13` | 3513 | 24003 |
| `haproxy_galera`| LB | Répartiteur | `10.6.0.100` | 3306 | N/A |

---

## 🔄 2. Architecture du Cluster de Réplication

Le cluster de réplication utilise une topologie classique Maître/Esclave avec GTID.

### Topologie Réseau

- **Sous-réseau** : `10.5.0.0/24`
- **Répartiteur de charge (LB)** : `10.5.0.100` (HAProxy)

### Schéma

```mermaid
graph TD
    Client_W[Client Écriture] -->|Port 3406| LB[HAProxy LB<br/>10.5.0.100]
    Client_R[Client Lecture] -->|Port 3407| LB
    
    subgraph Replication_Topology [Réplication : 10.5.0.0/24]
        LB -->|Écritures| M1["mariadb-m1 (Maître)<br/>10.5.0.11:3306"]
        LB -->|Lecture RR| S1["mariadb-s1 (Esclave 1)<br/>10.5.0.12:3306"]
        LB -->|Lecture RR| S2["mariadb-s2 (Esclave 2)<br/>10.5.0.13:3306"]
        
        M1 --"Async (GTID)"--> S1
        M1 --"Async (GTID)"--> S2
    end
```

### Détails des Accès

| Nom Logique | Nœud | Rôle | Adresse IP | Port MariaDB | Port SSH |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `mariadb-m1` | Nœud 1 | Maître | `10.5.0.11` | 3411 | 23001 |
| `mariadb-s1` | Nœud 2 | Esclave 1 | `10.5.0.12` | 3412 | 23002 |
| `mariadb-s2` | Nœud 3 | Esclave 2 | `10.5.0.13` | 3413 | 23003 |
| `haproxy_repli` | LB | Écriture -> M1 | `10.5.0.100` | 3406 | N/A |
| `haproxy_repli` | LB | Lecture -> S1/S2 | `10.5.0.100` | 3407 | N/A |

---

## 📊 3. Supervision & Observabilité

Les deux clusters sont pré-configurés pour l'audit et l'analyse de performance.

### Performance Schema (PFS)

Activé par défaut sur tous les nœuds. Il fournit des données de haute précision sur :

- **Exécution des instructions** : Statistiques détaillées et historique des requêtes.
- **Événements d'attente** : Analyse de la contention des ressources (verrous, IO).
- **Transactions** : Suivi des transactions actuelles et passées.

### Slow Query Logging

Configuré avec un échantillonnage agressif pour minimiser l'impact CPU tout en capturant les requêtes anormales.

- **Seuil** : 2.0 secondes (`long_query_time`).
- **Échantillonnage** : 1 requête sur 5 (`log_slow_rate_limit`).
- **Stockage** : Les journaux sont stockés dans `/var/lib/mysql/*.slow` et accessibles via `make logs-slow-*`.
