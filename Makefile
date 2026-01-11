# Makefile to orchestrate database containers via Docker Compose

# --- Configuration ---
# Use the bash shell for richer features
SHELL := /bin/bash

# --- Main Targets ---
.PHONY: help mycnf client info mysql93 mysql84 mysql80 mariadb114 mariadb1011 mariadb106 percona84 percona80 stop status logs \
        build-image up-galera down-galera logs-galera up-repli down-repli logs-repli test-repli test-galera \
        clean-data clean-galera clean-repli full-galera full-repli clone-test-db inject-employee-galera \
        inject-sakila-galera inject-employee-repli inject-sakila-repli inject-employee inject-sakila \
        gen-ssl clean-ssl renew-ssl renew-ssl-galera renew-ssl-repli emergency-galera emergency-repli check-galera check-repli

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
	@printf "    \033[1mlogs\033[0m          - 📄 Displays logs for all containers (e.g., make logs service=mysql93).\n"
	@printf "    \033[1mmycnf\033[0m         - 🔑 Generates the .my.cnf file for the MySQL client.\n"
	@printf "    \033[1mclient\033[0m        - 💻 Starts a MySQL client on the active database.\n"
	@printf "\n"
	@printf "  \033[1;32mMySQL:\033[0m\n"
	@printf "    \033[1mmysql93\033[0m       - Starts MySQL 9.3\n"
	@printf "    \033[1mmysql84\033[0m       - Starts MySQL 8.4\n"
	@printf "    \033[1mmysql80\033[0m       - Starts MySQL 8.0\n"
	@printf "    \033[1mmysql57\033[0m       - Starts MySQL 5.7\n"
	@printf "\n"
	@printf "  \033[1;32mMariaDB:\033[0m\n"
	@printf "    \033[1mmariadb114\033[0m    - Starts MariaDB 11.4\n"
	@printf "    \033[1mmariadb1011\033[0m   - Starts MariaDB 10.11\n"
	@printf "    \033[1mmariadb106\033[0m    - Starts MariaDB 10.6\n"
	@printf "\n"
	@printf "  \033[1;32mMariaDB Clusters (Galera & Replication):\033[0m\n"
	@printf "    \033[1mup-galera\033[0m     - 🚀 Starts Galera cluster (Sequential bootstrap)\n"
	@printf "    \033[1mup-repli\033[0m      - 🚀 Starts Replication cluster\n"
	@printf "    \033[1mcheck-galera\033[0m  - 📊 Checks Galera status\n"
	@printf "    \033[1mcheck-repli\033[0m   - 📊 Checks Replication status\n"
	@printf "    \033[1mtest-galera\033[0m   - 🧪 Runs Galera tests\n"
	@printf "    \033[1mtest-repli\033[0m    - 🧪 Runs Replication tests\n"
	@printf "\n"
	@printf "  \033[1;32mPercona Server:\033[0m\n"
	@printf "    \033[1mpercona84\033[0m     - Starts Percona Server 8.4\n"
	@printf "    \033[1mpercona80\033[0m     - Starts Percona Server 8.0\n"
	@printf "\n"

# --- Management Commands ---

# 🛑 Stops and removes all containers, networks, and orphans
stop:
	@echo "🔥 Stopping and cleaning up containers..."
	@docker compose down --remove-orphans
	@docker ps | grep -v CONTAINER | grep -E '(traefik|mysql|percona|mariadb)-' | awk '{print $$1}' | xargs -n1 docker stop || true

# 📊 Displays the status of active containers
status:
	@echo "📊 Docker Compose Status:"
	@docker compose ps

