# Step 8: Build and Deploy

## Create Makefile

File: `Makefile`

```makefile
APP_NAME = helloworld
CONTAINER_NAME = tomcat-dev
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
```

## Development workflow

```bash
# Clean previous build
make clean

# Build WAR file
make build

# Deploy to Tomcat
make deploy

# Check deployment status
make status
```

## Test your API

Visit: http://localhost:9292/helloworld/api/hello

## Build process

1. Maven compiles Java → `.class` files
2. Maven packages → `.war` file
3. Copy WAR to Tomcat webapps
4. Tomcat auto-deploys and starts app