# Cas de Tests & Résultats 🧪

Ce document décrit les suites de tests automatisées disponibles pour valider les clusters.

## 📊 Rapports de Test

Tous les rapports (Galera, Réplication, Performance Sysbench et HAProxy) sont centralisés dans le répertoire `reports/` :

- **Markdown (.md)** : Pour une consultation rapide ou archivage.
- **HTML (.html)** : Rapports interactifs premium (Tailwind CSS, Chart.js).

Les fichiers sont nommés selon le format : `test_<type>_<timestamp>.[md|html]`.

---

## 🏗️ Informations sur l'Architecture

Pour plus de détails sur la topologie du cluster, consultez la **[Documentation de l'Architecture](architecture_fr.md)**.

## 🌐 1. Suite de Tests Galera (`test_galera.sh`)

### Cas de Tests

1. **Connectivité & Statut** : Vérifie que les 3 nœuds sont UP, `wsrep_ready=ON` et que la taille du cluster est de 3.
2. **Réplication Synchrone** :
   - Écriture sur le Nœud 1 -> Lecture sur le Nœud 2 et le Nœud 3.
   - Écriture sur le Nœud 3 -> Lecture sur le Nœud 1.
3. **Cohérence de l'Auto-incrément** : Garantit que chaque nœud utilise un décalage (offset) différent pour éviter les collisions d'ID.
4. **Conflit de Certification (Verrouillage Optimiste)** : Simule des mises à jour simultanées sur la même ligne via différents nœuds pour déclencher un interblocage (deadlock) ou un échec de certification.
5. **Réplication du DDL** : Exécute un `ALTER TABLE` sur un nœud et vérifie les changements de schéma sur les autres.
6. **Contrainte de Clé Unique** : Vérifie que les erreurs de doublon sont correctement propagées et gérées.
7. **Vérification de la Configuration** : Valide que le **Performance Schema** et le **Slow Query Log** sont actifs.
8. **Audit du Fournisseur Galera** : Compare les `wsrep_provider_options` actuelles avec les meilleures pratiques.
9. **Expiration SSL** : Vérifie si les certificats expirent dans moins de 30 jours.

### Résultats Types

```text
✅ Node at port 3511 is UP (Ready: ON, Cluster Size: 3, State: Synced, SSL: TLS_AES_128_GCM_SHA256, GTID: 1)
✅ Node 2 received data correctly
✅ Node 1: Column 'new_col' exists
✅ Node 2 correctly rejected duplicate entry
```

---

## 🔄 2. Suite de Tests de Réplication (`test_repli.sh`)

### Cas de Tests

1. **Connectivité & SSL** : Vérifie si le Maître et les deux Esclaves sont joignables et rapporte le statut SSL.
2. **Vérification de la Topologie** : Affiche `SHOW MASTER STATUS` et `SHOW SLAVE STATUS` (threads IO/SQL).
3. **Réplication des Données** :
   - Création BDD/Table sur le Maître.
   - Écriture de données de test sur le Maître.
   - Vérification de la présence des données sur l'Esclave 1 et l'Esclave 2 après un court délai.

### Résultats Types

```text
✅ Port 3411 is UP (SSL: TLS_AES_128_GCM_SHA256)
✅ Slave 1 received: Hello from Master at Mon Jan  5 08:30:00 UTC 2026
```

---

## 🏎️ 3. Tests de Performance (Sysbench)

Exécutés via `test_perf_galera.sh` ou `test_perf_repli.sh`.

- **Sortie** : Génère un rapport HTML de haute qualité (ex : `test_perf_galera.html`).
- **Métriques** : TPS (Transactions par seconde), Latence (95ème percentile), et taux d'erreurs.

---

## 🔵 4. Validation HAProxy (`test_haproxy_galera.sh`)

### Cas de Tests

1. **Santé du Backend** : Vérifie l'état (UP/DOWN) de chaque nœud MariaDB via l'interface API/Stats de HAProxy.
2. **Benchmark de Latence** : Compare la latence moyenne d'une requête via le Load Balancer par rapport à une connexion directe sur un nœud.
3. **Détection de Persistance** : Identifie si HAProxy est configuré en Round-Robin pur ou avec des sessions persistantes (sticky).
4. **Simulation de Failover** :
   - Arrêt réel d'un conteneur MariaDB (`docker stop`).
   - Vérification de la continuité des requêtes SQL pendant la panne.
   - Redémarrage automatique du nœud.

### Rapports Premium

Comme pour les autres tests, cette suite génère un rapport HTML élégant montrant l'overhead de performance et les statistiques de bascule.