# ℹ️ Provides information about the active DB service and displays status/logs
info:
	@DB_SERVICE=$$(docker compose ps --services --filter "status=running" | grep -v traefik); \
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
	@DB_SERVICE=$$(docker compose ps --services --filter "status=running" | grep -v traefik); \
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
	@if [ -z "$$(grep -v '^#' .env | xargs |grep DB_ROOT_PASSWORD)" ]; then \
		printf "\n\033[1;31m❌ Error: DB_ROOT_PASSWORD is not defined in the .env file.\033[0m\n\n"; \
		exit 1; \
	fi
	@# Generate the .my.cnf file in the user's home directory
	@printf "[client]\nuser=root\npassword=%s\nhost=127.0.0.1\n" "$$(cat .env | sed 's/#.*//g' |grep DB_ROOT_PASSWORD| xargs|cut -d= -f2)" > $${HOME}/.my.cnf
	@# Apply restrictive permissions for security
	@chmod 600 $${HOME}/.my.cnf
	@printf "✅ .my.cnf file generated and secured in your home directory (~/.my.cnf).\n"

# 💻 Starts a MySQL client on the active DB
client:
	@if [ ! -f .env ]; then \
		printf "❌ .env file is missing. Cannot retrieve password.\n"; \
		exit 1; \
	fi
	@export DB_ROOT_PASSWORD=$$(sed 's/#.*//g' .env|grep DB_ROOT_PASSWORD| xargs|cut -d= -f2); \
	#echo "DB_ROOT_PASSWORD is set to: $${DB_ROOT_PASSWORD}"; \
	DB_SERVICE=$$(docker compose ps --services --filter "status=running" | grep -v traefik); \
	DB_CONTAINER=$$(docker compose ps $${DB_SERVICE} --format "{{.Names}}"); \
	if [ -n "$${DB_SERVICE}" ]; then \
		printf "💻 Connecting MySQL client to \033[1;32m%s\033[0m...\n" "$${DB_SERVICE}"; \
		docker exec -it "$${DB_CONTAINER}" mysql -uroot -p"$${DB_ROOT_PASSWORD}"; \
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
	@export DB_ROOT_PASSWORD=$$(sed 's/#.*//g' .env|grep DB_ROOT_PASSWORD| xargs|cut -d= -f2); \
	if [ ! -d "test_db" ]; then \
		printf "Cloning 'test_db' repository...\n"; \
		git clone https://github.com/datacharmer/test_db.git; \
	fi; \
	DB_CONTAINER=$$(docker compose ps $(service) --format "{{.Names}}"); \
	ADMIN_CMD=$$(docker exec "$${DB_CONTAINER}" sh -c 'command -v mysqladmin || command -v mariadb-admin' 2>/dev/null); \
	printf "⏳ Waiting for %s to be ready...\n" "$${DB_CONTAINER}"; \
	timeout 60s bash -c "until docker exec $${DB_CONTAINER} $${ADMIN_CMD} ping -h'127.0.0.1' --silent; do sleep 1; done"; \
	MYSQL_CMD=$$(docker exec "$${DB_CONTAINER}" sh -c 'command -v mysql || command -v mariadb' 2>/dev/null); \
	if [ -z "$${MYSQL_CMD}" ]; then printf "\033[1;31m❌ Error: Neither 'mysql' nor 'mariadb' found in container.\033[0m\n"; exit 1; fi; \
	printf "Injecting data into %s using %s...\n" "$${DB_CONTAINER}" "$${MYSQL_CMD}"; \
	if [ "$(db)" = "employees" ]; then \
		docker cp test_db "$${DB_CONTAINER}:/tmp/"; \
		docker exec -i "$${DB_CONTAINER}" sh -c "cd /tmp/test_db && $${MYSQL_CMD} -uroot -p$${DB_ROOT_PASSWORD} < employees.sql"; \
		printf "✅ 'employees' database injected.\n"; \
	elif [ "$(db)" = "sakila" ]; then \
		docker cp test_db/sakila "$${DB_CONTAINER}:/tmp/"; \
		docker exec -i "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot -p$${DB_ROOT_PASSWORD} < sakila-schema.sql"; \
		docker exec -i "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot -p$${DB_ROOT_PASSWORD} < sakila-data.sql"; \
		printf "✅ 'sakila' database injected.\n"; \
	else \
		printf "\033[1;31m❌ Error: Invalid database name '%s'.\033[0m\n" "$(db)"; \
		exit 1; \
	fi

