# Makefile to orchestrate database containers via Docker Compose

# --- Configuration ---
# Use the bash shell for richer features
SHELL := /bin/bash

# --- Main Targets ---
.PHONY: help mycnf client info mysql93 mysql84 mysql80 mariadb114 mariadb1011 mariadb106 percona84 percona80 stop status logs

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
