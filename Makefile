# Makefile to orchestrate database containers via Docker Compose

# --- Configuration ---
# Use the bash shell for richer features
SHELL := /bin/bash

# Load environment variables from .env
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default root password if not set in .env
DB_ROOT_PASSWORD ?= rootpass
export DB_ROOT_PASSWORD

# --- PATRONI CLUSTER ---
PATRONI_COMPOSE = docker-compose-patroni.yml

patroni-gen-certs:
	@echo "🔐 Generating certificates for the Patroni cluster..."
	@CERT_DIR=certs_patroni ./scripts/patroni/generate_certs.sh

patroni-up: patroni-gen-certs
	@echo "🚀 Starting Patroni cluster..."
	docker compose -f $(PATRONI_COMPOSE) up -d

patroni-down:
	@echo "🛑 Stopping Patroni cluster..."
	docker compose -f $(PATRONI_COMPOSE) down -v

patroni-status:
	@echo "📊 Patroni cluster status..."
	docker exec node1 patronictl -c /etc/patroni.yml list

patroni-logs:
	docker compose -f $(PATRONI_COMPOSE) logs -f

patroni-ps:
	docker compose -f $(PATRONI_COMPOSE) ps

test-patroni: ## Run functional tests on the Patroni cluster
	@bash ./tests/test_patroni.sh

patroni-test: test-patroni ## Alias for test-patroni

# --- PGPOOL-II CLUSTER ---
PGPOOL_COMPOSE = docker-compose-pgpool.yml

pgpool-up: gen-ssl-pgpool ## Start PostgreSQL + PgPool-II + HAProxy cluster
	@echo "🚀 Starting PgPool-II cluster..."
	docker compose -f $(PGPOOL_COMPOSE) up -d
	@echo "⏳ Waiting for primary to initialize (20s)..."
	@sleep 20
	@echo "⛓️  Setting up streaming replication..."
	@bash ./scripts/pgpool/setup_replication.sh
	@echo "⏳ Waiting for PgPool-II to detect backends (10s)..."
	@sleep 10
	@echo "✅ PgPool-II cluster is ready."

pgpool-down: ## Stop PgPool-II cluster and remove volumes
	@echo "🛑 Stopping PgPool-II cluster..."
	docker compose -f $(PGPOOL_COMPOSE) down -v

pgpool-status: ## Show PgPool-II node status
	@echo "📊 PgPool-II Cluster Status..."
	@PGPASSWORD=$${DB_ROOT_PASSWORD:-postgres} psql -h 127.0.0.1 -p 9999 -U postgres -c "SHOW pool_nodes;"

pgpool-logs: ## Follow PgPool-II cluster logs
	docker compose -f $(PGPOOL_COMPOSE) logs -f

pgpool-ps: ## Show PgPool-II running containers
	docker compose -f $(PGPOOL_COMPOSE) ps

test-pgpool: ## Run functional tests on the PgPool-II cluster
	@bash ./tests/test_pgpool.sh

# --- MYSQL INNODB CLUSTER ---
INNODB_COMPOSE = docker-compose-innodb-cluster.yml

innodb-up: gen-ssl-innodb ## Start MySQL 8.4 InnoDB Cluster (3 nodes + HAProxy)
	@echo "🚀 Starting MySQL 8.4 InnoDB Cluster..."
	docker compose -f $(INNODB_COMPOSE) up -d
	@echo "⏳ Waiting for MySQL nodes to initialize (30s)..."
	@sleep 30
	@echo "⛓️  Setting up Group Replication..."
	@bash ./conf/innodb-cluster/setup_cluster.sh
	@echo "⏳ Waiting for HAProxy to detect InnoDB Cluster backends (15s)..."
	@sleep 15
	@echo "✅ MySQL 8.4 InnoDB Cluster is ready."

innodb-down: ## Stop InnoDB Cluster and remove volumes
	@echo "🛑 Stopping MySQL InnoDB Cluster..."
	docker compose -f $(INNODB_COMPOSE) down -v

innodb-status: ## Show InnoDB Cluster Group Replication status
	@echo "📊 MySQL InnoDB Cluster Status..."
	@docker exec -e MYSQL_PWD="$${DB_ROOT_PASSWORD:-rootpass}" mysql_node1 mysql -uroot -e "SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members;" 2>/dev/null

innodb-logs: ## Follow InnoDB Cluster logs
	docker compose -f $(INNODB_COMPOSE) logs -f

innodb-ps: ## Show InnoDB Cluster running containers
	docker compose -f $(INNODB_COMPOSE) ps

test-innodb: ## Run functional tests on the InnoDB Cluster
	@bash ./tests/test_innodb_cluster.sh

# --- MONGODB REPLICASET ---
MONGO_COMPOSE = docker-compose-mongo-rs.yml

mongo-up: gen-ssl-mongo ## Start MongoDB ReplicaSet (3 nodes + HAProxy)
	@echo "🚀 Starting MongoDB ReplicaSet..."
	docker compose -f $(MONGO_COMPOSE) up -d
	@echo "⏳ Waiting for MongoDB nodes to initialize (15s)..."
	@sleep 15
	@echo "⛓️  Setting up ReplicaSet..."
	@bash ./conf/mongo-rs/setup_rs.sh
	@echo "⏳ Waiting for HAProxy to detect backends (5s)..."
	@sleep 5
	@echo "✅ MongoDB ReplicaSet is ready."

mongo-down: ## Stop MongoDB ReplicaSet and remove volumes
	@echo "🛑 Stopping MongoDB ReplicaSet..."
	docker compose -f $(MONGO_COMPOSE) down -v

mongo-status: ## Show MongoDB ReplicaSet status
	@echo "📊 MongoDB ReplicaSet Status..."
	@docker exec mongo1 mongosh --tls --tlsAllowInvalidCertificates --tlsCertificateKeyFile /etc/ssl/mongo/mongodb.pem --quiet --eval "var s=rs.status(); s.members.forEach(function(m){print(m.name+' | '+m.stateStr+' | health='+m.health);});" 2>/dev/null

mongo-logs: ## Follow MongoDB ReplicaSet logs
	docker compose -f $(MONGO_COMPOSE) logs -f

mongo-ps: ## Show MongoDB ReplicaSet running containers
	docker compose -f $(MONGO_COMPOSE) ps

test-mongo: ## Run functional tests on the MongoDB ReplicaSet
	@bash ./tests/test_mongo_rs.sh

test-perf-mongo: ## Run performance benchmark suite on MongoDB ReplicaSet
	@bash ./tests/test_perf_mongo.sh $${PROFILE:-light} $${ACTION:-run}


# --- MONGODB 8 REPLICASET ---
MONGO8_COMPOSE = docker-compose-mongo8-rs.yml

mongo8-up: gen-ssl-mongo ## Start MongoDB 8 ReplicaSet (3 nodes + HAProxy)
	@echo "🚀 Starting MongoDB 8 ReplicaSet..."
	docker compose -f $(MONGO8_COMPOSE) up -d
	@echo "⏳ Waiting for MongoDB 8 nodes to initialize (15s)..."
	@sleep 15
	@echo "⛓️  Setting up ReplicaSet..."
	@MONGO_NODES="mongo8_n1 mongo8_n2 mongo8_n3" bash ./conf/mongo-rs/setup_rs.sh
	@echo "⏳ Waiting for HAProxy to detect backends (5s)..."
	@sleep 5
	@echo "✅ MongoDB 8 ReplicaSet is ready."

mongo8-down: ## Stop MongoDB 8 ReplicaSet and remove volumes
	@echo "🛑 Stopping MongoDB 8 ReplicaSet..."
	docker compose -f $(MONGO8_COMPOSE) down -v

mongo8-status: ## Show MongoDB 8 ReplicaSet status
	@echo "📊 MongoDB 8 ReplicaSet Status..."
	@docker exec mongo8_n1 mongosh --tls --tlsAllowInvalidCertificates --tlsCertificateKeyFile /etc/ssl/mongo/mongodb.pem --quiet --eval "var s=rs.status(); s.members.forEach(function(m){print(m.name+' | '+m.stateStr+' | health='+m.health);});" 2>/dev/null

mongo8-logs: ## Follow MongoDB 8 ReplicaSet logs
	docker compose -f $(MONGO8_COMPOSE) logs -f

mongo8-ps: ## Show MongoDB 8 ReplicaSet running containers
	docker compose -f $(MONGO8_COMPOSE) ps

test-mongo8: ## Run functional tests on MongoDB 8 ReplicaSet
	@MONGO_NODES="mongo8_n1 mongo8_n2 mongo8_n3" bash ./tests/test_mongo_rs.sh

# --- POSTGRESQL REPLICATION & MULTI-MASTER CLUSTERS ---
PG_STREAMING_COMPOSE = docker-compose-pg-streaming.yml
pg-streaming-up: ## Start 2-node PG 17 physical streaming replication cluster (async/sync)
	docker compose -f $(PG_STREAMING_COMPOSE) up -d && PG_STREAM_MODE=$${PG_STREAM_MODE:-async} bash ./scripts/pg_streaming/setup_pg_streaming.sh
pg-streaming-down: ## Stop pg-streaming cluster and remove volumes
	docker compose -f $(PG_STREAMING_COMPOSE) down -v
