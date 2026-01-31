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

# --- Main Targets ---
.PHONY: help mycnf client info mysql96 mysql84 mysql80 mysql57 mariadb118 mariadb114 mariadb1011 mariadb106 percona80 postgres17 postgres16 stop status logs \
        build-image galera-up galera-down galera-logs repli-up repli-down repli-logs test-repli test-galera \
        up-galera down-galera logs-galera up-repli down-repli logs-repli \
        clean-data clean-galera clean-repli full-galera full-repli clone-test-db inject-employee-galera \
        inject-sakila-galera inject-employee-repli inject-sakila-repli inject-employees inject-employee inject-sakila \
        gen-ssl clean-ssl renew-ssl renew-ssl-galera renew-ssl-repli emergency-galera emergency-repli check-galera check-repli \
        test-config start verify inject sync-test-db

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
	@printf "    \033[1mlogs\033[0m          - 📄 Displays logs for all containers (e.g., make logs service=mysql93).\n"
	@printf "    \033[1mmycnf\033[0m         - 🔑 Generates the .my.cnf file for the MySQL client.\n"
	@printf "    \033[1mclient\033[0m        - 💻 Starts a MySQL client on the active database.\n"
	@printf "\n"
	@printf "  \033[1;32mMySQL:\033[0m\n"
	@printf "    \033[1mmysql96\033[0m       - Starts MySQL 9.6\n"
	@printf "    \033[1mmysql84\033[0m       - Starts MySQL 8.4\n"
	@printf "    \033[1mmysql80\033[0m       - Starts MySQL 8.0\n"
	@printf "    \033[1mmysql57\033[0m       - Starts MySQL 5.7\n"
	@printf "\n"
	@printf "  \033[1;32mMariaDB:\033[0m\n"
	@printf "    \033[1mmariadb118\033[0m    - Starts MariaDB 11.8\n"
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
	@printf "    \033[1mtest-config\033[0m   - 🧪 Validates orchestration and configuration\n"
	@printf "\n"
	@printf "  \033[1;32mData Injection:\033[0m\n"
	@printf "    \033[1minject-employees\033[0m - 💉 Injects employees database (Auto-detect environment)\n"
	@printf "    \033[1minject-sakila\033[0m    - 💉 Injects sakila database (Auto-detect environment)\n"
	@printf "    \033[1minject\033[0m           - 💉 Alias for inject-employees on default service\n"
	@printf "\n"
	@printf "  \033[1;32mPercona Server:\033[0m\n"
	@printf "    \033[1mpercona80\033[0m     - Starts Percona Server 8.0\n"
	@printf "\n"
	@printf "  \033[1;32mPostgreSQL:\033[0m\n"
	@printf "    \033[1mpostgres17\033[0m    - Starts PostgreSQL 17\n"
	@printf "    \033[1mpostgres16\033[0m    - Starts PostgreSQL 16\n"
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
	@DB_SERVICE=$$($(GET_ACTIVE_SERVICE)); \
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
	if [ -n "$${DB_SERVICE}" ]; then \
		printf "💻 Connecting MySQL client to \033[1;32m%s\033[0m...\n" "$${DB_SERVICE}"; \
		docker exec -it "$${DB_CONTAINER}" mysql -uroot -p"$(DB_ROOT_PASSWORD)"; \
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
			timeout 120s bash -c "until docker exec $${DB_CONTAINER} sh -c 'mysql -uroot -p\"$(DB_ROOT_PASSWORD)\" -e \"SELECT 1\" 2>/dev/null | grep -q 1 || mariadb -uroot -p\"$(DB_ROOT_PASSWORD)\" -e \"SELECT 1\" 2>/dev/null | grep -q 1'; do sleep 2; done" || (printf \"\033[1;31m❌ Error: Database reached timeout without becoming ready. Check credentials or logs.\033[0m\n\" && exit 1); \
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
				if [ "$(service)" = "mysql96" ]; then \
					printf "⚠️ Skipping 'employees' for mysql96 (Nested source regression). Use sakila instead.\n"; \
				else \
					docker cp $(TEST_DB_DIR)/employees "$${DB_CONTAINER}:/tmp/test_db" && \
					docker exec -i "$${DB_CONTAINER}" sh -c "cd /tmp/test_db && $${MYSQL_CMD} -uroot -p\"$(DB_ROOT_PASSWORD)\" < employees.sql" && \
					printf "✅ 'employees' database injected.\n"; \
				fi; \
			elif [ "$(db)" = "sakila" ]; then \
				docker cp $(TEST_DB_DIR)/sakila "$${DB_CONTAINER}:/tmp/" && \
				docker exec -i "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot -p\"$(DB_ROOT_PASSWORD)\" < sakila-mv-schema.sql" && \
				docker exec -i "$${DB_CONTAINER}" sh -c "cd /tmp/sakila && $${MYSQL_CMD} -uroot -p\"$(DB_ROOT_PASSWORD)\" < sakila-mv-data.sql" && \
				printf "✅ 'sakila' database injected.\n"; \
			fi \
			;; \
	esac

# --- Full Test Suite ---
.PHONY: test-all

test-all:
	@# List of all database services to test
	@SERVICES_TO_TEST="mysql96 mysql84 mysql80 mariadb118 mariadb114 mariadb1011 mariadb106 percona80 postgres17 postgres16"; \
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
				timeout 120s bash -c "until docker exec $${DB_CONTAINER} sh -c 'mysql -uroot -p\"$(DB_ROOT_PASSWORD)\" -e \"SELECT 1\" 2>/dev/null | grep -q 1 || mariadb -uroot -p\"$(DB_ROOT_PASSWORD)\" -e \"SELECT 1\" 2>/dev/null | grep -q 1'; do sleep 2; done" || exit 1; \
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
				docker exec "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -p"$(DB_ROOT_PASSWORD)" -e "SHOW DATABASES;" | grep -q "employees" && \
				printf "✅ 'employees' database found.\n" && \
				docker exec "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -p"$(DB_ROOT_PASSWORD)" -e "SHOW DATABASES;" | grep -q "sakila" && \
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
				docker exec "$${DB_CONTAINER}" "$${MYSQL_CMD}" -uroot -p"$(DB_ROOT_PASSWORD)" -h traefik -e "SHOW DATABASES;" | grep -q "employees" && \
				printf "✅ Connection via Traefik successful.\n" \
				;; \
		esac; \
		\
		printf "🛑 Stopping service %s...\n" "$$service" && \
		docker compose down -v; \
	done
	@printf "\n\033[1;32m✅ All services tested successfully!\033[0m\n"
	
test-config: ## Validate the current orchestration configuration, directory structure, SSL and profiles
	@echo "🚀 Running Configuration Validation..."
	bash ./tests/test_env.sh
	bash ./tests/test_config.sh
	bash ./tests/test_security_ssl.sh
	bash ./tests/test_profiles.sh


# --- Start-up Targets by Profile ---
traefik: stop
	@echo "🚀 Starting Traefik..."
	@docker compose --profile traefik up -d

# 🐬 MySQL
mysql96: stop traefik
	@echo "🚀 Starting MySQL 9.6..."
	@docker compose --profile mysql96 up -d

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
mariadb118: stop traefik
	@echo "🚀 Starting MariaDB 11.8..."
	@docker compose --profile mariadb118 up -d

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
percona80: stop traefik
	@echo "🚀 Starting Percona Server 8.0..."
	@docker compose --profile percona80 up -d

# 🐘 PostgreSQL
postgres17: stop traefik
	@echo "🚀 Starting PostgreSQL 17..."
	@docker compose --profile postgres17 up -d

postgres16: stop traefik
	@echo "🚀 Starting PostgreSQL 16..."
	@docker compose --profile postgres16 up -d

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
	@until mariadb -h 127.0.0.1 -P 3511 -u root -p"$${DB_ROOT_PASSWORD}" -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 1; done
	@echo "✅ Node 1 is Synced."
	@echo ">> 🚀 Joining Node 2..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_02
	@echo ">> ⏳ Waiting for Node 2 to join..."
	@until mariadb -h 127.0.0.1 -P 3512 -u root -p"$${DB_ROOT_PASSWORD}" -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 2 is Synced."
	@echo ">> 🚀 Joining Node 3..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_03
	@echo ">> ⏳ Waiting for Node 3 to join..."
	@until mariadb -h 127.0.0.1 -P 3513 -u root -p"$${DB_ROOT_PASSWORD}" -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 3 is Synced."
	@echo ">> 🚀 Starting Load Balancer..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate haproxy_galera
	@echo "✅ Cluster is fully SEQUENTIALLY BOOTSTRAPPED and ready."

bootstrap-galera: stop build-image gen-ssl down-repli ## Bootstrap a NEW Galera cluster (Sequential)
	@echo ">> 🚀 Bootstrapping Node 1 (Primary)..."
	MARIADB_GALERA_BOOTSTRAP=1 docker compose -f $(COMPOSE_GALERA) up -d galera_01
	@echo ">> ⏳ Waiting for Node 1 to bootstrap..."
	@until mariadb -h 127.0.0.1 -P 3511 -u root -p"$${DB_ROOT_PASSWORD}" -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 1; done
	@echo "✅ Node 1 is Synced."
	@echo ">> 🚀 Joining Node 2..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_02
	@echo ">> ⏳ Waiting for Node 2 to join..."
	@until mariadb -h 127.0.0.1 -P 3512 -u root -p"$${DB_ROOT_PASSWORD}" -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
	@echo "✅ Node 2 is Synced."
	@echo ">> 🚀 Joining Node 3..."
	docker compose -f $(COMPOSE_GALERA) up -d --no-recreate galera_03
	@echo ">> ⏳ Waiting for Node 3 to join..."
	@until mariadb -h 127.0.0.1 -P 3513 -u root -p"$${DB_ROOT_PASSWORD}" -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | grep -q "Synced"; do sleep 2; done
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
	@cd $(TEST_DB_DIR)/employees && mariadb -h 127.0.0.1 -P 3511 -u root -p"$${DB_ROOT_PASSWORD}" < employees.sql
	@echo "✅ employees.sql injected into Galera cluster."

inject-sakila-galera: ## Sequential: Full Galera bootstrap and inject sakila database
	@echo ">> 💉 Injecting sakila schema into Galera..."
	@cd $(TEST_DB_DIR)/sakila && mariadb -h 127.0.0.1 -P 3511 -u root -p"$${DB_ROOT_PASSWORD}" < sakila-mv-schema.sql
	@echo ">> 💉 Injecting sakila data into Galera..."
	@cd $(TEST_DB_DIR)/sakila && mariadb -h 127.0.0.1 -P 3511 -u root -p"$${DB_ROOT_PASSWORD}" < sakila-mv-data.sql
	@echo "✅ sakila database injected into Galera cluster."

inject-employee-repli: ## Sequential: Full Replication bootstrap and inject employees.sql
	@echo ">> 💉 Injecting employees database into Replication (Master)..."
	@cd $(TEST_DB_DIR)/employees && mariadb -h 127.0.0.1 -P 3411 -u root -p"$${DB_ROOT_PASSWORD}" < employees.sql
	@echo "✅ employees.sql injected into Replication cluster."

inject-sakila-repli: ## Sequential: Full Replication bootstrap and inject sakila database
	@echo ">> 💉 Injecting sakila schema into Replication (Master)..."
	@cd $(TEST_DB_DIR)/sakila && mariadb -h 127.0.0.1 -P 3411 -u root -p"$${DB_ROOT_PASSWORD}" < sakila-mv-schema.sql
	@echo ">> 💉 Injecting sakila data into Replication (Master)..."
	@cd $(TEST_DB_DIR)/sakila && mariadb -h 127.0.0.1 -P 3411 -u root -p"$${DB_ROOT_PASSWORD}" < sakila-mv-data.sql
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
	bash ./scripts/gen_profiles.sh

gen-ssl: ## Generate SSL certificates for MariaDB
	bash ./scripts/gen_ssl.sh

clean-ssl: ## Remove SSL certificates (REVERSIBLE)
	rm -rf ssl/

renew-ssl-galera: ## Force SSL certificate regeneration and reload on active Galera nodes
	@echo ">> 🔄 Regenerating SSL certificates..."
	rm -rf ssl/
	bash ./scripts/gen_ssl.sh
	@echo ">> 🚀 Reloading SSL on Galera nodes..."
	@mariadb -h 127.0.0.1 -P 3511 -u root -p"$${DB_ROOT_PASSWORD}" -e "FLUSH SSL;" && echo "✅ Node 1 reloaded"
	@mariadb -h 127.0.0.1 -P 3512 -u root -p"$${DB_ROOT_PASSWORD}" -e "FLUSH SSL;" && echo "✅ Node 2 reloaded"
	@mariadb -h 127.0.0.1 -P 3513 -u root -p"$${DB_ROOT_PASSWORD}" -e "FLUSH SSL;" && echo "✅ Node 3 reloaded"
	@echo "✨ Galera zero-downtime SSL rotation completed."

renew-ssl-repli: ## Force SSL certificate regeneration and reload on active Replication nodes
	@echo ">> 🔄 Regenerating SSL certificates..."
	rm -rf ssl/
	bash ./scripts/gen_ssl.sh
	@echo ">> 🚀 Reloading SSL on Replication nodes..."
	@mariadb -h 127.0.0.1 -P 3411 -u root -p"$${DB_ROOT_PASSWORD}" -e "FLUSH SSL;" && echo "✅ Node 1 reloaded"
	@mariadb -h 127.0.0.1 -P 3412 -u root -p"$${DB_ROOT_PASSWORD}" -e "FLUSH SSL;" && echo "✅ Node 2 reloaded"
	@mariadb -h 127.0.0.1 -P 3413 -u root -p"$${DB_ROOT_PASSWORD}" -e "FLUSH SSL;" && echo "✅ Node 3 reloaded"
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
	echo ">> 📊 Galera Status (Node $$( (NODE:-1) ) @ port $$NODE_PORT)..."; \
	mariadb -h 127.0.0.1 -P $$NODE_PORT -u root -p"$${DB_ROOT_PASSWORD}" -e "\
		SELECT VARIABLE_NAME, VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME IN ('WSREP_CLUSTER_SIZE', 'WSREP_LOCAL_STATE_COMMENT', 'WSREP_CONNECTED', 'WSREP_READY'); \
		SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; \
		SHOW VARIABLES LIKE 'wsrep_slave_threads'; \
		SHOW VARIABLES LIKE 'wsrep_provider_options';"

check-repli: ## Check Replication cluster status and key variables (Usage: make check-repli [NODE=1|2|3])
	@NODE_PORT=$$(case "$(NODE)" in 2) echo "3412";; 3) echo "3413";; *) echo "3411";; esac); \
	echo ">> 📊 Replication Status (Node $$( (NODE:-1) ) @ port $$NODE_PORT)..."; \
	mariadb -h 127.0.0.1 -P $$NODE_PORT -u root -p"$${DB_ROOT_PASSWORD}" -e "\
		SHOW SLAVE STATUS\G \
		SHOW VARIABLES LIKE 'innodb_buffer_pool_size'; \
		SHOW VARIABLES LIKE 'read_only';" ; \
	if [ "$$NODE_PORT" = "3411" ]; then \
		echo ">> 🛡️ Master Status:"; \
		mariadb -h 127.0.0.1 -P 3411 -u root -p"$${DB_ROOT_PASSWORD}" -e "SHOW MASTER STATUS\G"; \
	fi
