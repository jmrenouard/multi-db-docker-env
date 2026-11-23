# Environment Variables and TLS PKI Matrix

Configuration keys loaded by [config.go](../../../pkg/config/config.go) and certificate layouts from [cert.go](../../../pkg/pki/cert.go).

## Environment Variables (`.env`)

| Variable | Default | Scope | Purpose |
|---|---|---|---|
| `DB_ROOT_PASSWORD` | `rootpass` | Global | Root/superuser password (`ROOT_PASSWORD` alias). |
| `DEFAULT_SERVICE` | `mariadb114` | `./mdb start` | Default standalone target (`DEFAULT_DB` alias). |
| `TRAEFIK_MYSQL_PORT` | `3306` | `docker-compose.yml` | Host port for standalone MySQL/MariaDB/Percona. |
| `TRAEFIK_PG_PORT` | `5432` | `docker-compose.yml` | Host port for standalone PostgreSQL 15–18. |
| `TRAEFIK_DASHBOARD_PORT` | `8088` | `docker-compose.yml` | Traefik v3 API/UI host port. |
| `GALERA_LB_PORT` | `3306` | `docker-compose-galera.yml` | HAProxy host port for Galera. |
| `HAPROXY_STATS_AUTH` | `admin:adminpass` | `docker-compose-patroni.yml` | Patroni HAProxy HTTPS stats credentials. |
| `SSL_DIR` / `REPORTS_DIR` | `ssl` / `reports` | `./mdb` | Local PKI and telemetry report directories. |
| `EXTRA_SANS` | `""` | `generate_certs.sh` | Comma-separated extra DNS/IP SAN entries. |
| `PG_SCALE` / `PG18_IO_METHOD` | `2` / `worker` | PG 18 & benches | Benchmark scale factor and PG 18 AIO method. |

## TLS PKI Directory and File Matrix

| Topology | Directory | CA & Leaf Files (`0644` certs / `0600` keys) |
|---|---|---|
| `galera`, `repli` | `ssl/` | `ca-cert.pem`, `server-cert.pem`, `server-key.pem`, `client-cert.pem`, `client-key.pem` |
| `innodb` | `ssl/innodb/` | `ca-cert.pem`, `server-cert.pem`, `server-key.pem` |
| `pgpool` | `ssl/pgpool/` | `ca-cert.pem`, `server.crt`, `server.key` |
| `patroni` | `certs_patroni/` | `ca.crt`, `etcd-*.{crt,key}`, `patroni-api.{crt,key}`, `postgresql-*.{crt,key}`, `haproxy.pem` |
| `mongo` / `mongo8` | `ssl/mongo/` / `ssl/certs/mongo8/` | `ca.pem`, `server.crt`, `server.key`, combined `mongodb.pem` |

Private keys (`*.key`, `*-key.pem`, `mongodb.pem`, `haproxy.pem`) require mode `0600` and stay excluded from Git and MkDocs (`exclude_docs`). See [TLS Setup](../../../documentation/tls_setup.md).
