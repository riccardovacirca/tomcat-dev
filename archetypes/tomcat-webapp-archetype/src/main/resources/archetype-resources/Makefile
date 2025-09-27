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

.PHONY: clean build deploy status help

help:
	@echo "Targets: clean, build, deploy, status"

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