MAKEFLAGS += --no-print-directory

# ${artifactId} Webapp Build System
# Usage: make [target]

APP_NAME = ${artifactId}
CONTAINER_NAME = tomcat-dev
TOMCAT_WEBAPPS = /usr/local/tomcat/webapps

.DEFAULT_GOAL := help

# Build targets
build:
	@echo "Building $(APP_NAME) webapp..."
	@mvn package -q -DskipTests
	@echo "Build complete: target/$(APP_NAME).war"

compile:
	@echo "Compiling $(APP_NAME)..."
	@mvn compile -q

# Deployment
deploy: build
	@echo "Deploying $(APP_NAME) to $(CONTAINER_NAME)..."
	@rm -rf $(TOMCAT_WEBAPPS)/$(APP_NAME)*
	@cp target/$(APP_NAME).war $(TOMCAT_WEBAPPS)/
	@echo "Deployed: http://localhost:9292/$(APP_NAME)"
	@echo "Wait a few seconds for Tomcat to extract and deploy the WAR file"

undeploy:
	@echo "Undeploying $(APP_NAME) from $(CONTAINER_NAME)..."
	@rm -rf $(TOMCAT_WEBAPPS)/$(APP_NAME)*
	@echo "Undeployed successfully"

redeploy: undeploy deploy
	@echo "Redeployment complete"

status:
	@echo "Checking deployment status for $(APP_NAME):"
	@ls -la $(TOMCAT_WEBAPPS)/$(APP_NAME)* 2>/dev/null || echo "$(APP_NAME) is not deployed"

# Testing
test:
	@echo "Running unit tests for $(APP_NAME)..."
	@mvn test

test-verbose:
	@echo "Running unit tests with verbose output..."
	@mvn test -X

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@mvn clean -q

# Development targets
dev-build: clean compile test
	@echo "$(APP_NAME) development build completed"

dev-deploy: clean deploy
	@echo "$(APP_NAME) clean deployment completed"

# Database CLI - Connect to application database or execute SQL file
dbcli:
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found"; \
		exit 1; \
	fi
	@. ./.env && \
	if [ -n "$(load)" ]; then \
		if [ ! -f "$(load)" ]; then \
			echo "Error: SQL file not found: $(load)"; \
			exit 1; \
		fi; \
		if [ "$$DB_TYPE" = "postgres" ]; then \
			echo "Loading SQL file into PostgreSQL database: $$DB_NAME"; \
			PGPASSWORD=$$DB_PASSWORD psql -h $$DB_HOST -p $$DB_PORT -U $$DB_USER -d $$DB_NAME -f "$(load)"; \
		elif [ "$$DB_TYPE" = "mariadb" ]; then \
			echo "Loading SQL file into MariaDB database: $$DB_NAME"; \
			mysql -h $$DB_HOST -P $$DB_PORT -u $$DB_USER -p$$DB_PASSWORD $$DB_NAME < "$(load)"; \
		elif [ "$$DB_TYPE" = "sqlite" ]; then \
			echo "Loading SQL file into SQLite database: $$DB_PATH"; \
			sqlite3 $$DB_PATH < "$(load)"; \
		else \
			echo "Error: Unknown database type: $$DB_TYPE"; \
			exit 1; \
		fi; \
		echo "SQL file loaded successfully"; \
	else \
		if [ "$$DB_TYPE" = "postgres" ]; then \
			echo "Connecting to PostgreSQL database: $$DB_NAME"; \
			echo "Use \\q to quit"; \
			PGPASSWORD=$$DB_PASSWORD psql -h $$DB_HOST -p $$DB_PORT -U $$DB_USER -d $$DB_NAME; \
		elif [ "$$DB_TYPE" = "mariadb" ]; then \
			echo "Connecting to MariaDB database: $$DB_NAME"; \
			echo "Use 'exit' or 'quit' to quit"; \
			mysql -h $$DB_HOST -P $$DB_PORT -u $$DB_USER -p$$DB_PASSWORD $$DB_NAME; \
		elif [ "$$DB_TYPE" = "sqlite" ]; then \
			echo "Connecting to SQLite database: $$DB_PATH"; \
			echo "Use .quit to quit"; \
			sqlite3 $$DB_PATH; \
		else \
			echo "Error: Unknown database type: $$DB_TYPE"; \
			exit 1; \
		fi; \
	fi

# Display help
help:
	@echo "$(APP_NAME) Webapp - Available targets:"
	@echo ""
	@echo "  build         - Build WAR file"
	@echo "  compile       - Compile source code"
	@echo "  deploy        - Build and deploy to Tomcat"
	@echo "  undeploy      - Remove webapp from Tomcat"
	@echo "  redeploy      - Undeploy and deploy again"
	@echo "  status        - Check deployment status"
	@echo "  test          - Run unit tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  clean         - Clean build artifacts"
	@echo "  dbcli         - Connect to application database"
	@echo "  dbcli load=<file.sql> - Execute SQL file in database"
	@echo ""
	@echo "  dev-build     - Full development build (clean + compile + test)"
	@echo "  dev-deploy    - Clean deployment (clean + build + deploy)"
	@echo ""
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Access URL: http://localhost:9292/$(APP_NAME)"

.PHONY: build compile deploy undeploy redeploy status test test-verbose clean dev-build dev-deploy dbcli help