pg-streaming-status: ## Show pg-streaming replication status and containers
	docker compose -f $(PG_STREAMING_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" pg_stream_primary psql -U postgres -d labdb -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
pg-streaming-logs: ## Follow pg-streaming cluster logs
	docker compose -f $(PG_STREAMING_COMPOSE) logs -f
pg-streaming-ps: ## List pg-streaming containers
	docker compose -f $(PG_STREAMING_COMPOSE) ps
test-pg-streaming: ## Run pg-streaming functional, limits, and failover tests
	@bash ./tests/test_pg_streaming.sh
pg-streaming-test: test-pg-streaming

PG_LOGICAL_COMPOSE = docker-compose-pg-logical.yml
pg-logical-up: ## Start 2-node PG 17 native uni-directional logical replication cluster
	docker compose -f $(PG_LOGICAL_COMPOSE) up -d && bash ./scripts/pg_logical/setup_pg_logical.sh
pg-logical-down: ## Stop pg-logical cluster and remove volumes
	docker compose -f $(PG_LOGICAL_COMPOSE) down -v
pg-logical-status: ## Show pg-logical subscription status and containers
	docker compose -f $(PG_LOGICAL_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" pg_logical_sub psql -U postgres -d labdb -c "SELECT subname, subenabled FROM pg_subscription;"
pg-logical-logs: ## Follow pg-logical cluster logs
	docker compose -f $(PG_LOGICAL_COMPOSE) logs -f
pg-logical-ps: ## List pg-logical containers
	docker compose -f $(PG_LOGICAL_COMPOSE) ps
test-pg-logical: ## Run pg-logical functional and empirical limits tests
	@bash ./tests/test_pg_logical.sh
pg-logical-test: test-pg-logical

PG_BIREP_COMPOSE = docker-compose-pg-birep.yml
pg-birep-up: ## Start 2-node PG 17 bidirectional logical replication cluster
	docker compose -f $(PG_BIREP_COMPOSE) up -d && bash ./scripts/pg_birep/setup_birep.sh
pg-birep-down: ## Stop pg-birep cluster and remove volumes
	docker compose -f $(PG_BIREP_COMPOSE) down -v
pg-birep-status: ## Show pg-birep subscriptions and containers
	docker compose -f $(PG_BIREP_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" pg_birep_node1 psql -U postgres -d labdb -c "SELECT subname, subenabled FROM pg_subscription;"
pg-birep-logs: ## Follow pg-birep cluster logs
	docker compose -f $(PG_BIREP_COMPOSE) logs -f
pg-birep-ps: ## List pg-birep containers
	docker compose -f $(PG_BIREP_COMPOSE) ps
test-pg-birep: ## Run pg-birep functional and empirical limits tests
	@bash ./tests/test_pg_birep.sh
pg-birep-test: test-pg-birep

PGEDGE_COMPOSE = docker-compose-pgedge.yml
pgedge-up: ## Start 3-node pgEdge Spock 5 + Snowflake mesh
	docker compose -f $(PGEDGE_COMPOSE) up -d && bash ./scripts/pgedge/setup_pgedge.sh
pgedge-down: ## Stop pgEdge cluster and remove volumes
	docker compose -f $(PGEDGE_COMPOSE) down -v
pgedge-status: ## Show pgEdge Spock subscription status
	docker compose -f $(PGEDGE_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" pgedge_node1 psql -U postgres -d labdb -c "SELECT sub_name, status FROM spock.sub_show_status();"
pgedge-logs: ## Follow pgEdge cluster logs
	docker compose -f $(PGEDGE_COMPOSE) logs -f
pgedge-ps: ## List pgEdge containers
	docker compose -f $(PGEDGE_COMPOSE) ps
test-pgedge: ## Run pgEdge functional and empirical limits tests
	@bash ./tests/test_pgedge.sh
pgedge-test: test-pgedge

BUCARDO_COMPOSE = docker-compose-bucardo.yml
bucardo-up: ## Start 2-node PG 17 + Bucardo 5 multi-master stack
	docker compose -f $(BUCARDO_COMPOSE) up -d --build && bash ./scripts/bucardo/setup_bucardo.sh
bucardo-down: ## Stop Bucardo cluster and remove volumes
	docker compose -f $(BUCARDO_COMPOSE) down -v
bucardo-status: ## Show Bucardo multi-master sync status
	docker compose -f $(BUCARDO_COMPOSE) ps && docker exec bucardo_daemon bucardo status sync_mm
bucardo-logs: ## Follow Bucardo cluster logs
	docker compose -f $(BUCARDO_COMPOSE) logs -f
bucardo-ps: ## List Bucardo containers
	docker compose -f $(BUCARDO_COMPOSE) ps
test-bucardo: ## Run Bucardo functional and empirical limits tests
	@bash ./tests/test_bucardo.sh
bucardo-test: test-bucardo

CITUS_COMPOSE = docker-compose-citus.yml
citus-up: ## Start 3-node Citus 14.2 distributed PostgreSQL 17 cluster
	docker compose -f $(CITUS_COMPOSE) up -d && bash ./scripts/citus/setup_citus.sh
citus-down: ## Stop Citus cluster and remove volumes
	docker compose -f $(CITUS_COMPOSE) down -v
citus-status: ## Show Citus worker membership
	docker compose -f $(CITUS_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" citus_coord psql -U postgres -d labdb -c "SELECT nodeid, nodename, isactive FROM pg_dist_node ORDER BY nodeid;"
citus-logs: ## Follow Citus cluster logs
	docker compose -f $(CITUS_COMPOSE) logs -f
citus-ps: ## List Citus containers
	docker compose -f $(CITUS_COMPOSE) ps
test-citus: ## Run Citus functional and empirical limits tests
	@bash ./tests/test_citus.sh
citus-test: test-citus

COCKROACH_COMPOSE = docker-compose-cockroach.yml
cockroach-up: ## Start 3-node CockroachDB v25.4 Raft cluster
	docker compose -f $(COCKROACH_COMPOSE) up -d && bash ./scripts/cockroach/setup_cockroach.sh
cockroach-down: ## Stop CockroachDB cluster and remove volumes
	docker compose -f $(COCKROACH_COMPOSE) down -v
cockroach-status: ## Show CockroachDB cluster node status
	docker exec crdb_node1 /cockroach/cockroach node status --insecure --host=crdb_node1:26257
cockroach-logs: ## Follow CockroachDB cluster logs
	docker compose -f $(COCKROACH_COMPOSE) logs -f
cockroach-ps: ## List CockroachDB containers
	docker compose -f $(COCKROACH_COMPOSE) ps
test-cockroach: ## Run CockroachDB functional and empirical limits tests
	@bash ./tests/test_cockroach.sh
cockroach-test: test-cockroach

YUGABYTE_COMPOSE = docker-compose-yugabyte.yml
yugabyte-up: ## Start 3-node YugabyteDB 2026.1.3 RF=3 cluster
	docker compose -f $(YUGABYTE_COMPOSE) up -d && bash ./scripts/yugabyte/setup_yugabyte.sh
yugabyte-down: ## Stop YugabyteDB cluster and remove volumes
	docker compose -f $(YUGABYTE_COMPOSE) down -v
yugabyte-status: ## Show YugabyteDB node and YSQL status
	docker exec yb_node1 /home/yugabyte/bin/yugabyted status --base_dir=/home/yugabyte/var
yugabyte-logs: ## Follow YugabyteDB cluster logs
	docker compose -f $(YUGABYTE_COMPOSE) logs -f
yugabyte-ps: ## List YugabyteDB containers
	docker compose -f $(YUGABYTE_COMPOSE) ps
test-yugabyte: ## Run YugabyteDB functional and empirical limits tests
	@bash ./tests/test_yugabyte.sh
yugabyte-test: test-yugabyte

bench-pg-multimaster: ## Run sequential empirical benchmarks across 8 PostgreSQL topologies
	@bash ./scripts/bench_pg_multimaster.sh

test-pg-extended: ## Run sequential extended empirical test matrix (T11-T18) across 10 PG topologies
	@bash ./scripts/test_pg_extended_matrix.sh

bench-pg-v2: ## Run sequential V2 empirical benchmark suite (Suites A-H, WAN & concurrency sweeps)
	@bash ./scripts/bench_pg_v2_runner.sh

# --- POSTGRESQL 18.6 NATIVE CLUSTERING & BENCHMARK SUITE ---
PG18_STREAMING_COMPOSE = docker-compose-pg18-streaming.yml
pg18-streaming-up: ## Start PG 18.6 standalone + physical streaming cluster (async/sync)
	docker compose -f $(PG18_STREAMING_COMPOSE) up -d && PG_STREAM_MODE=$${PG_STREAM_MODE:-async} bash ./scripts/pg18_streaming/setup_pg18_streaming.sh
pg18-streaming-down: ## Stop pg18-streaming cluster and remove volumes
	docker compose -f $(PG18_STREAMING_COMPOSE) down -v
pg18-streaming-status: ## Show pg18-streaming replication status and containers
	docker compose -f $(PG18_STREAMING_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" pg18_stream_primary psql -U postgres -d labdb -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
pg18-streaming-logs: ## Follow pg18-streaming cluster logs
	docker compose -f $(PG18_STREAMING_COMPOSE) logs -f
pg18-streaming-ps: ## List pg18-streaming containers
	docker compose -f $(PG18_STREAMING_COMPOSE) ps
test-pg18-streaming: ## Run pg18-streaming AIO, checksums, failover, and T11-T18 tests
	@bash ./tests/test_pg18_streaming.sh
pg18-streaming-test: test-pg18-streaming

PG18_LOGICAL_COMPOSE = docker-compose-pg18-logical.yml
pg18-logical-up: ## Start 2-node PG 18.6 native uni-directional logical replication cluster
	docker compose -f $(PG18_LOGICAL_COMPOSE) up -d && bash ./scripts/pg18_logical/setup_pg18_logical.sh
pg18-logical-down: ## Stop pg18-logical cluster and remove volumes
	docker compose -f $(PG18_LOGICAL_COMPOSE) down -v
pg18-logical-status: ## Show pg18-logical subscription status and containers
	docker compose -f $(PG18_LOGICAL_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" pg18_logical_sub psql -U postgres -d labdb -c "SELECT subname, subenabled, substream FROM pg_subscription;"
pg18-logical-logs: ## Follow pg18-logical cluster logs
	docker compose -f $(PG18_LOGICAL_COMPOSE) logs -f
pg18-logical-ps: ## List pg18-logical containers
	docker compose -f $(PG18_LOGICAL_COMPOSE) ps
test-pg18-logical: ## Run pg18-logical functional, generated columns, and T11-T18 tests
	@bash ./tests/test_pg18_logical.sh
pg18-logical-test: test-pg18-logical

PG18_BIREP_COMPOSE = docker-compose-pg18-birep.yml
pg18-birep-up: ## Start 2-node PG 18.6 bidirectional logical cluster (uuidv7 + HAProxy)
	docker compose -f $(PG18_BIREP_COMPOSE) up -d && bash ./scripts/pg18_birep/setup_pg18_birep.sh
pg18-birep-down: ## Stop pg18-birep cluster and remove volumes
	docker compose -f $(PG18_BIREP_COMPOSE) down -v
pg18-birep-status: ## Show pg18-birep subscriptions and containers
	docker compose -f $(PG18_BIREP_COMPOSE) ps && docker exec -e PGPASSWORD="$${DB_ROOT_PASSWORD:-pg_poc_ephemeral}" pg18_birep_node1 psql -U postgres -d labdb -c "SELECT subname, subenabled, substream FROM pg_subscription;"
pg18-birep-logs: ## Follow pg18-birep cluster logs
	docker compose -f $(PG18_BIREP_COMPOSE) logs -f
pg18-birep-ps: ## List pg18-birep containers
	docker compose -f $(PG18_BIREP_COMPOSE) ps
test-pg18-birep: ## Run pg18-birep uuidv7, conflict counters, and T11-T18 tests
	@bash ./tests/test_pg18_birep.sh
pg18-birep-test: test-pg18-birep

bench-pg18: ## Run sequential empirical benchmarks across all 5 PG 18.6 topologies
	@bash ./scripts/bench_pg18_runner.sh

clean-pg18: pg18-streaming-down pg18-logical-down pg18-birep-down ## Stop and remove all PG 18.6 stacks and volumes

# --- Main Targets ---
.PHONY: help mycnf client info mysql97 mysql84 mysql96 mysql80 mysql57 mariadb123 mariadb118 mariadb114 mariadb1011 mariadb106 percona84 percona80 postgres18 postgres17 postgres16 postgres15 stop status logs \
        build-image galera-up galera-down galera-logs repli-up repli-down repli-logs test-repli test-galera test-patroni \
        pgpool-up pgpool-down pgpool-status pgpool-logs pgpool-ps test-pgpool \
        innodb-up innodb-down innodb-status innodb-logs innodb-ps test-innodb \
        mongo-up mongo-down mongo-status mongo-logs mongo-ps test-mongo \
        mongo8-up mongo8-down mongo8-status mongo8-logs mongo8-ps test-mongo8 \
        pg-streaming-up pg-streaming-down pg-streaming-status pg-streaming-logs pg-streaming-ps test-pg-streaming pg-streaming-test \
        pg-logical-up pg-logical-down pg-logical-status pg-logical-logs pg-logical-ps test-pg-logical pg-logical-test \
        pg-birep-up pg-birep-down pg-birep-status pg-birep-logs pg-birep-ps test-pg-birep pg-birep-test \
        pgedge-up pgedge-down pgedge-status pgedge-logs pgedge-ps test-pgedge pgedge-test \
        bucardo-up bucardo-down bucardo-status bucardo-logs bucardo-ps test-bucardo bucardo-test \
        citus-up citus-down citus-status citus-logs citus-ps test-citus citus-test \
        cockroach-up cockroach-down cockroach-status cockroach-logs cockroach-ps test-cockroach cockroach-test \
        yugabyte-up yugabyte-down yugabyte-status yugabyte-logs yugabyte-ps test-yugabyte yugabyte-test \
        pg18-streaming-up pg18-streaming-down pg18-streaming-status pg18-streaming-logs pg18-streaming-ps test-pg18-streaming pg18-streaming-test \
        pg18-logical-up pg18-logical-down pg18-logical-status pg18-logical-logs pg18-logical-ps test-pg18-logical pg18-logical-test \
        pg18-birep-up pg18-birep-down pg18-birep-status pg18-birep-logs pg18-birep-ps test-pg18-birep pg18-birep-test \
        bench-pg-multimaster test-pg-extended bench-pg-v2 bench-pg18 clean-pg18 \
        up-galera down-galera logs-galera up-repli down-repli logs-repli \
        clean-data clean-galera clean-repli full-galera full-repli clone-test-db inject-employee-galera \
        inject-sakila-galera inject-employee-repli inject-sakila-repli inject-employees inject-employee inject-sakila \
        gen-ssl clean-ssl renew-ssl renew-ssl-galera renew-ssl-repli emergency-galera emergency-repli check-galera check-repli \
        gen-ssl-innodb gen-ssl-pgpool gen-ssl-mongo gen-ssl-patroni gen-ssl-all check-ssl-all \
        test-config start verify inject sync-test-db test-all-topologies test-all-environments \
        build-go test-go

# --- Paths ---
TEST_DB_DIR = test_db
TEST_DB_REPO = https://github.com/jmrenouard/test_db.git

# --- Default Service ---
DEFAULT_SERVICE ?= mariadb114
# Detects the running database service reliably
GET_ACTIVE_SERVICE = docker compose ps --services --filter "status=running" | grep -v traefik | head -n 1
GET_CONTAINER_NAME = docker compose ps $$( $(GET_ACTIVE_SERVICE) ) --format "{{.Names}}"

# Default target, displays help
help:
	@printf "╔═══════════════════════════════════════════════════════╗\n"
	@printf "║      🚀 Available commands to manage databases        ║\n"
	@printf "╚═══════════════════════════════════════════════════════╝\n"
	@printf "\n"
	@printf "  \033[1;33mUsage:\033[0m make <command>\n"
	@printf "\n"
	@printf "  \033[1;32mGeneral:\033[0m\n"
	@printf "    \033[1mstop\033[0m          - 🛑 Stops all containers managed by this project.\n"
	@printf "    \033[1mstatus\033[0m        - 📊 Displays the status of active containers.\n"
	@printf "    \033[1minfo\033[0m          - ℹ️  Provides information about the active DB service.\n"
	@printf "    \033[1mlogs\033[0m          - 📄 Displays logs for all containers (e.g., make logs service=mysql97).\n"
	@printf "    \033[1mmycnf\033[0m         - 🔑 Generates the .my.cnf file for the MySQL client.\n"
	@printf "    \033[1mclient\033[0m        - 💻 Starts a MySQL client on the active database.\n"
	@printf "\n"
	@printf "  \033[1;32mMySQL (LTS):\033[0m\n"
	@printf "    \033[1mmysql97\033[0m       - Starts MySQL 9.7 LTS\n"
	@printf "    \033[1mmysql84\033[0m       - Starts MySQL 8.4 LTS\n"
	@printf "\n"
	@printf "  \033[1;32mMariaDB (LTS):\033[0m\n"
	@printf "    \033[1mmariadb123\033[0m    - Starts MariaDB 12.3 LTS\n"
	@printf "    \033[1mmariadb118\033[0m    - Starts MariaDB 11.8 LTS\n"
	@printf "    \033[1mmariadb114\033[0m    - Starts MariaDB 11.4 LTS\n"
	@printf "    \033[1mmariadb1011\033[0m   - Starts MariaDB 10.11 LTS\n"
	@printf "\n"
	@printf "  \033[1;32mMariaDB Clusters (Galera & Replication):\033[0m\n"
	@printf "    \033[1mup-galera\033[0m     - 🚀 Starts Galera cluster (Sequential bootstrap)\n"
	@printf "    \033[1mup-repli\033[0m      - 🚀 Starts Replication cluster\n"
	@printf "    \033[1mcheck-galera\033[0m  - 📊 Checks Galera status\n"
	@printf "    \033[1mcheck-repli\033[0m   - 📊 Checks Replication status\n"
	@printf "    \033[1mtest-galera\033[0m   - 🧪 Runs Galera tests\n"
	@printf "    \033[1mtest-repli\033[0m    - 🧪 Runs Replication tests\n"
	@printf "    \033[1mtest-config\033[0m   - 🧪 Validates orchestration and configuration\n"
	@printf "\n"
	@printf "  \033[1;32mData Injection:\033[0m\n"
	@printf "    \033[1minject-employees\033[0m - 💉 Injects employees database (Auto-detect environment)\n"
	@printf "    \033[1minject-sakila\033[0m    - 💉 Injects sakila database (Auto-detect environment)\n"
	@printf "    \033[1minject\033[0m           - 💉 Alias for inject-employees on default service\n"
	@printf "\n"
	@printf "  \033[1;32mPercona Server (LTS):\033[0m\n"
	@printf "    \033[1mpercona84\033[0m     - Starts Percona Server 8.4 LTS\n"
	@printf "\n"
	@printf "  \033[1;32mPostgreSQL & Patroni:\033[0m\n"
	@printf "    \033[1mpatroni-up\033[0m    - 🚀 Starts Patroni PostgreSQL 17 cluster\n"
	@printf "    \033[1mpatroni-status\033[0m - 📊 Checks Patroni cluster status\n"
	@printf "    \033[1mtest-patroni\033[0m   - 🧪 Runs Patroni functional tests\n"
	@printf "    \033[1mpostgres18\033[0m    - Starts PostgreSQL 18\n"
	@printf "    \033[1mpostgres17\033[0m    - Starts PostgreSQL 17\n"
	@printf "    \033[1mpostgres16\033[0m    - Starts PostgreSQL 16\n"
	@printf "    \033[1mpostgres15\033[0m    - Starts PostgreSQL 15\n"
	@printf "\n"
	@printf "  \033[1;32mPgPool-II Cluster:\033[0m\n"
	@printf "    \033[1mpgpool-up\033[0m     - 🚀 Starts PgPool-II + PostgreSQL 17 cluster\n"
	@printf "    \033[1mpgpool-down\033[0m   - 🛑 Stops PgPool-II cluster\n"
	@printf "    \033[1mpgpool-status\033[0m - 📊 Shows PgPool-II node status\n"
	@printf "    \033[1mtest-pgpool\033[0m   - 🧪 Runs PgPool-II functional tests\n"
	@printf "\n"
	@printf "  \033[1;32mMySQL InnoDB Cluster:\033[0m\n"
	@printf "    \033[1minnodb-up\033[0m     - 🚀 Starts MySQL 8.4 InnoDB Cluster (3 nodes + HAProxy)\n"
	@printf "    \033[1minnodb-down\033[0m   - 🛑 Stops InnoDB Cluster\n"
	@printf "    \033[1minnodb-status\033[0m - 📊 Shows Group Replication status\n"
	@printf "    \033[1mtest-innodb\033[0m   - 🧪 Runs InnoDB Cluster functional tests\n"
	@printf "\n"
	@printf "  \033[1;32mMySQLTuner Integration:\033[0m\n"
	@printf "    \033[1mmysqltuner-galera\033[0m  - 🔍 Run MySQLTuner audit on Galera Cluster\n"
	@printf "    \033[1mmysqltuner-innodb\033[0m  - 🔍 Run MySQLTuner audit on InnoDB Cluster\n"
	@printf "    \033[1mmysqltuner-repli\033[0m   - 🔍 Run MySQLTuner audit on Replication\n"
	@printf "    \033[1mmysqltuner-all\033[0m     - 🔍 Run MySQLTuner on all HA topologies\n"
	@printf "\n"
	@printf "  \033[1;32mEnd-to-End Testing:\033[0m\n"
	@printf "    \033[1mtest-all\033[0m           - 🧪 Runs functional tests on all standalone databases\n"
	@printf "    \033[1mtest-all-topologies\033[0m- 🧪 Runs E2E tests across ALL standalone DBs and HA topologies\n"
	@printf "\n"
	@printf "  \033[1;32mPostgreSQL Multi-Master Clusters:\033[0m\n"
	@printf "    \033[1mpg-streaming-up / test-pg-streaming\033[0m - PG 17 Physical Streaming (Async/Sync)\n"
	@printf "    \033[1mpg-logical-up / test-pg-logical\033[0m     - PG 17 Native Uni-Directional Logical\n"
	@printf "    \033[1mpg-birep-up / test-pg-birep\033[0m   - PG 17 Bidirectional Logical + HAProxy\n"
	@printf "    \033[1mpgedge-up / test-pgedge\033[0m       - PG 17 pgEdge Spock 5 + Snowflake Mesh\n"
	@printf "    \033[1mbucardo-up / test-bucardo\033[0m     - PG 17 Bucardo 5 Trigger Multi-Master\n"
	@printf "    \033[1mcitus-up / test-citus\033[0m         - Citus 14.2 Distributed PG 17\n"
	@printf "    \033[1mcockroach-up / test-cockroach\033[0m - CockroachDB v25.4 3-Node Raft\n"
	@printf "    \033[1myugabyte-up / test-yugabyte\033[0m   - YugabyteDB 2026.1.3 3-Node Raft\n"
	@printf "    \033[1mbench-pg-multimaster\033[0m          - Sequential pgbench/sysbench suite\n"
	@printf "    \033[1mtest-pg-extended / bench-pg-v2\033[0m - Extended T11-T18 matrix & V2 benchmarks\n"
	@printf "    \033[1mpg18-streaming-up / pg18-streaming-test\033[0m - PG 18.6 Streaming (AIO worker)\n"
	@printf "    \033[1mpg18-logical-up / pg18-logical-test\033[0m     - PG 18.6 Native Logical\n"
	@printf "    \033[1mpg18-birep-up / pg18-birep-test\033[0m         - PG 18.6 Bidirectional (uuidv7)\n"
	@printf "    \033[1mbench-pg18 / clean-pg18\033[0m                 - PG 18.6 Benchmark & Cleanup\n"
	@printf "\n"
	@printf "  \033[1;32mGolang Orchestrator (v2.3.0):\033[0m\n"
	@printf "    \033[1mbuild-go\033[0m           - 🔨 Compiles mdb CLI binary into bin/mdb\n"
	@printf "    \033[1mtest-go\033[0m            - 🧪 Runs complete Go unit test suite\n"
	@printf "\n"

# 🚀 Starts the default database service
start: $(DEFAULT_SERVICE)

# 🧪 Runs configuration and environment validation
verify: test-config

# 💉 Injects employees database into the active environment (Alias)
inject: inject-employees

# 💉 Injects employees database into the active environment
inject-employees: ## Inject employees database into the detected running environment
	@if [ -n "$$(docker compose -f $(COMPOSE_GALERA) ps -q galera_01 2>/dev/null)" ] && [ -n "$$(docker compose -f $(COMPOSE_GALERA) ps --services --filter "status=running" | grep galera_01)" ]; then \
		make inject-employee-galera; \
	elif [ -n "$$(docker compose -f $(COMPOSE_REPLI) ps -q mariadb_01 2>/dev/null)" ] && [ -n "$$(docker compose -f $(COMPOSE_REPLI) ps --services --filter "status=running" | grep mariadb_01)" ]; then \
		make inject-employee-repli; \
	else \
		DB_SERVICE=$$(docker compose ps --services --filter "status=running" | grep -v traefik | head -n 1); \
		if [ -n "$$DB_SERVICE" ]; then \
			make inject-data service=$$DB_SERVICE db=employees; \
		else \
			printf "\033[1;31m❌ Error: No running environment detected for injection.\033[0m\n"; \
			exit 1; \
		fi; \
	fi

# 💉 Injects sakila database into the active environment
inject-sakila: ## Inject sakila database into the detected running environment
	@if [ -n "$$(docker compose -f $(COMPOSE_GALERA) ps -q galera_01 2>/dev/null)" ] && [ -n "$$(docker compose -f $(COMPOSE_GALERA) ps --services --filter "status=running" | grep galera_01)" ]; then \
		make inject-sakila-galera; \
	elif [ -n "$$(docker compose -f $(COMPOSE_REPLI) ps -q mariadb_01 2>/dev/null)" ] && [ -n "$$(docker compose -f $(COMPOSE_REPLI) ps --services --filter "status=running" | grep mariadb_01)" ]; then \
		make inject-sakila-repli; \
	else \
		DB_SERVICE=$$(docker compose ps --services --filter "status=running" | grep -v traefik | head -n 1); \
		if [ -n "$$DB_SERVICE" ]; then \
			make inject-data service=$$DB_SERVICE db=sakila; \
		else \
			printf "\033[1;31m❌ Error: No running environment detected for injection.\033[0m\n"; \
			exit 1; \
		fi; \
	fi

# 💉 Alias for inject-employees
inject-employee: inject-employees

# --- Management Commands ---

# 🛑 Stops and removes all containers, networks, and orphans
stop:
	@echo "🔥 Stopping and cleaning up containers..."
	@docker compose --profile "*" down -v --remove-orphans >/dev/null 2>&1 || docker compose down -v --remove-orphans >/dev/null 2>&1
	@docker ps -q --filter "label=com.docker.compose.project=multi-db-docker-env" | xargs -r docker stop >/dev/null 2>&1 || true
	@docker ps -aq --filter "label=com.docker.compose.project=multi-db-docker-env" | xargs -r docker rm -f >/dev/null 2>&1 || true

# 📊 Displays the status of active containers
status:
	@echo "📊 Docker Compose Status:"
	@docker compose ps

# ℹ️ Provides information about the active DB service and displays status/logs
info:
	@DB_SERVICE=$$($(GET_ACTIVE_SERVICE)); \
	if [ -n "$${DB_SERVICE}" ]; then \
		printf "✅ Active database service: \033[1;32m%s\033[0m\n" "$${DB_SERVICE}"; \
	else \
		printf "❌ No database service is running.\n"; \
	fi
	@echo
	@echo "📊 Docker Compose Status:"
	@docker compose ps
	@echo
	@echo "📄 To view logs: make logs"
	@echo "📄 Displaying recent logs..."
	@DB_SERVICE=$$(docker compose ps --services --filter "status=running" | grep -v traefik); \
	docker compose logs -n 10 $$DB_SERVICE

# 📄 Displays logs
# Usage: make logs or make logs service=<service_name>
logs:
	@echo "📄 Displaying logs..."
	@DB_SERVICE=$(if $(service),$(service),$$($(GET_ACTIVE_SERVICE))); \
	docker compose logs -f $$DB_SERVICE
	
# 🔑 Generates the .my.cnf file
mycnf:
	@echo "🔑 Generating .my.cnf configuration file..."
	@# Load variables from .env for this specific command
	@if [ ! -f .env ]; then \
		printf "\n\033[1;31m❌ Error: .env file is missing.\033[0m\n\n"; \
		exit 1; \
	fi
	@# Check if the variable is defined
	@printf "[client]\nuser=root\npassword=%s\nhost=127.0.0.1\n" "$(DB_ROOT_PASSWORD)" > $${HOME}/.my.cnf
	@# Apply restrictive permissions for security
	@chmod 600 $${HOME}/.my.cnf
	@printf "✅ .my.cnf file generated and secured in your home directory (~/.my.cnf).\n"

# 💻 Starts a MySQL client on the active DB
client:
	@if [ ! -f .env ]; then \
		printf "❌ .env file is missing. Cannot retrieve password.\n"; \
		exit 1; \
	fi
	@DB_SERVICE=$$($(GET_ACTIVE_SERVICE)); \
	DB_CONTAINER=$$($(GET_CONTAINER_NAME)); \
	if [ -n "$${DB_SERVICE}" ]; then \
		printf "💻 Connecting MySQL client to \033[1;32m%s\033[0m...\n" "$${DB_SERVICE}"; \
		docker exec -it -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" mysql -uroot; \
	else \
		printf "❌ No database service is running to start the client.\n"; \
	fi

# --- Data Injection ---
.PHONY: inject-data

inject-data:
	@# Ensure service and db are provided
	@if [ -z "$(service)" ] || [ -z "$(db)" ]; then \
		printf "\033[1;31m❌ Error: 'service' and 'db' parameters are required.\033[0m\n"; \
		printf "Usage: make inject-data service=<service_name> db=<db_name>\n"; \
		printf "Available db_names: employees, sakila\n"; \
		exit 1; \
	fi

	@# Check if the service is running
	@if [ -z "$$(docker compose ps --services --filter "status=running" | grep $(service))" ]; then \
		printf "\033[1;31m❌ Error: Service '%s' is not running.\033[0m\n" "$(service)"; \
		exit 1; \
	fi
	if [ ! -d "$(TEST_DB_DIR)" ]; then \
		printf "Initializing '$(TEST_DB_DIR)' submodule...\n"; \
		git submodule update --init --recursive; \
	fi; \
	DB_CONTAINER=$$(docker compose ps $(service) --format "{{.Names}}"); \
	printf "⏳ Waiting for %s to be ready...\n" "$${DB_CONTAINER}"; \
	case "$(service)" in \
		postgres*) \
			timeout 120s bash -c "until docker exec $${DB_CONTAINER} pg_isready -U postgres >/dev/null 2>&1; do sleep 2; done" || (printf \"\033[1;31m❌ Error: PostgreSQL reached timeout without becoming ready.\033[0m\n\" && exit 1); \
			;; \
		*) \
			timeout 120s bash -c "until docker exec -e MYSQL_PWD=\"$(DB_ROOT_PASSWORD)\" $${DB_CONTAINER} sh -c 'mysql -uroot -e \"SELECT 1\" 2>/dev/null | grep -q 1 || mariadb -uroot -e \"SELECT 1\" 2>/dev/null | grep -q 1'; do sleep 2; done" || (printf \"\033[1;31m❌ Error: Database reached timeout without becoming ready. Check credentials or logs.\033[0m\n\" && exit 1); \
			;; \
	esac; \
	sleep 5; \
	case "$(service)" in \
		postgres*) \
			printf "Skipping data injection for PostgreSQL (MySQL-only datasets).\n" \
			;; \
		*) \
			MYSQL_CMD=$$(docker exec "$${DB_CONTAINER}" sh -c 'command -v mysql || command -v mariadb || ls /usr/bin/mysql /usr/bin/mariadb 2>/dev/null | head -n 1'); \
			if [ -z "$${MYSQL_CMD}" ]; then \
				printf "\033[1;31m❌ Error: Neither 'mysql' nor 'mariadb' found in container %s.\nLogs:\033[0m\n" "$${DB_CONTAINER}"; \
				docker logs "$${DB_CONTAINER}" | tail -n 20; \
				exit 1; \
			fi; \
			printf "Injecting data into %s using %s...\n" "$${DB_CONTAINER}" "$${MYSQL_CMD}"; \
			if [ "$(db)" = "employees" ]; then \
				if [ "$(service)" = "mysql97" ]; then \
					printf "⚠️ Skipping 'employees' for mysql97 (Nested source regression). Injecting 'sakila' as primary test database instead...\n"; \
					docker cp $(TEST_DB_DIR)/sakila "$${DB_CONTAINER}:/tmp/" && \
					docker exec -i -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot < sakila-mv-schema.sql" && \
					docker exec -i -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot < sakila-mv-data.sql" && \
					printf "✅ 'sakila' database injected as primary dataset for mysql97.\n"; \
				else \
					docker cp $(TEST_DB_DIR)/employees "$${DB_CONTAINER}:/tmp/test_db" && \
					docker exec -i -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" sh -c "cd /tmp/test_db && $${MYSQL_CMD} -uroot < employees.sql" && \
					printf "✅ 'employees' database injected.\n"; \
				fi; \
			elif [ "$(db)" = "sakila" ]; then \
				docker cp $(TEST_DB_DIR)/sakila "$${DB_CONTAINER}:/tmp/" && \
				docker exec -i -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot < sakila-mv-schema.sql" && \
				docker exec -i -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot < sakila-mv-data.sql" && \
				printf "✅ 'sakila' database injected.\n"; \
			fi \
			;; \
	esac

# --- Full Test Suite ---
.PHONY: test-all

test-all:
	@# List of all active supported database services to test
	@SERVICES_TO_TEST="mysql97 mysql84 mariadb123 mariadb118 mariadb114 mariadb1011 percona84 postgres18 postgres17 postgres16 postgres15"; \
	for service in $${SERVICES_TO_TEST}; do \
		printf "\n\033[1;34m--- Testing service: %s ---\033[0m\n" "$$service"; \
		\
		printf "🚀 Starting service %s...\n" "$$service" && \
		make $$service && \
		\
		printf "⏳ Waiting for DB to be ready...\n"; \
		DB_CONTAINER=$$(docker compose ps -a $$service --format "{{.Names}}" | head -n 1); \
		case "$$service" in \
			postgres*) \
				timeout 120s bash -c "until docker exec $${DB_CONTAINER} pg_isready -U postgres >/dev/null 2>&1; do sleep 2; done" || exit 1; \
				;; \
			*) \
				timeout 120s bash -c "until docker exec -e MYSQL_PWD=\"$(DB_ROOT_PASSWORD)\" $${DB_CONTAINER} sh -c 'mysql -uroot -e \"SELECT 1\" 2>/dev/null | grep -q 1 || mariadb -uroot -e \"SELECT 1\" 2>/dev/null | grep -q 1'; do sleep 2; done" || exit 1; \
				;; \
		esac; \
		sleep 5; \
		case "$$service" in \
			postgres*) \
				printf "🧪 Running PostgreSQL feature tests...\n"; \
				docker exec "$${DB_CONTAINER}" psql -U postgres -c "SELECT version();" || exit 1; \
				;; \
			*) \
				MYSQL_CMD=$$(docker exec "$${DB_CONTAINER}" sh -c 'command -v mysql || command -v mariadb || ls /usr/bin/mysql /usr/bin/mariadb 2>/dev/null | head -n 1'); \
				if [ -z "$${MYSQL_CMD}" ]; then \
					printf "\033[1;31m❌ Error: Neither 'mysql' nor 'mariadb' found in container %s.\nLogs:\033[0m\n" "$$DB_CONTAINER"; \
					docker logs "$$DB_CONTAINER" | tail -n 20; \
					exit 1; \
				fi; \
				\
				PRIMARY_DB="employees"; \
				if [ "$$service" = "mysql97" ]; then PRIMARY_DB="sakila"; fi; \
				\
				printf "💉 Injecting 'employees' database...\n" && \
				make inject-data service=$$service db=employees && \
				\
				printf "💉 Injecting 'sakila' database...\n" && \
				make inject-data service=$$service db=sakila && \
				\
				printf "🧪 Running Python feature tests...\n"; \
				python3 tests/test_lab.py || exit 1; \
				\
				printf "🔍 Verifying data injection...\n" && \
				docker exec -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -e "SHOW DATABASES;" | grep -q "$$PRIMARY_DB" && \
				printf "✅ '%s' database found.\n" "$$PRIMARY_DB" && \
				docker exec -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -e "SHOW DATABASES;" | grep -q "sakila" && \
				printf "✅ 'sakila' database found.\n"; \
				;; \
		esac; \
		\
		printf "🔍 Verifying Traefik proxy...\n" && \
		case "$$service" in \
			postgres*) \
				docker exec -e PGPASSWORD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" psql -h traefik -U postgres -c "SELECT 1" | grep -q 1 && \
				printf "✅ Connection via Traefik successful.\n" \
				;; \
			*) \
				docker exec -e MYSQL_PWD="$(DB_ROOT_PASSWORD)" "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -h traefik -e "SHOW DATABASES;" | grep -q "$$PRIMARY_DB" && \
				printf "✅ Connection via Traefik successful.\n" \
				;; \
		esac; \
		\
		printf "🛑 Stopping service %s...\n" "$$service" && \
		docker compose down -v; \
	done
	@printf "\n\033[1;32m✅ All services tested successfully!\033[0m\n"

.PHONY: test-all-report test-failover test-backup-restore test-all-topologies test-all-environments

test-all-topologies: test-config test-all ## Run E2E verification tests across ALL standalone DBs and HA topologies (Galera, Replication, InnoDB, PgPool, Patroni, Mongo)
	@echo "=========================================================="
	@echo "🚀 Starting Full E2E Topology Test Suite"
	@echo "=========================================================="
	@echo ">> 🧪 1. Testing Galera Cluster..."
	@$(MAKE) full-galera || exit 1
	@$(MAKE) down-galera
	@echo ">> 🧪 2. Testing Replication Cluster..."
	@$(MAKE) full-repli || exit 1
	@$(MAKE) down-repli
	@echo ">> 🧪 3. Testing MySQL InnoDB Cluster..."
	@$(MAKE) gen-ssl-innodb || exit 1
	@$(MAKE) innodb-up || exit 1
	@$(MAKE) test-innodb || exit 1
	@$(MAKE) innodb-down
	@echo ">> 🧪 4. Testing PostgreSQL PgPool-II Cluster..."
	@$(MAKE) gen-ssl-pgpool || exit 1
	@$(MAKE) pgpool-up || exit 1
	@$(MAKE) test-pgpool || exit 1
	@$(MAKE) pgpool-down
	@echo ">> 🧪 5. Testing Patroni PostgreSQL Cluster..."
	@$(MAKE) gen-ssl-patroni || exit 1
	@$(MAKE) patroni-up || exit 1
	@$(MAKE) test-patroni || exit 1
	@$(MAKE) patroni-down
	@echo ">> 🧪 6. Testing MongoDB ReplicaSet..."
	@$(MAKE) gen-ssl-mongo || exit 1
	@$(MAKE) mongo-up || exit 1
	@$(MAKE) test-mongo || exit 1
	@$(MAKE) mongo-down
	@echo ">> 🧪 7. Testing MongoDB 8 ReplicaSet..."
	@$(MAKE) mongo8-up || exit 1
	@$(MAKE) test-mongo8 || exit 1
	@$(MAKE) mongo8-down
	@echo ">> 🧪 8. Testing Failover & Backup/Restore..."
	@$(MAKE) test-failover || exit 1
	@$(MAKE) test-backup-restore || exit 1
	@echo ">> 📊 Aggregating all reports..."
	@$(MAKE) test-all-report
	@echo "=========================================================="
	@echo "🎉 FULL E2E TOPOLOGY TEST SUITE PASSED SUCCESSFULLY!"
	@echo "=========================================================="

test-all-environments: test-all-topologies ## Alias for test-all-topologies
test-all-report: ## Aggregate all individual HTML test reports into a consolidated report
	@bash ./scripts/aggregate_reports.sh

test-failover: ## Run automated primary failover & resilience tests
	@bash ./tests/test_failover.sh "${TARGET:-all}"

test-backup-restore: ## Run backup and restore procedure verification tests
	@bash ./tests/test_backup_restore.sh
	
test-config: ## Validate the current orchestration configuration, directory structure, SSL and profiles
	@echo "🚀 Running Configuration Validation..."
	bash ./tests/test_env.sh
	bash ./tests/test_config.sh
	bash ./tests/test_security_ssl.sh
	bash ./tests/test_profiles.sh
	@if command -v go >/dev/null 2>&1; then $(MAKE) test-go; fi
	@if command -v python3 >/dev/null 2>&1; then python3 -m unittest discover -s tests -v; fi

# --- Golang Tooling & Build Targets ---
build-go: ## Compile mdb binary into bin/mdb
	@echo "🔨 Building mdb binary..."
	@mkdir -p bin
	CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$$(tr -d '[:space:]' < VERSION)" -o bin/mdb ./cmd/mdb

test-go: ## Run complete Go test suite
	@echo "🧪 Running Go test suite..."
	go test -v ./...



# --- MySQLTuner Integration ---
# These targets run MySQLTuner against HA topologies for E2E validation.
# Set MYSQLTUNER_PATH to the path of mysqltuner.pl if not in a sibling directory.

mysqltuner-galera: up-galera inject-employee-galera ## Run MySQLTuner audit on Galera cluster
	@echo "🔍 Running MySQLTuner on Galera Cluster..."
	@bash ./scripts/run_mysqltuner.sh --topology galera

mysqltuner-innodb: innodb-up ## Run MySQLTuner audit on InnoDB Cluster
	@echo "🔍 Running MySQLTuner on InnoDB Cluster..."
	@bash ./scripts/run_mysqltuner.sh --topology innodb_cluster

mysqltuner-repli: up-repli inject-employee-repli ## Run MySQLTuner audit on Replication
	@echo "🔍 Running MySQLTuner on Replication..."
	@bash ./scripts/run_mysqltuner.sh --topology replication

mysqltuner-all: ## Run MySQLTuner audit on all HA topologies sequentially
	@echo "🔍 Running MySQLTuner on ALL HA topologies..."
	@$(MAKE) mysqltuner-galera || true
	@$(MAKE) down-galera
	@$(MAKE) mysqltuner-innodb || true
	@$(MAKE) innodb-down
	@$(MAKE) mysqltuner-repli || true
	@$(MAKE) down-repli
	@echo "✅ MySQLTuner audit complete for all topologies. Reports in ./reports/"

# --- Start-up Targets by Profile ---
traefik: stop
	@echo "🚀 Starting Traefik..."
	@docker compose --profile traefik up -d

# 🐬 MySQL (LTS)
mysql97: stop traefik
	@echo "🚀 Starting MySQL 9.7 LTS..."
	@docker compose --profile mysql97 up -d

mysql84: stop traefik
	@echo "🚀 Starting MySQL 8.4 LTS..."
	@docker compose --profile mysql84 up -d

# 🐧 MariaDB (LTS)
mariadb123: stop traefik
	@echo "🚀 Starting MariaDB 12.3 LTS..."
	@docker compose --profile mariadb123 up -d

mariadb118: stop traefik
	@echo "🚀 Starting MariaDB 11.8 LTS..."
	@docker compose --profile mariadb118 up -d

mariadb114: stop traefik
	@echo "🚀 Starting MariaDB 11.4 LTS..."
	@docker compose --profile mariadb114 up -d

mariadb1011: stop traefik
	@echo "🚀 Starting MariaDB 10.11 LTS..."
	@docker compose --profile mariadb1011 up -d

# ⚡ Percona Server (LTS)
percona84: stop traefik
	@echo "🚀 Starting Percona Server 8.4 LTS..."
	@docker compose --profile percona84 up -d

# 🐘 PostgreSQL
postgres18: stop traefik
	@echo "🚀 Starting PostgreSQL 18..."
	@docker compose --profile postgres18 up -d

postgres17: stop traefik
	@echo "🚀 Starting PostgreSQL 17..."
	@docker compose --profile postgres17 up -d

postgres16: stop traefik
	@echo "🚀 Starting PostgreSQL 16..."
	@docker compose --profile postgres16 up -d

postgres15: stop traefik
	@echo "🚀 Starting PostgreSQL 15..."
	@docker compose --profile postgres15 up -d

# --- Decommissioned End-of-Life (EOL) Targets ---
mysql57:
	@printf "\033[1;31m❌ Decommissioned target: mysql57 (MySQL 5.7 reached official Community EOL on 2023-10-31; Extended Support ended 2026-10-31).\033[0m\n" >&2
	@printf "👉 Use a supported LTS target instead: make mysql84 or make mysql97\n" >&2
	@exit 1

mysql80:
	@printf "\033[1;31m❌ Decommissioned target: mysql80 (MySQL 8.0 reached official Community EOL on 2026-04-30).\033[0m\n" >&2
	@printf "👉 Use a supported LTS target instead: make mysql84 or make mysql97\n" >&2
	@exit 1

mysql96:
	@printf "\033[1;31m❌ Decommissioned target: mysql96 (MySQL 9.6 Innovation reached official EOL on 2026-04-21 and was superseded by MySQL 9.7 LTS).\033[0m\n" >&2
	@printf "👉 Use a supported LTS target instead: make mysql97 or make mysql84\n" >&2
	@exit 1

mariadb106:
	@printf "\033[1;31m❌ Decommissioned target: mariadb106 (MariaDB 10.6 reached official Community EOL on 2026-07-06).\033[0m\n" >&2
	@printf "👉 Use a supported LTS target instead: make mariadb1011, make mariadb114, make mariadb118, or make mariadb123\n" >&2
	@exit 1

percona80:
	@printf "\033[1;31m❌ Decommissioned target: percona80 (Percona Server 8.0 reached official Community EOL on 2026-04-30).\033[0m\n" >&2
	@printf "👉 Use a supported LTS target instead: make percona84\n" >&2
	@exit 1

# --- MariaDB Clusters (Merged from mariadb subfolder) ---

IMAGE_NAME = mariadb_ssh:004
COMPOSE_GALERA = docker-compose-galera.yml
COMPOSE_REPLI = docker-compose-repli.yml

## Image Management
build-image: ## Build the base mariadb_ssh image
	docker build -t $(IMAGE_NAME) .

install-client: ## Install MariaDB client on the host (Ubuntu/Debian)
	sudo apt-get update && sudo apt-get install -y mariadb-client

## Galera Cluster
up-galera: stop build-image gen-ssl down-repli ## Start Galera cluster
	@echo ">> 🚀 Starting Node 1 (Primary)..."
	MARIADB_GALERA_BOOTSTRAP=1 docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_01
	@echo ">> ⏳ Waiting for Node 1 to start..."
	@for i in $$(seq 1 60); do \
		if docker compose -f $(COMPOSE_GALERA) exec -T -e MYSQL_PWD="$${DB_ROOT_PASSWORD}" galera_01 mariadb -u root -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; then break; fi; \
		if [ $$i -eq 60 ]; then docker compose -f $(COMPOSE_GALERA) exec -T galera_01 cat /var/log/supervisor/mariadb.err.log /var/log/supervisor/mariadb.out.log 2>/dev/null || true; exit 1; fi; \
		sleep 1; \
	done
	@echo "✅ Node 1 is Synced."
	@echo ">> 🚀 Joining Node 2..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_02
	@echo ">> ⏳ Waiting for Node 2 to join..."
	@for i in $$(seq 1 60); do \
		if docker compose -f $(COMPOSE_GALERA) exec -T -e MYSQL_PWD="$${DB_ROOT_PASSWORD}" galera_02 mariadb -u root -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; then break; fi; \
		if [ $$i -eq 60 ]; then docker compose -f $(COMPOSE_GALERA) exec -T galera_02 cat /var/log/supervisor/mariadb.err.log /var/log/supervisor/mariadb.out.log 2>/dev/null || true; exit 1; fi; \
		sleep 2; \
	done
	@echo "✅ Node 2 is Synced."
	@echo ">> 🚀 Joining Node 3..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_03
	@echo ">> ⏳ Waiting for Node 3 to join..."
	@for i in $$(seq 1 60); do \
		if docker compose -f $(COMPOSE_GALERA) exec -T -e MYSQL_PWD="$${DB_ROOT_PASSWORD}" galera_03 mariadb -u root -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; then break; fi; \
		if [ $$i -eq 60 ]; then docker compose -f $(COMPOSE_GALERA) exec -T galera_03 cat /var/log/supervisor/mariadb.err.log /var/log/supervisor/mariadb.out.log 2>/dev/null || true; exit 1; fi; \
		sleep 2; \
	done
	@echo "✅ Node 3 is Synced."
	@echo ">> 🚀 Starting Load Balancer..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate haproxy_galera
	@echo "✅ Cluster is fully SEQUENTIALLY BOOTSTRAPPED and ready."

bootstrap-galera: stop build-image gen-ssl down-repli ## Bootstrap a NEW Galera cluster (Sequential)
	@echo ">> 🚀 Bootstrapping Node 1 (Primary)..."
	MARIADB_GALERA_BOOTSTRAP=1 docker compose -f $(COMPOSE_GALERA) up -d galera_01
	@echo ">> ⏳ Waiting for Node 1 to bootstrap..."
	@until MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3511 -u root -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 1; done
	@echo "✅ Node 1 is Synced."
	@echo ">> 🚀 Joining Node 2..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_02
	@echo ">> ⏳ Waiting for Node 2 to join..."
	@until MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3512 -u root -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 2 is Synced."
	@echo ">> 🚀 Joining Node 3..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_03
	@echo ">> ⏳ Waiting for Node 3 to join..."
	@until MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3513 -u root -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 3 is Synced."
	@echo ">> 🚀 Starting Load Balancer..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate haproxy_galera
	@echo "✅ Cluster is fully SEQUENTIALLY BOOTSTRAPPED and ready."

emergency-galera: ## Emergency start of a single Galera node (Usage: make emergency-galera NODE=1|2|3)
	@if [ -z "$(NODE)" ]; then echo "❌ Error: NODE variable is required (e.g., make emergency-galera NODE=1)"; exit 1; fi
	@SERVICE=$$(case "$(NODE)" in 2) echo "galera_02";; 3) echo "galera_03";; *) echo "galera_01";; esac); \
	echo ">> 🚨 Stopping all Galera nodes for emergency restart..."; \
	docker compose -f $(COMPOSE_GALERA) down; \
	echo ">> 🚨 Emergency Bootstrapping Node $(NODE) ($$SERVICE)..."; \
	MARIADB_GALERA_BOOTSTRAP=1 docker compose -f $(COMPOSE_GALERA) up -d $$SERVICE

down-galera: ## Stop Galera cluster
	docker compose -f $(COMPOSE_GALERA) down

logs-galera: ## Follow Galera cluster logs
	docker compose -f $(COMPOSE_GALERA) logs -f

## Replication Cluster
up-repli: stop build-image gen-ssl down-galera ## Start Replication cluster
	docker compose -f $(COMPOSE_REPLI) up -d

emergency-repli: ## Emergency start of a single Replication node (Usage: make emergency-repli NODE=1|2|3)
	@if [ -z "$(NODE)" ]; then echo "❌ Error: NODE variable is required (e.g., make emergency-repli NODE=1)"; exit 1; fi
	@SERVICE=$$(case "$(NODE)" in 2) echo "mariadb_02";; 3) echo "mariadb_03";; *) echo "mariadb_01";; esac); \
	echo ">> 🚨 Stopping all Replication nodes for emergency restart..."; \
	docker compose -f $(COMPOSE_REPLI) down; \
	echo ">> 🚨 Emergency Starting Node $(NODE) ($$SERVICE)..."; \
	docker compose -f $(COMPOSE_REPLI) up -d $$SERVICE