# --- Full Test Suite ---
.PHONY: test-all

test-all:
	@# List of all database services to test
	@SERVICES_TO_TEST="mysql84 mariadb114 percona84"; \
	for service in $${SERVICES_TO_TEST}; do \
		printf "\n\033[1;34m--- Testing service: %s ---\033[0m\n" "$$service"; \
		\
		printf "🚀 Starting service %s...\n" "$$service"; \
		make $$service; \
		\
		printf "⏳ Waiting for DB to be ready...\n"; \
		DB_CONTAINER=$$(docker compose ps $$service --format "{{.Names}}"); \
		ADMIN_CMD=$$(docker exec "$${DB_CONTAINER}" sh -c 'command -v mysqladmin || command -v mariadb-admin' 2>/dev/null); \
		MYSQL_CMD=$$(docker exec "$${DB_CONTAINER}" sh -c 'command -v mysql || command -v mariadb' 2>/dev/null); \
		timeout 60s bash -c "until docker exec $${DB_CONTAINER} $${ADMIN_CMD} ping -h'127.0.0.1' --silent; do sleep 1; done"; \
		\
		printf "💉 Injecting 'employees' database...\n"; \
		make inject-data service=$$service db=employees; \
		\
		printf "💉 Injecting 'sakila' database...\n"; \
		make inject-data service=$$service db=sakila; \
		\
		printf "🔍 Verifying data injection...\n"; \
		docker exec "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -p"$(DB_ROOT_PASSWORD)" -e "SHOW DATABASES;" | grep -q "employees"; \
		if [ $$? -eq 0 ]; then \
			printf "✅ 'employees' database found.\n"; \
		else \
			printf "\033[1;31m❌ 'employees' database not found.\033[0m\n"; \
			exit 1; \
		fi; \
		docker exec "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -p"$(DB_ROOT_PASSWORD)" -e "SHOW DATABASES;" | grep -q "sakila"; \
		if [ $$? -eq 0 ]; then \
			printf "✅ 'sakila' database found.\n"; \
		else \
			printf "\033[1;31m❌ 'sakila' database not found.\033[0m\n"; \
			exit 1; \
		fi; \
		\
		printf "🔍 Verifying Traefik proxy...\n"; \
		docker exec "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -p"$(DB_ROOT_PASSWORD)" -h traefik -e "SHOW DATABASES;" | grep -q "employees"; \
		if [ $$? -eq 0 ]; then \
			printf "✅ Connection via Traefik successful.\n"; \
		else \
			printf "\033[1;31m❌ Connection via Traefik failed.\033[0m\n"; \
			exit 1; \
		fi; \
		\
		printf "🛑 Stopping service %s...\n" "$$service"; \
		make stop; \
	done
	@printf "\n\033[1;32m✅ All services tested successfully!\033[0m\n"


# --- Start-up Targets by Profile ---
traefik: stop
	@echo "🚀 Starting Traefik..."
	@docker compose --profile traefik up -d

# 🐬 MySQL
mysql93: stop traefik
	@echo "🚀 Starting MySQL 9.3..."
	@docker compose --profile mysql93 up -d

mysql84: stop traefik
	@echo "🚀 Starting MySQL 8.4..."
	@docker compose --profile mysql84 up -d

mysql80: stop traefik
	@echo "🚀 Starting MySQL 8.0..."
	@docker compose --profile mysql80 up -d

mysql57: stop traefik
	@echo "🚀 Starting MySQL 5.7..."
	@docker compose --profile mysql57 up -d

# 🐧 MariaDB
mariadb114: stop traefik
	@echo "🚀 Starting MariaDB 11.4..."
	@docker compose --profile mariadb114 up -d

mariadb1011: stop traefik
	@echo "🚀 Starting MariaDB 10.11..."
	@docker compose --profile mariadb1011 up -d

mariadb106: stop traefik
	@echo "🚀 Starting MariaDB 10.6..."
	@docker compose --profile mariadb106 up -d

# ⚡ Percona Server
percona84: stop traefik
	@echo "🚀 Starting Percona Server 8.4..."
	@docker compose --profile percona84 up -d

percona80: stop traefik
	@echo "🚀 Starting Percona Server 8.0..."
	@docker compose --profile percona80 up -d

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
	@until mariadb -h 127.0.0.1 -P 3511 -u root -prootpass -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 1; done
	@echo "✅ Node 1 is Synced."
	@echo ">> 🚀 Joining Node 2..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_02
	@echo ">> ⏳ Waiting for Node 2 to join..."
	@until mariadb -h 127.0.0.1 -P 3512 -u root -prootpass -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 2 is Synced."
	@echo ">> 🚀 Joining Node 3..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_03
	@echo ">> ⏳ Waiting for Node 3 to join..."
	@until mariadb -h 127.0.0.1 -P 3513 -u root -prootpass -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 3 is Synced."
	@echo ">> 🚀 Starting Load Balancer..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate haproxy_galera
	@echo "✅ Cluster is fully SEQUENTIALLY BOOTSTRAPPED and ready."

bootstrap-galera: stop build-image gen-ssl down-repli ## Bootstrap a NEW Galera cluster (Sequential)
	@echo ">> 🚀 Bootstrapping Node 1 (Primary)..."
	MARIADB_GALERA_BOOTSTRAP=1 docker compose -f $(COMPOSE_GALERA) up -d galera_01
	@echo ">> ⏳ Waiting for Node 1 to bootstrap..."
	@until mariadb -h 127.0.0.1 -P 3511 -u root -prootpass -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 1; done
	@echo "✅ Node 1 is Synced."
	@echo ">> 🚀 Joining Node 2..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_02
	@echo ">> ⏳ Waiting for Node 2 to join..."
	@until mariadb -h 127.0.0.1 -P 3512 -u root -prootpass -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 2 is Synced."
	@echo ">> 🚀 Joining Node 3..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_03
	@echo ">> ⏳ Waiting for Node 3 to join..."
	@until mariadb -h 127.0.0.1 -P 3513 -u root -prootpass -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
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
	bash ./test_repli.sh

setup-repli: ## Configure Master/Slave relationship
	bash ./setup_repli.sh

test-lb-galera: ## Specifically test the HAProxy load balancer for Galera
	bash ./test_haproxy_galera.sh

test-galera: ## Run the Galera functional test suite
	bash ./test_galera.sh

test-perf-repli: ## Run performance tests on Replication (Usage: make test-perf-repli PROFILE=light ACTION=run)
	bash ./test_perf_repli.sh $(PROFILE) $(ACTION)

test-perf-galera: ## Run performance tests on Galera (Usage: make test-perf-galera PROFILE=light ACTION=run)
	bash ./test_perf_galera.sh $(PROFILE) $(ACTION)

## Backup & Restore (Logical)
backup-galera: ## Backup Galera cluster (Usage: make backup-galera [DB=name])
	bash ./backup_logical.sh galera $(DB)

restore-galera: ## Restore Galera cluster (Usage: make restore-galera FILE=filename.sql.gz)
	bash ./restore_logical.sh galera $(FILE)

backup-repli: ## Backup Replication cluster (Usage: make backup-repli [DB=name])
	bash ./backup_logical.sh repli $(DB)

restore-repli: ## Restore Replication cluster (Usage: make restore-repli FILE=filename.sql.gz)
	bash ./restore_logical.sh repli $(FILE)

## Backup & Restore (Physical - MariaBackup)
backup-phys-galera: ## Physical backup Galera (Usage: make backup-phys-galera)
	bash ./backup_physical.sh galera

restore-phys-galera: ## Physical restore Galera (Usage: make restore-phys-galera FILE=filename.tar.gz)
	bash ./restore_physical.sh galera $(FILE)

backup-phys-repli: ## Physical backup Replication (Usage: make backup-phys-repli)
	./backup_physical.sh repli

restore-phys-repli: ## Physical restore Replication (Usage: make restore-phys-repli FILE=filename.tar.gz)
	./restore_physical.sh repli $(FILE)

## Data Injection
TEST_DB_REPO_CLUSTER = https://github.com/jmrenouard/test_db
TEST_DB_DIR_CLUSTER = /var/tmp/test_db

clone-test-db-cluster: ## Clone the test database repository to /var/tmp
	@if [ ! -d "$(TEST_DB_DIR_CLUSTER)" ]; then \
		echo ">> 📥 Cloning test_db repository to $(TEST_DB_DIR_CLUSTER)..."; \
		git clone $(TEST_DB_REPO_CLUSTER) $(TEST_DB_DIR_CLUSTER); \
	else \
		echo ">> 🔄 test_db repository already exists in $(TEST_DB_DIR_CLUSTER), pulling updates..."; \
		(cd $(TEST_DB_DIR_CLUSTER) && git pull); \
	fi

inject-employee-galera: clone-test-db-cluster ## Sequential: Full Galera bootstrap and inject employees.sql
	@echo ">> 💉 Injecting employees database into Galera..."
	@cd $(TEST_DB_DIR_CLUSTER) && mariadb -h 127.0.0.1 -P 3511 -u root -prootpass < employees.sql
	@echo "✅ employees.sql injected into Galera cluster."

inject-sakila-galera: clone-test-db-cluster ## Sequential: Full Galera bootstrap and inject sakila database
	@echo ">> 💉 Injecting sakila schema into Galera..."
	@cd $(TEST_DB_DIR_CLUSTER)/sakila && mariadb -h 127.0.0.1 -P 3511 -u root -prootpass < sakila-mv-schema.sql
	@echo ">> 💉 Injecting sakila data into Galera..."
	@cd $(TEST_DB_DIR_CLUSTER)/sakila && mariadb -h 127.0.0.1 -P 3511 -u root -prootpass < sakila-mv-data.sql
	@echo "✅ sakila database injected into Galera cluster."

inject-employee-repli: clone-test-db-cluster ## Sequential: Full Replication bootstrap and inject employees.sql
	@echo ">> 💉 Injecting employees database into Replication (Master)..."
	@cd $(TEST_DB_DIR_CLUSTER) && mariadb -h 127.0.0.1 -P 3411 -u root -prootpass < employees.sql
	@echo "✅ employees.sql injected into Replication cluster."

inject-sakila-repli: clone-test-db-cluster ## Sequential: Full Replication bootstrap and inject sakila database
	@echo ">> 💉 Injecting sakila schema into Replication (Master)..."
	@cd $(TEST_DB_DIR_CLUSTER)/sakila && mariadb -h 127.0.0.1 -P 3411 -u root -prootpass < sakila-mv-schema.sql
	@echo ">> 💉 Injecting sakila data into Replication (Master)..."
	@cd $(TEST_DB_DIR_CLUSTER)/sakila && mariadb -h 127.0.0.1 -P 3411 -u root -prootpass < sakila-mv-data.sql
	@echo "✅ sakila database injected into Replication cluster."

## Full Cycle Targets (CI/CD style)
clean-reports:
	rm -rf reports/*.md reports/*.html

full-repli: clean-repli clean-ssl clean-reports up-repli setup-repli test-repli ## Full cycle for Replication: Clean, Start, Setup, and Test

full-galera: clean-galera clean-ssl clean-reports bootstrap-galera down-galera up-galera test-galera ## Full cycle for Galera: Clean, Start (Sequential), and Test

## Utility
clean-galera: down-galera ## Stop Galera and remove all data/backups (CAUTION!)
	rm -rf gdatadir_* gbackups_*

clean-repli: down-repli ## Stop Replication and remove all data/backups (CAUTION!)
	rm -rf datadir_* backups_*

gen-profiles: ## Generate shell profile files with aliases
	bash ./gen_profiles.sh

gen-ssl: ## Generate SSL certificates for MariaDB
	bash ./gen_ssl.sh

clean-ssl: ## Remove SSL certificates (REVERSIBLE)
	rm -rf ssl/

renew-ssl-galera: ## Force SSL certificate regeneration and reload on active Galera nodes
	@echo ">> 🔄 Regenerating SSL certificates..."
	rm -rf ssl/
	bash ./gen_ssl.sh
	@echo ">> 🚀 Reloading SSL on Galera nodes..."
	@mariadb -h 127.0.0.1 -P 3511 -u root -prootpass -e "FLUSH SSL;" && echo "✅ Node 1 reloaded"
	@mariadb -h 127.0.0.1 -P 3512 -u root -prootpass -e "FLUSH SSL;" && echo "✅ Node 2 reloaded"
	@mariadb -h 127.0.0.1 -P 3513 -u root -prootpass -e "FLUSH SSL;" && echo "✅ Node 3 reloaded"
	@echo "✨ Galera zero-downtime SSL rotation completed."

renew-ssl-repli: ## Force SSL certificate regeneration and reload on active Replication nodes
	@echo ">> 🔄 Regenerating SSL certificates..."
	rm -rf ssl/
	bash ./gen_ssl.sh
	@echo ">> 🚀 Reloading SSL on Replication nodes..."
	@mariadb -h 127.0.0.1 -P 3411 -u root -prootpass -e "FLUSH SSL;" && echo "✅ Node 1 reloaded"
	@mariadb -h 127.0.0.1 -P 3412 -u root -prootpass -e "FLUSH SSL;" && echo "✅ Node 2 reloaded"
	@mariadb -h 127.0.0.1 -P 3413 -u root -prootpass -e "FLUSH SSL;" && echo "✅ Node 3 reloaded"
	@echo "✨ Replication zero-downtime SSL rotation completed."

renew-ssl: renew-ssl-galera ## [DEPRECATED] Use renew-ssl-galera or renew-ssl-repli

clean-data: clean-galera clean-repli clean-ssl ## Remove ALL data, backup, and SSL directories (CAUTION!)

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
	echo ">> 📊 Galera Status (Node $(NODE:-1) @ port $$NODE_PORT)..."; \
	mariadb -h 127.0.0.1 -P $$NODE_PORT -u root -prootpass -e "\
		SELECT VARIABLE_NAME, VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME IN ('WSREP_CLUSTER_SIZE', 'WSREP_LOCAL_STATE_COMMENT', 'WSREP_CONNECTED', 'WSREP_READY'); \
		SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; \
		SHOW VARIABLES LIKE 'wsrep_slave_threads'; \
		SHOW VARIABLES LIKE 'wsrep_provider_options';"

check-repli: ## Check Replication cluster status and key variables (Usage: make check-repli [NODE=1|2|3])
	@NODE_PORT=$$(case "$(NODE)" in 2) echo "3412";; 3) echo "3413";; *) echo "3411";; esac); \
	echo ">> 📊 Replication Status (Node $(NODE:-1) @ port $$NODE_PORT)..."; \
	mariadb -h 127.0.0.1 -P $$NODE_PORT -u root -prootpass -e "\
		SHOW SLAVE STATUS\G \
		SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; \
		SHOW VARIABLES LIKE 'read_only';" ; \
	if [ "$$NODE_PORT" = "3411" ]; then \
		echo ">> 🛡️ Master Status:"; \
		mariadb -h 127.0.0.1 -P 3411 -u root -prootpass -e "SHOW MASTER STATUS\G"; \
	fi
