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
	@echo ""
	@echo "  dev-build     - Full development build (clean + compile + test)"
	@echo "  dev-deploy    - Clean deployment (clean + build + deploy)"
	@echo ""
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Access URL: http://localhost:9292/$(APP_NAME)"

.PHONY: build compile deploy undeploy redeploy status test test-verbose clean dev-build dev-deploy help