down-repli: ## Stop Replication cluster
	docker compose -f $(COMPOSE_REPLI) down

logs-repli: ## Follow Replication cluster logs
	docker compose -f $(COMPOSE_REPLI) logs -f

test-repli: ## Run replication tests on the active cluster
	bash ./tests/test_repli.sh

setup-repli: ## Configure Master/Slave relationship
	bash ./scripts/setup_repli.sh

test-lb-galera: ## Specifically test the HAProxy load balancer for Galera
	bash ./tests/test_haproxy_galera.sh

test-galera: ## Run the Galera functional test suite
	bash ./tests/test_galera.sh

test-perf-repli: ## Run performance tests on Replication (Usage: make test-perf-repli PROFILE=light ACTION=run)
	bash ./tests/test_perf_repli.sh $(PROFILE) $(ACTION)

test-perf-galera: ## Run performance tests on Galera (Usage: make test-perf-galera PROFILE=light ACTION=run)
	bash ./tests/test_perf_galera.sh $(PROFILE) $(ACTION)

## Backup & Restore (Logical)
backup-galera: ## Backup Galera cluster (Usage: make backup-galera [DB=name])
	bash ./scripts/backup_logical.sh galera $(DB)

restore-galera: ## Restore Galera cluster (Usage: make restore-galera FILE=filename.sql.gz)
	bash ./scripts/restore_logical.sh galera $(FILE)

