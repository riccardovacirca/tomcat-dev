# Main Project Makefile

MAKEFLAGS += --no-print-directory

PROJECTS_DIR = projects

.PHONY: build deploy help app lib postgres default

# Default target - shows help
default:
	@$(MAKE) help

help:
	@echo "Usage:"
	@echo "  make app name=<app_name> [db=<db_type>] - Generate new Maven webapp in $(PROJECTS_DIR)/"
	@echo "  make lib name=<lib_name> [db=<db_type>] - Generate new JAR library in $(PROJECTS_DIR)/"
	@echo "  make build app=<app_name>               - Build specific app from $(PROJECTS_DIR)/"
	@echo "  make deploy app=<app_name>              - Deploy specific app from $(PROJECTS_DIR)/"
	@echo "  make postgres                           - Connect to PostgreSQL database"
	@echo ""
	@echo "Database types: postgres, mariadb, sqlite"
	@echo ""
	@echo "Examples:"
	@echo "  make app name=my-webapp"
	@echo "  make app name=my-api db=postgres"
	@echo "  make lib name=my-library"
	@echo "  make lib name=auth-service db=postgres"

build:
	@if [ -z "$(app)" ]; then \
		echo "Error: app parameter required. Usage: make build app=<app_name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(PROJECTS_DIR)/$(app)" ]; then \
		echo "Error: Project '$(app)' not found in $(PROJECTS_DIR)/ directory"; \
		echo "Copy from examples/$(app) to $(PROJECTS_DIR)/$(app) first"; \
		exit 1; \
	fi
	@if [ ! -f "$(PROJECTS_DIR)/$(app)/Makefile" ]; then \
		echo "Error: No Makefile found in $(PROJECTS_DIR)/$(app)/ directory"; \
		exit 1; \
	fi
	@cd $(PROJECTS_DIR)/$(app) && $(MAKE) build

deploy:
	@if [ -z "$(app)" ]; then \
		echo "Error: app parameter required. Usage: make deploy app=<app_name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(PROJECTS_DIR)/$(app)" ]; then \
		echo "Error: Project '$(app)' not found in $(PROJECTS_DIR)/ directory"; \
		echo "Copy from examples/$(app) to $(PROJECTS_DIR)/$(app) first"; \
		exit 1; \
	fi
	@if [ ! -f "$(PROJECTS_DIR)/$(app)/Makefile" ]; then \
		echo "Error: No Makefile found in $(PROJECTS_DIR)/$(app)/ directory"; \
		exit 1; \
	fi
	@cd $(PROJECTS_DIR)/$(app) && $(MAKE) deploy

app:
	@if [ -z "$(name)" ]; then \
		echo "Error: name parameter required. Usage: make app name=<app_name> [db=<db_type>]"; \
		exit 1; \
	fi
	@if [ -n "$(db)" ]; then \
		./install.sh --create-webapp $(name) --database $(db); \
	else \
		./install.sh --create-webapp $(name); \
	fi

lib:
	@if [ -z "$(name)" ]; then \
		echo "Error: name parameter required. Usage: make lib name=<lib_name> [db=<db_type>]"; \
		exit 1; \
	fi
	@if [ -n "$(db)" ]; then \
		./install.sh --create-library $(name) --database $(db); \
	else \
		./install.sh --create-library $(name); \
	fi

postgres:
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found"; \
		exit 1; \
	fi
	@echo "Connecting to PostgreSQL database..."
	@. ./.env && echo "Database: $$POSTGRES_DB | User: $$POSTGRES_USER | Host: host.docker.internal:$$POSTGRES_PORT"
	@echo "Use \\q to quit"
	@. ./.env && PGPASSWORD=$$POSTGRES_PASSWORD psql -h host.docker.internal -p $$POSTGRES_PORT -U $$POSTGRES_USER -d $$POSTGRES_DB