# ${artifactId} Makefile

MAKEFLAGS += --no-print-directory

# Load environment variables
ifneq (,$(wildcard .env))
    include .env
    export
endif

APP_NAME = ${artifactId}
CONTAINER_NAME ?= tomcat-dev
TOMCAT_WEBAPPS = /usr/local/tomcat/webapps

# Database Configuration (with fallback defaults)
POSTGRES_CONTAINER_NAME ?= tomcat-dev-postgres
POSTGRES_USER ?= devuser
POSTGRES_PASSWORD ?= devpass123
POSTGRES_DB ?= devdb
MARIADB_CONTAINER_NAME ?= tomcat-dev-mariadb
MARIADB_USER ?= devuser
MARIADB_PASSWORD ?= devpass123
MARIADB_DATABASE ?= devdb
SQLITE_DATA_DIR ?= sqlite-data
SQLITE_DATABASE ?= devdb.sqlite

.PHONY: clean build deploy status help init-db

help:
	@echo "Targets: clean, build, deploy, status, init-db"

clean:
	@mvn clean -q

build:
	@echo "Building $(APP_NAME)..."
	@mvn package -q -DskipTests
	@echo "Build complete: target/$(APP_NAME).war"

deploy: build
	@echo "Deploying to $(CONTAINER_NAME)..."
	@rm -rf $(TOMCAT_WEBAPPS)/$(APP_NAME)*
	@cp target/$(APP_NAME).war $(TOMCAT_WEBAPPS)/
	@echo "Deployed: http://localhost:9292/$(APP_NAME)"

status:
	@ls -la $(TOMCAT_WEBAPPS)/$(APP_NAME)* 2>/dev/null || echo "Not deployed"

init-db:
#if( $dbType == "postgres" )
	@echo "Creating PostgreSQL table for items..."
	@PGPASSWORD=$(POSTGRES_PASSWORD) psql -h $(POSTGRES_CONTAINER_NAME) -p 5432 -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c \
		"CREATE TABLE IF NOT EXISTS items ( \
			id SERIAL PRIMARY KEY, \
			title VARCHAR(255) NOT NULL, \
			description TEXT, \
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP \
		);"
	@echo "PostgreSQL table created"
#elseif( $dbType == "mariadb" )
	@echo "Creating MariaDB table for items..."
	@mysql -h $(MARIADB_CONTAINER_NAME) -P 3306 -u $(MARIADB_USER) -p$(MARIADB_PASSWORD) $(MARIADB_DATABASE) -e \
		"CREATE TABLE IF NOT EXISTS items ( \
			id INT AUTO_INCREMENT PRIMARY KEY, \
			title VARCHAR(255) NOT NULL, \
			description TEXT, \
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP \
		);"
	@echo "MariaDB table created"
#elseif( $dbType == "sqlite" )
	@echo "Creating SQLite table for items..."
	@sqlite3 /workspace/$(SQLITE_DATA_DIR)/$(SQLITE_DATABASE) \
		"CREATE TABLE IF NOT EXISTS items ( \
			id INTEGER PRIMARY KEY AUTOINCREMENT, \
			title TEXT NOT NULL, \
			description TEXT, \
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP, \
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP \
		);"
	@echo "SQLite table created"
#end