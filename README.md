# Tomcat Development Environment

Containerized Tomcat 10.1 development environment for building Java web applications with database integration support.

## Quick Start

### Project Setup
```bash
./install.sh --postgres  # Setup with PostgreSQL
./install.sh --mariadb   # Setup with MariaDB  
./install.sh --sqlite    # Setup with SQLite
./install.sh             # Basic setup without database
```

### Build and Deploy Applications
```bash
make build app=helloworld    # Build specific application
make deploy app=helloworld   # Build and deploy to container
make help                    # Show available targets
```

### Access Applications
- Applications: `http://localhost:9292/<app_name>`
- Tomcat Manager: `http://localhost:9292/manager` (admin/admin123)

## Architecture

### Standard Servlet Applications
Single `pom.xml` projects with servlet annotations for URL mapping:
- Source: `src/main/java/` and `src/main/webapp/`
- Dependencies: Jakarta EE 6.0.0 Servlet API
- Deployment: WAR files to container webapps

### Microservice Architecture
Multi-module Maven projects with library/webapp separation:
- Library module: `microservice-lib/` (shared business logic)
- Webapp module: `microservice-webapp/` (servlet endpoints)
- Build order: JAR libraries first, then WAR webapps

## Database Integration

Optional database support via environment variables:

### PostgreSQL
```bash
POSTGRES_ENABLED=true
# Host port 15432 → Container port 5432
# Data: /var/lib/postgresql/tomcat-dev
```

### MariaDB
```bash
MARIADB_ENABLED=true  
# Host port 13306 → Container port 3306
# Data: /var/lib/mysql/tomcat-dev
```

### SQLite
```bash
SQLITE_ENABLED=true
# Data: project sqlite-data/ directory
```

## Container Configuration

### Ports
- Tomcat: 9292:8080
- PostgreSQL: 15432:5432 (if enabled)
- MariaDB: 13306:3306 (if enabled)

### Environment
- Java 17 runtime
- Heap size: 256m-1024m
- Timezone: Europe/Rome
- Webapps deploy to: `/usr/local/tomcat/webapps/`

## Development Standards

### Java Configuration
- Source/target: Java 17
- Encoding: UTF-8
- API: Jakarta EE 6.0.0 (not javax.servlet)
- WAR packaging with `failOnMissingWebXml=false`

### Response Patterns
JSON responses with standardized structure:
- Fields: message, timestamp, service, version, status
- CORS headers for development (wildcard origins)
- OPTIONS method handling for preflight requests
- JSON escaping via `escapeJson()` utility method

### Security
- Servlet API scope: 'provided' (container-provided)
- JSON injection prevention
- CORS configured for development (restrict in production)
- Database credentials via environment variables

## Application Commands

Each application directory includes standard Makefile targets:
- `make clean` - Clean build artifacts
- `make build` - Compile and package
- `make deploy` - Deploy to Tomcat
- `make test` - Run unit tests
- `make status` - Check deployment status