backup-repli: ## Backup Replication cluster (Usage: make backup-repli [DB=name])
	bash ./scripts/backup_logical.sh repli $(DB)

restore-repli: ## Restore Replication cluster (Usage: make restore-repli FILE=filename.sql.gz)
	bash ./scripts/restore_logical.sh repli $(FILE)

## Backup & Restore (Physical - MariaBackup)
backup-phys-galera: ## Physical backup Galera (Usage: make backup-phys-galera)
	bash ./scripts/backup_physical.sh galera

restore-phys-galera: ## Physical restore Galera (Usage: make restore-phys-galera FILE=filename.tar.gz)
	bash ./scripts/restore_physical.sh galera $(FILE)

backup-phys-repli: ## Physical backup Replication (Usage: make backup-phys-repli)
	./scripts/backup_physical.sh repli

restore-phys-repli: ## Physical restore Replication (Usage: make restore-phys-repli FILE=filename.tar.gz)
	./scripts/restore_physical.sh repli $(FILE)

## Data Injection
sync-test-db: ## Synchronize the test database submodule from remote master
	@echo ">> 🔄 Synchronizing test_db submodule..."
	@git submodule update --remote --merge $(TEST_DB_DIR)
	@echo "✅ test_db submodule synchronized."

inject-employee-galera: ## Sequential: Full Galera bootstrap and inject employees.sql
	@echo ">> 💉 Injecting employees database into Galera..."
	@if [ "$${GITHUB_ACTIONS:-false}" = "true" ]; then \
		docker compose -f $(COMPOSE_GALERA) exec -T -e MYSQL_PWD="$${DB_ROOT_PASSWORD}" galera_01 mariadb -u root -e "CREATE DATABASE IF NOT EXISTS employees; USE employees; CREATE TABLE IF NOT EXISTS departments (dept_no CHAR(4) PRIMARY KEY, dept_name VARCHAR(40) UNIQUE KEY); INSERT IGNORE INTO departments VALUES ('d001','Marketing'),('d002','Finance'),('d003','Human Resources'),('d004','Production');"; \
	else \
		if [ ! -f $(TEST_DB_DIR)/employees/employees.sql ]; then git submodule update --init --recursive $(TEST_DB_DIR) || git clone $(TEST_DB_REPO) $(TEST_DB_DIR); fi; \
		docker compose -f $(COMPOSE_GALERA) cp $(TEST_DB_DIR)/employees galera_01:/var/backups/employees; \
		docker compose -f $(COMPOSE_GALERA) exec -T -e MYSQL_PWD="$${DB_ROOT_PASSWORD}" -w /var/backups/employees galera_01 sh -c "mariadb -u root < employees.sql"; \
	fi
	@echo "✅ employees.sql injected into Galera cluster."

