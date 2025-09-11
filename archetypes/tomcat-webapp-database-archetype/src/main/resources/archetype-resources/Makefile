# ${artifactId} Makefile

MAKEFLAGS += --no-print-directory

APP_NAME = ${artifactId}
CONTAINER_NAME = tomcat-dev
TOMCAT_WEBAPPS = /usr/local/tomcat/webapps

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
	@docker exec tomcat-dev-postgres psql -U devuser -d devdb -c \
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
	@docker exec tomcat-dev-mariadb mysql -u devuser -pdevpass123 devdb -e \
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
	@docker exec $(CONTAINER_NAME) sqlite3 /workspace/sqlite-data/devdb.sqlite \
		"CREATE TABLE IF NOT EXISTS items ( \
			id INTEGER PRIMARY KEY AUTOINCREMENT, \
			title TEXT NOT NULL, \
			description TEXT, \
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP, \
			updated_at DATETIME DEFAULT CURRENT_TIMESTAMP \
		);"
	@echo "SQLite table created"
#end