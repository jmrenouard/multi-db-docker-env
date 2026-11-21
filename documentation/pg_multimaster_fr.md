# Topologies PostgreSQL Réplication, Multi-Maître et SQL Distribué

Ce guide présente les douze topologies PostgreSQL de réplication, multi-maître et SQL distribué (`pg-streaming`, `pg-logical`, `pg-birep`, `pg18-streaming`, `pg18-logical`, `pg18-birep`, `yt-cluster`, `pgedge`, `bucardo`, `citus`, `yugabyte`, `cockroach`) ainsi que la référence PostgreSQL 17 (`docker-compose-pg17-baseline.yml`) disponibles dans `multi-db-docker-env` (`v2.4.1`), avec leurs cibles Makefile, commandes CLI Go `mdb` (20 topologies enregistrées), résultats de benchmarks V1/V2/PG18/YT, matrice étendue `T11`–`T18` et modes de défaillance observés.

*Étude comparative complète, graphiques Log10 et explorateur HTML interactif : [jmrenouard/ClusterPostgreSQL-Series](https://github.com/jmrenouard/ClusterPostgreSQL-Series).*

*English version: [pg_multimaster.md](pg_multimaster.md).*

## Matrice d'architecture

| Topologie | Moteur / Image | Nœuds et routage | CAP / PACELC | Ports localhost |
| :--- | :--- | :--- | :--- | :--- |
| **`pg-streaming`** | `postgres:17` (`wal_level=replica`) | 1 Primaire RW + 1 Standby RO (`async` / `sync`) | `AP` (`async`) / `CP` (`sync`) | `15434` (pri), `15435` (stb) |
| **`pg-logical`** | `postgres:17` (`wal_level=logical`) | 1 Publisher + 1 Subscriber (`pub_logical` -> `sub_logical`) | `AP` / `PA-EL` | `15436` (pub), `15437` (sub) |
| **`pg-birep`** | `postgres:17` (`17.11`) + `haproxy:2.9-alpine` | 2 nœuds actif-actif + HAProxy RR | `AP` / `PA-EL` | `15440` (LB), `15441`–`15442`, `15449` (stats) |
| **`pg18-streaming`** | `postgres:18` (`18.6`, AIO `worker`, checksums `on`) | 1 Standalone + 1 Primaire RW + 1 Standby RO (`async`/`sync`) | `AP` (`async`) / `CP` (`sync`) | `15531` (std), `15534` (pri), `15535` (stb) |
| **`pg18-logical`** | `postgres:18` (`18.6`, `substream=p`, `pubgencols=s`) | 1 Publisher + 1 Subscriber (`pub_pg18_logical` -> `sub_pg18_logical`) | `AP` / `PA-EL` | `15536` (pub), `15537` (sub) |
| **`pg18-birep`** | `postgres:18` (`18.6`, `uuidv7()`) + `haproxy:2.9-alpine` | 2 nœuds actif-actif (`origin=none`) + HAProxy RR | `AP` / `PA-EL` | `15540` (LB), `15541`–`15542`, `15549` (stats) |
| **`yt-cluster`** | `dbinvent/yt:1.21.3` (PG `18.7` + `yt_cluster 1.21` / `ytserv`) | 3 nœuds actif-actif (`cc=half` 2-sur-3 XA 2PC par défaut ; async `cc=nodes>=0` optionnel) | `CP` / `PC-EC` (défaut) · `AP` (async) | `5491`–`5493` (`127.0.0.1`) |
| **`pgedge`** | `ghcr.io/pgedge/pgedge-postgres:17-spock5-minimal` | Maillage 3 nœuds Spock 5.0.14 + Snowflake 2.6.1 | `AP` / `PA-EL` | `15450` (LB), `15451`–`15453` |
| **`bucardo`** | `postgres:17` (`plperl`) + Bucardo `5.6.0` | 2 sources PG 17 + daemon Perl asynchrone | `AP` / `PA-EL` | `15461`–`15462` |
| **`citus`** | `citusdata/citus:14.2.0-pg17` | 1 Coordinateur + 2 Workers (8 shards) | `CP` (Coord SPOF / 2PC) | `15490` (coord), `15491`–`15492` |
| **`yugabyte`** | `yugabytedb/yugabyte:2026.1.3.0-b100` | 3 nœuds YSQL/DocDB Raft (`RF=3`) | `CP` / `PC-EC` | `15471`–`15473` (YSQL), `17001` (UI) |
| **`cockroach`** | `cockroachdb/cockroach:v24.3.0` | 3 nœuds Pebble Raft (`RF=3`, `SERIALIZABLE`) | `CP` / `PC-EC` | `15481`–`15483` (SQL), `18081` (UI) |
| **`pg17-baseline`** | `postgres:17` | Standalone (`15431`) + Streaming synchrone (`15432`–`15433`) | `CA` / `PC-EC` | `15431`–`15433` |

## Démarrage rapide (`Makefile` & CLI `mdb`)

```bash
# Cycle de vie via Makefile
make pg-streaming-up && make test-pg-streaming && make pg-streaming-down
make pg-logical-up   && make test-pg-logical   && make pg-logical-down
make pg-birep-up     && make test-pg-birep     && make pg-birep-down
make pg18-streaming-up && make pg18-streaming-test && make pg18-streaming-down
make pg18-logical-up   && make pg18-logical-test   && make pg18-logical-down
make pg18-birep-up     && make pg18-birep-test     && make pg18-birep-down
make yt-cluster-up     && make yt-cluster-test     && make yt-cluster-down
make pgedge-up       && make test-pgedge       && make pgedge-down
make bucardo-up      && make test-bucardo      && make bucardo-down
make citus-up        && make test-citus        && make citus-down
make cockroach-up    && make test-cockroach    && make cockroach-down
make yugabyte-up     && make test-yugabyte     && make yugabyte-down

# Matrice de tests empiriques étendus (T11-T18 sur les 10 topologies PostgreSQL)
make test-pg-extended

# Campagnes séquentielles multi-moteurs (V1 Suites A-F, V2 Suites A-H, PG 18.6 et YT Cluster 1.21.3)
make bench-pg-multimaster
make bench-pg-v2
make bench-pg18
make bench-yt-cluster
make clean-pg18

# Ou via le CLI natif Go mdb (v2.4.1, 20 topologies enregistrées)
./bin/mdb topologies
./bin/mdb up pg18-streaming && ./bin/mdb status pg18-streaming && ./bin/mdb down pg18-streaming
./bin/mdb up pg18-logical   && ./bin/mdb status pg18-logical   && ./bin/mdb down pg18-logical
./bin/mdb up pg18-birep     && ./bin/mdb status pg18-birep     && ./bin/mdb down pg18-birep
./bin/mdb up yt-cluster     && ./bin/mdb status yt-cluster     && ./bin/mdb down yt-cluster
```

## Synthèse des benchmarks empiriques (`PG_SCALE=2`)

Tous les benchmarks ont été exécutés séquentiellement sur le réseau bridge Docker (`multi-db-pgbench-sysbench:latest`, `200 000` lignes `pgbench_accounts`, clé primaire surrogate explicite `hid` sur `pgbench_history`) :
- **Suite A** : `pgbench` mono-nœud RW (`8` clients, `20 s`)
- **Suite B1** : `pgbench` multi-nœuds sur plages disjointes (`2x4` clients, `20 s`)
- **Suite B2** : `pgbench` multi-nœuds avec chevauchement (`2x4` clients, `20 s`)
- **Suite C** : Lectures seules (`16` clients, `20 s`)
- **Suite D** : Contention sur `50` comptes chauds (`8` clients, `15 s`)
- **Suite E** : `sysbench oltp_read_write` (`4` tables x `10 000` lignes, `8` threads, `20 s`)
- **Suite F** : Latence WAN simulée (`tc qdisc replace dev eth0 root netem delay 25ms`, ~50 ms RTT, `15 s`)

| Topologie | A Mono RW (TPS / ms) | B1 Disjoint (TPS / dérive) | B2 Overlap (TPS / dérive) | C RO 16c (TPS) | D Ligne chaude (TPS / dérive) | E Sysbench (TPS / err) | F WAN `25ms` (TPS / p95 ms) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `pg17-standalone` | `866.82` / `9.22` | `920.07` / `0` | `879.01` / `0` | `55 614.16` | `3 128.63` / `0` | `1 129.51` / `112` | N/A |
| `pg17-async-streaming` | `610.15` / `13.09` | `627.39` / `0` | `584.80` / `0` | `45 358.52` | `2 081.26` / `0` | `962.84` / `107` | `599.61` / `34.38` |
| `pg17-sync-streaming` | `409.48` / `19.52` | `407.41` / `0` | `465.22` / `0` | `54 483.07` | `1 370.10` / `0` | `819.36` / `118` | `57.00` / `353.49` |
| `pg17-logical` | `532.38` / `14.99` | `251.63` / `0` | `355.57` / `0` | `42 302.43` | `2 386.93` / `0` | `595.81` / `65` | `654.11` / `30.58` |
| `pg-birep` | `875.91` / `9.12` | `820.09` / `0` | `1 228.60` / `-4 567` (DIV) | `53 072.52` | `1 231.15` / `-71 063` (DIV) | `1 105.32` / `96` | `824.04` / `24.95` |
| `pgedge` (LWW) | `556.06` / `14.37` | `346.95` / `0` | `818.65` / `-66 328` (LU) | `54 124.99` | `2 280.11` / `-278 698` (LU) | `888.56` / `114` | `646.77` / `32.40` |
| `pgedge-delta-apply` | — | — | — | — | `1 837.64` / **`0`** (CONV) | — | — |
| `bucardo` | `735.38` / `10.86` | `1 078.90` / `0` | `1 267.77` / `+123 679` (LU) | `53 731.92` | `1 378.79` / `-531 620` (LU) | `1 232.84` / `112` | `763.23` / `27.26` |
| `citus` | `309.04` / `25.85` | `265.29` / `0` | `312.98` / `0` | `21 324.70` | `1 691.45` / `0` | `189.44` / `9` | `21.67` / `633.96` |
| `yugabyte` | `173.64` / `45.88` | `194.75` / `0` | `170.19` / `0` | `17 150.58` | `832.65` / `0` | `128.24` / `0` | `5.78` / `3 401.33` |
| `cockroach` | `42.08` / `187.60` | `60.35` / `0` (`87` ret) | `74.17` / `0` (`96` ret) | `13 185.54` | `471.61` / `0` | `44.84` / `685` | `10.06` / `2 930.54` |

### Enseignements majeurs

1. **Écritures disjointes vs chevauchement** : Les grappes asynchrones (`pg-birep`, `pgedge`, `bucardo`) convergent avec `0` dérive sur des clés disjointes (`B1`), mais perdent des mises à jour ou divergent dès que les écritures se chevauchent (`B2`, `D`). L'activation de `spock.delta_apply` (`log_old_value=true`) sur `pgedge` conserve `1 837,64 TPS` avec une **dérive strictement nulle (`0`)**.
2. **Impact du RTT WAN** : L'ajout d'un délai unidirectionnel de `25 ms` (`tc netem`) fait chuter les architectures `PC/EC` (`pg17-sync-streaming` `-86,1 %`, `citus` `-93,0 %`, `yugabyte` `-96,7 %`, `cockroach` `-76,1 %`), tandis que les moteurs `PA/EL` valident localement autour de `~10 ms`.

## Limites empiriques et codes `SQLSTATE` observés

- **Tables sans clé primaire (`pgbench_history`)** : `pg-birep` lève `SQLSTATE 55000` sur `UPDATE`/`DELETE` ; `pgedge` classe la table dans `default_insert_only` (les `UPDATE` locaux ne répliquent pas) ; `bucardo` rejette `validate_sync` (`must specify a primary key`) ; `citus` bloque `ADD PRIMARY KEY` / `SERIAL` post-distribution (`0A000`) ; `cockroach` injecte une colonne cachée `rowid`.
- **Collisions `SERIAL` non coordonnées** : `pg-birep` bloque l'apply worker (`23505`, `apply_error_count=1`), alors que `pgedge` (`spock.resolutions=1`) et `bucardo` (`Conflicts=1`) écrasent silencieusement la ligne du nœud 1. Utiliser des séquences décalées, `snowflake` ou `unique_rowid()`.
- **Conflits `UNIQUE(email)` secondaires** : `pg-birep` et `bucardo` stoppent la réplication (`23505`, état `Bad` sur Bucardo) ; `pgedge` (`transdiscard`) journalise `23505` dans `spock.exception_log` et laisse les nœuds diverger ; `citus` interdit `UNIQUE` sans la clé de distribution (`0A000`) ; `yugabyte` et `cockroach` appliquent `23505` globalement.
- **Fonctionnalités PostgreSQL & extensions** :
  - `pg_advisory_lock` et `LISTEN`/`NOTIFY` restent strictement locaux au nœud sur `pg-birep`, `pgedge` et `bucardo`.
  - `yugabyte` : `pg_trgm`, `uuid-ossp`, `vector` et `TEMP TABLE` fonctionnent ; `LISTEN`/`NOTIFY` retourne `0A000` (désactivé).
  - `cockroach` : `CREATE TEMP TABLE` lève `XCEXF` sans `experimental_enable_temp_tables='on'` ; `LISTEN` retourne `42601` ; `40001` (`WriteTooOldError`) impose une boucle de retry client (`685` erreurs ignorées sous `sysbench`).
  - `citus` : l'extension `vector` est absente (`0A000`) dans l'image standard `14.2.0-pg17`.
- **Quorum et particularités d'images** :
  - `yugabyte` et `cockroach` (`RF=3`) tolèrent la perte de `1/3` nœud (`RPO=0`) et gèlent totalement à `2/3` pertes (`cockroach` `57014`, `yugabyte` timeout) jusqu'au retour du quorum.
  - L'image minimale Rocky UBI `pgedge` a exigé le forçage de `output_plugin_libraries=pgoutput,spock_output` (`42501`), `listen_addresses=*` et `host replication` `scram-sha-256`.
  - `bucardo` a nécessité une image `Dockerfile.pg` dédiée avec `postgresql-plperl-17`, `libdbi-perl` et `libdbd-pg-perl` sur les nœuds PostgreSQL pour la fonction `db_getconn` (`PL/PerlU`).

## Matrice étendue V2 (`T11`–`T18`) & Benchmarks V2 (`bench-pg-v2`)

La commande `make test-pg-extended` exécute 8 sondes empiriques avancées sur les 10 topologies :
- **`T11` Ingestion 10 000 lignes** : `pgedge` (`67 406 lignes/s`), `pg-birep` (`65 881 lignes/s`), `pg17-logical` (`52 816 lignes/s`), `cockroach` (`22 079 lignes/s`) ; rattrapage pair `105–417 ms`.
- **`T12` Course UPDATE vs DELETE (Tombstone)** : `pg17-logical` diverge (`pub=upd_n1`, `sub=DELETED`, `UPDATE` ignoré sur ligne absente) ; les moteurs multi-maître asynchrones laissent `DELETE` gagner silencieusement ; le streaming physique rejette l'écriture standby (`25006`) ; le consensus Raft sérialise.
- **`T13` Course FK inter-nœuds** : `bucardo` échoue `0/10` (`23503x10`) sous sa latence de polling (`p50=548.74 ms`) ; le standby physique rejette (`25006x10`) ; logique/mesh/Raft réussissent `10/10`.
- **`T14` Fidélité MD5 (`BYTEA 64 Kio` / JSONB / UTF-8)** : l'image Rocky UBI `pgedge` utilise `SQL_ASCII` par défaut (`chr()` lève `SQLSTATE 54000`, encodage échappé converge `3/3`) ; tous les autres moteurs convergent à l'identique (`md5=00493e3a`).
- **`T15` Latence brute de visibilité (`n=30`)** : `pgedge` `p50=1.16 ms` (`p95=1.63`), `pg-birep` `1.47/2.28 ms`, `pg17-logical` `1.68/2.14 ms`, `pg17-sync-streaming` `1.88/2.74 ms`, `yugabyte` `2.01/2.83 ms`, `cockroach` `4.09/4.98 ms`, `bucardo` `548.74/1275.25 ms`.
- **`T16` Crash `SIGKILL` (RPO) & `T17` Transaction longue** : `RPO=0` sur 9/10 moteurs ; `SIGKILL` sur `citus_worker2` lève `08006` jusqu'au redémarrage ; `SIGKILL` sur le nœud métadonnées `bucardo` laisse l'écriture hors panne non répliquée (`post_restart=20/21`) ; zéro lecture sale en `T17` (`cockroach` `serializable_intent_wait=2.1s`).
- **`T18` Synchronisation des séquences après 50 insertions** : le streaming physique préserve la séquence après `pg_promote()` (`last_value=66|true`, zéro `23505`) ; les séquences globales Raft passent ; `pg17-logical`, `pg-birep`, `pgedge` et `bucardo` laissent la séquence distante à `1|false` -> **`SQLSTATE 23505`** sans `setval()`, séquences décalées ou `snowflake.nextval()`.

La commande `make bench-pg-v2` complète la campagne avec les charges sysbench étendues (`E2` lecture seule, `E3` écriture seule, `E4` point-select culminant à `148 022 TPS` sur `pg17-async-streaming`), `H_append_only_insert` (`3 108 TPS` standalone, `2 987 TPS` YugabyteDB 2 nœuds, `2 207 TPS` pgEdge 2 nœuds), la montée en concurrence (`G_conc_c1..c32`) et le balayage WAN (`10 / 25 / 50 ms`, réduisant `pg17-sync-streaming` `121.75 -> 57.00 -> 25.79 TPS` et `yugabyte` `15.38 -> 5.78 -> 3.06 TPS`). Consulter [ClusterPostgreSQL-Series](https://github.com/jmrenouard/ClusterPostgreSQL-Series) pour les CSV complets, les graphiques Log10 et le tableau de bord interactif.

## Topologies natives PostgreSQL 18.6 & synthèse des benchmarks (`v2.3.0`)

`make bench-pg18` exécute les 18 suites (`A`–`H`, WAN `10/25/50 ms`, concurrence `c1..c32`) sur les 5 topologies natives PG 18.6 (`PG_SCALE=2`) :

| Topologie | `A_rw` TPS | `C_ro` TPS | `E_sb_rw` TPS | `E2_ro` TPS | `E3_wo` TPS | `E4_pt` QPS | `H_append` TPS | `F_wan25` TPS | `T11` lignes/s |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `pg18-standalone` | `784.43` | `42 373.67` | `1 046.67` | `2 000.88` | `1 382.15` | `130 850.73` | `1 956.76` | N/A | `80 108` |
| `pg18-async-streaming` | `558.34` | `47 548.05` | `980.72` | `1 706.90` | `1 809.82` | `126 416.90` | `1 423.07` | `554.93` | `87 903` |
| `pg18-sync-streaming` | `497.94` | `32 258.16` | `767.63` | `1 869.54` | `1 184.57` | `122 246.91` | `1 760.26` | `41.56` | `75 629` |
| `pg18-logical` | `314.26` | `45 862.68` | `1 027.84` | `1 517.26` | `1 582.39` | `131 542.35` | `3 518.49` | `844.10` | `69 827` |
| `pg18-birep` (`uuidv7`) | `514.28` | `42 190.66` | `1 055.55` | `2 053.07` | `1 492.99` | `146 907.74` | `2 066.70` | `747.42` | `70 470` |

- **Arborescence Docker `PGDATA`** : `postgres:18` déplace `PGDATA` vers `/var/lib/postgresql/18/docker` (`VOLUME /var/lib/postgresql`) ; les trois piles Compose PG 18 montent `/var/lib/postgresql` et utilisent `${PGDATA:-/var/lib/postgresql/18/docker}`.
- **AIO `io_method` & Checksums** : défauts `io_method=worker` (`io_workers=3`) et `data_checksums=on`. `io_method=io_uring` échoue avec `Operation not permitted` sous le profil seccomp Docker par défaut ; `worker` réduit le scan séquentiel à froid de `-18,5 %` (`829,4 ms` vs `1018,3 ms` en `sync`).
- **`uuidv7()` natif & 7 compteurs `confl_*`** : `id UUID PRIMARY KEY DEFAULT uuidv7()` réalise `50/50` écritures concurrentes bi-nœuds sans collision (`0` `23505`, `0` inversion B-tree) et `2 066,70 TPS` sur `H_append_only_insert` (`3,30x` vs `pg-birep` PG 17). Les 7 compteurs `pg_stat_subscription_stats` — dont `confl_multiple_unique_conflicts` — sont vérifiés dans `tests/test_pg18_birep.sh`.
- **Séquences logiques reportées à PG 19** : `CREATE SUBSCRIPTION` active `substream=p` par défaut et `publish_generated_columns=stored` fonctionne (`pubgencols=s`), mais `FOR ALL SEQUENCES` et `REFRESH SEQUENCES` lèvent toujours `SQLSTATE 42601` en PG 18.6 (séquences abonnées à `1|false` -> `23505` après bascule).

## Pile actif-actif YT Cluster 1.21.3 (PostgreSQL 18.7, `v2.4.1`)

`docker-compose-yt-cluster.yml` déploie un cluster 3 nœuds `dbinvent/yt:1.21.3` (`yt1`/`yt2`/`yt3` sur `127.0.0.1:5491-5493:5432`) associant PostgreSQL 18.7 non modifié (`io_method=worker`, `data_checksums=on`), l'extension `yt_cluster 1.21` et le coordinateur Rust local `ytserv`.

- **Matrice complète 18 suites Sync-2PC (`cc=half`) vs Async (`cc=nodes>=0`)** : `yt_info('d')` active par défaut `def_cluster_commit={"at_least":0,"mode":1}` (`half` = 2PC XA synchrone 2-sur-3, `NO_SC`, `min_cluster_size=2`). Sous `PG_SCALE=2` (`make bench-yt-cluster`), `yt-cluster` atteint `A_rw=20,63`, `B1=36,14`, `B2_overlap=10,69`, `C_ro=48 787,74`, `D_hot=67,76` (`0` dérive), `E_sb=28,48`, `E2=2 122,68`, `E3=26,43`, `E4_pt=165 472,75`, `H_append=110,53` (`uuidv7()`), `F_wan=4,81/2,25/1,41` et `G_conc=28,07..4,60 TPS` (`T11=86 lignes/s`). En mode asynchrone `cc=nodes>=0` (`yt-cluster-async`), les débits progressent sur les 18 suites : `A_rw=41,45`, `B1=88,19`, `B2_overlap=55,03`, `C_ro=40 774,49`, `D_hot=163,01` (`0` dérive), `E_sb=124,05`, `E2=2 083,85`, `E3=133,55`, `E4_pt=177 442,88`, `H_append=224,93`, `F_wan` non-Leader `=8,47/4,78/2,90` et `G_conc=53,94..91,68..44,20 TPS`.
- **Limites vérifiées, quarantaine `recon` & réversibilité (`make yt-cluster-test`)** : l'arbitrage de conflits garantit une dérive nulle (`55409` sur mises à jour concurrentes / `SERIAL`, `40001` sur `UNIQUE`) ; en mode asynchrone (`cc=nodes>=0`), la réutilisation immédiate de `sbtest1..4` après écritures conflictuelles peut déclencher `SQLSTATE 55000` (`yt_synchronize: recon: row [...] is blocked` en attente d'audit), d'où l'isolation de la préparation `sbtest` par suite destructive ; le rollback de `SAVEPOINT` sur écritures échoue au `COMMIT` (`0A000`) ; la perte de `2/3` nœuds bloque les écritures (`57P03`, `YT-E1852`) ; `T16` `SIGKILL` préserve `RPO=0` (`20/20`, réserve sur fichier résiduel `.s.YT.5432.pid` `YT-E1104`) ; `T_REVERT` confirme `DROP EXTENSION yt_cluster CASCADE;` sans perte de données (`5/5` -> `6/6`).