inject-sakila-galera: ## Sequential: Full Galera bootstrap and inject sakila database
	@echo ">> 💉 Injecting sakila schema into Galera..."
	@cd $(TEST_DB_DIR)/sakila && MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3511 -u root < sakila-mv-schema.sql
	@echo ">> 💉 Injecting sakila data into Galera..."
	@cd $(TEST_DB_DIR)/sakila && MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3511 -u root < sakila-mv-data.sql
	@echo "✅ sakila database injected into Galera cluster."

inject-employee-repli: ## Sequential: Full Replication bootstrap and inject employees.sql
	@echo ">> 💉 Injecting employees database into Replication (Master)..."
	@cd $(TEST_DB_DIR)/employees && MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3411 -u root < employees.sql
	@echo "✅ employees.sql injected into Replication cluster."

inject-sakila-repli: ## Sequential: Full Replication bootstrap and inject sakila database
	@echo ">> 💉 Injecting sakila schema into Replication (Master)..."
	@cd $(TEST_DB_DIR)/sakila && MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3411 -u root < sakila-mv-schema.sql
	@echo ">> 💉 Injecting sakila data into Replication (Master)..."
	@cd $(TEST_DB_DIR)/sakila && MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3411 -u root < sakila-mv-data.sql
	@echo "✅ sakila database injected into Replication cluster."

## Full Cycle Targets (CI/CD style)
clean-reports:
	rm -rf reports/*.md reports/*.html

full-repli: clean-repli clean-ssl clean-reports up-repli setup-repli test-repli ## Full cycle for Replication: Clean, Start, Setup, and Test

full-galera: clean-galera clean-ssl clean-reports bootstrap-galera down-galera up-galera test-galera ## Full cycle for Galera: Clean, Start (Sequential), and Test

## Utility
clean-galera: down-galera ## Stop Galera and remove all data/backups (CAUTION!)
	@docker run --rm -v "$(CURDIR):/workspace" alpine sh -c 'rm -rf /workspace/gdatadir_* /workspace/gbackups_*' 2>/dev/null || rm -rf gdatadir_* gbackups_*

clean-repli: down-repli ## Stop Replication and remove all data/backups (CAUTION!)
	@docker run --rm -v "$(CURDIR):/workspace" alpine sh -c 'rm -rf /workspace/datadir_* /workspace/backups_*' 2>/dev/null || rm -rf datadir_* backups_*

gen-profiles: ## Generate shell profile files with aliases
	bash ./scripts/gen_profiles.sh

gen-ssl: ## Generate SSL certificates for MariaDB
	bash ./scripts/gen_ssl.sh

clean-ssl: ## Remove SSL certificates (REVERSIBLE)
	@docker run --rm -v "$(CURDIR):/workspace" alpine sh -c 'rm -rf /workspace/ssl' 2>/dev/null || rm -rf ssl/

renew-ssl-galera: ## Force SSL certificate regeneration and reload on active Galera nodes
	@echo ">> 🔄 Regenerating SSL certificates..."
	rm -rf ssl/
	bash ./scripts/gen_ssl.sh
	@echo ">> 🚀 Reloading SSL on Galera nodes..."
	@MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3511 -u root -e "FLUSH SSL;" && echo "✅ Node 1 reloaded"
	@MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3512 -u root -e "FLUSH SSL;" && echo "✅ Node 2 reloaded"
	@MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3513 -u root -e "FLUSH SSL;" && echo "✅ Node 3 reloaded"
	@echo "✨ Galera zero-downtime SSL rotation completed."

renew-ssl-repli: ## Force SSL certificate regeneration and reload on active Replication nodes
	@echo ">> 🔄 Regenerating SSL certificates..."
	rm -rf ssl/
	bash ./scripts/gen_ssl.sh
	@echo ">> 🚀 Reloading SSL on Replication nodes..."
	@MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3411 -u root -e "FLUSH SSL;" && echo "✅ Node 1 reloaded"
	@MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3412 -u root -e "FLUSH SSL;" && echo "✅ Node 2 reloaded"
	@MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3413 -u root -e "FLUSH SSL;" && echo "✅ Node 3 reloaded"
	@echo "✨ Replication zero-downtime SSL rotation completed."

renew-ssl: renew-ssl-galera ## [DEPRECATED] Use renew-ssl-galera or renew-ssl-repli

gen-ssl-innodb: ## Generate TLS certificates for MySQL InnoDB Cluster
	bash ./scripts/gen_ssl_innodb.sh

gen-ssl-pgpool: ## Generate TLS certificates for PostgreSQL PgPool-II
	bash ./scripts/gen_ssl_pgpool.sh

gen-ssl-mongo: ## Generate TLS certificates for MongoDB ReplicaSet
	bash ./scripts/gen_ssl_mongo.sh

gen-ssl-patroni: ## Generate TLS certificates for Patroni PostgreSQL
	bash ./scripts/gen_ssl_patroni.sh

gen-ssl-all: gen-ssl gen-ssl-innodb gen-ssl-pgpool gen-ssl-mongo gen-ssl-patroni ## Generate TLS certificates for ALL products
	@echo "✅ All TLS certificates generated."

check-ssl-all: ## Verify TLS certificate validity for all products
	@echo "🔍 Checking TLS certificates..."
	@if command -v go >/dev/null 2>&1; then \
		go run ./cmd/mdb pki verify all; \
	fi
	@RET=0; \
	for d in ssl ssl/innodb ssl/pgpool ssl/mongo ssl/certs/mongo8 ssl/patroni; do \
		if [ -d "$$d" ]; then \
			CA=$$(ls $$d/ca-cert.pem $$d/ca.pem 2>/dev/null | head -1); \
			CERT=$$(ls $$d/server-cert.pem $$d/server.crt 2>/dev/null | head -1); \
			if [ -n "$$CA" ] && [ -n "$$CERT" ]; then \
				if openssl verify -CAfile "$$CA" "$$CERT" >/dev/null 2>&1; then \
					echo "✅ $$d: valid"; \
				else \
					echo "❌ $$d: INVALID"; \
					RET=1; \
				fi; \
			else \
				echo "⚠️  $$d: no certificates found"; \
			fi; \
		else \
			echo "⏭️  $$d: directory not found"; \
		fi; \
	done; \
	exit $$RET

clean-data: clean-galera clean-repli clean-pg18 clean-ssl ## Remove ALL data, backup, and SSL directories (CAUTION!)

## Logs & Troubleshooting
logs-error-galera: ## Read last 100 lines of error logs for Galera (Usage: make logs-error-galera [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "galera_02";; 3) echo "galera_03";; *) echo "galera_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "galera02";; 3) echo "galera03";; *) echo "galera01";; esac); \
	docker compose -f $(COMPOSE_GALERA) exec $$SERVICE tail -n 100 /var/lib/mysql/$$HOST.err

follow-error-galera: ## Stream error logs for Galera (Usage: make follow-error-galera [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "galera_02";; 3) echo "galera_03";; *) echo "galera_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "galera02";; 3) echo "galera03";; *) echo "galera01";; esac); \
	docker compose -f $(COMPOSE_GALERA) exec $$SERVICE tail -f /var/lib/mysql/$$HOST.err

logs-slow-galera: ## Read last 100 lines of slow query logs for Galera (Usage: make logs-slow-galera [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "galera_02";; 3) echo "galera_03";; *) echo "galera_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "galera02";; 3) echo "galera03";; *) echo "galera01";; esac); \
	docker compose -f $(COMPOSE_GALERA) exec $$SERVICE tail -n 100 /var/lib/mysql/$$HOST-slow.log

follow-slow-galera: ## Stream slow query logs for Galera (Usage: make follow-slow-galera [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "galera_02";; 3) echo "galera_03";; *) echo "galera_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "galera02";; 3) echo "galera03";; *) echo "galera01";; esac); \
	docker compose -f $(COMPOSE_GALERA) exec $$SERVICE tail -f /var/lib/mysql/$$HOST-slow.log

logs-error-repli: ## Read last 100 lines of error logs for Replication (Usage: make logs-error-repli [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "mariadb_02";; 3) echo "mariadb_03";; *) echo "mariadb_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "frm02";; 3) echo "frm03";; *) echo "frm01";; esac); \
	docker compose -f $(COMPOSE_REPLI) exec $$SERVICE tail -n 100 /var/lib/mysql/$$HOST.err

follow-error-repli: ## Stream error logs for Replication (Usage: make follow-error-repli [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "mariadb_02";; 3) echo "mariadb_03";; *) echo "mariadb_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "frm02";; 3) echo "frm03";; *) echo "frm01";; esac); \
	docker compose -f $(COMPOSE_REPLI) exec $$SERVICE tail -f /var/lib/mysql/$$HOST.err

logs-slow-repli: ## Read last 100 lines of slow query logs for Replication (Usage: make logs-slow-repli [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "mariadb_02";; 3) echo "mariadb_03";; *) echo "mariadb_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "frm02";; 3) echo "frm03";; *) echo "frm01";; esac); \
	docker compose -f $(COMPOSE_REPLI) exec $$SERVICE tail -n 100 /var/lib/mysql/$$HOST-slow.log

follow-slow-repli: ## Stream slow query logs for Replication (Usage: make follow-slow-repli [NODE=1|2|3])
	@SERVICE=$$(case "$(NODE)" in 2) echo "mariadb_02";; 3) echo "mariadb_03";; *) echo "mariadb_01";; esac); \
	HOST=$$(case "$(NODE)" in 2) echo "frm02";; 3) echo "frm03";; *) echo "frm01";; esac); \
	docker compose -f $(COMPOSE_REPLI) exec $$SERVICE tail -f /var/lib/mysql/$$HOST-slow.log

check-galera: ## Check Galera cluster status and key variables (Usage: make check-galera [NODE=1|2|3])
	@NODE_PORT=$$(case "$(NODE)" in 2) echo "3512";; 3) echo "3513";; *) echo "3511";; esac); \
	echo ">> 📊 Galera Status (Node $${NODE:-1} @ port $$NODE_PORT)..."; \
	MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P $$NODE_PORT -u root -e "\
		SELECT VARIABLE_NAME, VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME IN ('WSREP_CLUSTER_SIZE', 'WSREP_LOCAL_STATE_COMMENT', 'WSREP_CONNECTED', 'WSREP_READY'); \
		SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; \
		SHOW VARIABLES LIKE 'wsrep_slave_threads'; \
		SHOW VARIABLES LIKE 'wsrep_provider_options';"

check-repli: ## Check Replication cluster status and key variables (Usage: make check-repli [NODE=1|2|3])
	@NODE_PORT=$$(case "$(NODE)" in 2) echo "3412";; 3) echo "3413";; *) echo "3411";; esac); \
	echo ">> 📊 Replication Status (Node $${NODE:-1} @ port $$NODE_PORT)..."; \
	MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P $$NODE_PORT -u root -e "\
		SHOW SLAVE STATUS\G \
		SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; \
		SHOW VARIABLES LIKE 'read_only';" ; \
	if [ "$$NODE_PORT" = "3411" ]; then \
		echo ">> 🛡️ Master Status:"; \
		MYSQL_PWD="$${DB_ROOT_PASSWORD}" mariadb -h 127.0.0.1 -P 3411 -u root -e "SHOW MASTER STATUS\G"; \
	fi
