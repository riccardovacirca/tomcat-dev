#!/bin/sh

set -e

# Command line options
INSTALL_POSTGRES=false
INSTALL_MARIADB=false
INSTALL_SQLITE=false
INSTALL_CLAUDE=false
CREATE_WEBAPP=""
CREATE_LIBRARY=""
REMOVE_WEBAPP=""
REMOVE_LIBRARY=""
DATABASE_TYPE=""

print_info() {
  printf "[INFO] %s\n" "$1"
}

print_warn() {
  printf "[WARN] %s\n" "$1"
}

print_error() {
  printf "[ERROR] %s\n" "$1"
}

print_header() {
  printf "[TOMCAT-DEV] %s\n" "$1"
}

# Check if an archetype is installed in the local Maven repository
check_archetype_installed() {
  local groupId="$1"
  local artifactId="$2"
  local version="$3"

  # Convert groupId to path format (com.example.archetypes -> com/example/archetypes)
  local groupPath=$(echo "$groupId" | sed 's/\./\//g')
  local archetypePath="$HOME/.m2/repository/$groupPath/$artifactId/$version"

  [ -d "$archetypePath" ]
}

# Install all required archetypes if not already present
ensure_archetypes_installed() {
  local archetypes_needed=false
  local archetypes_dir="archetypes"

  # List of required archetypes
  local archetype_list="tomcat-webapp-archetype tomcat-webapp-database-archetype tomcat-jar-library tomcat-jar-database-archetype"

  # Check which archetypes need to be installed
  for archetype in $archetype_list; do
    if ! check_archetype_installed "com.example.archetypes" "$archetype" "1.0.0"; then
      archetypes_needed=true
      break
    fi
  done

  if [ "$archetypes_needed" = true ]; then
    print_info "Installing Maven archetypes to local repository..."

    # Ensure we're in the correct directory
    if [ ! -d "$archetypes_dir" ]; then
      print_error "Archetypes directory not found: $archetypes_dir"
      exit 1
    fi

    # Install each archetype
    for archetype in $archetype_list; do
      if [ -d "$archetypes_dir/$archetype" ]; then
        if ! check_archetype_installed "com.example.archetypes" "$archetype" "1.0.0"; then
          print_info "Installing archetype: $archetype"
          cd "$archetypes_dir/$archetype" || exit 1
          mvn clean install -q || {
            print_error "Failed to install archetype: $archetype"
            exit 1
          }
          cd - > /dev/null || exit 1
        else
          print_info "Archetype already installed: $archetype"
        fi
      else
        print_warn "Archetype directory not found: $archetypes_dir/$archetype"
      fi
    done

    print_info "All required archetypes are now installed"
  else
    print_info "All Maven archetypes are already installed"
  fi
}

create_env_file() {
  print_info "Creating .env configuration"
  cat > ".env" << EOF
# Container Configuration
CONTAINER_NAME=tomcat-dev
TOMCAT_VERSION=10.1-jdk17

# Network Configuration
NETWORK_NAME=tomcat-dev-net
HOST_PORT=9292
MANAGER_PORT=9292
TOMCAT_INTERNAL_PORT=8080

# Java Application Settings
JAVA_VERSION=17
HEAP_SIZE_MIN=256m
HEAP_SIZE_MAX=1024m
TIMEZONE=Europe/Rome

# Git Configuration (optional)
# GIT_USER=Your Name
# GIT_MAIL=your.email@example.com

# Tomcat Manager Configuration
ADMIN_USER=admin
ADMIN_PASSWORD=admin123
MANAGER_USER=manager
MANAGER_PASSWORD=manager123

# Logging Configuration
LOG_DIR=logs
LOG_FILE=tomcat-dev.log
LOG_ROTATION=daily

# PostgreSQL Configuration (optional)
POSTGRES_ENABLED=false
POSTGRES_CONTAINER_NAME=tomcat-dev-postgres
POSTGRES_VERSION=latest
POSTGRES_PORT=15432
POSTGRES_DB=devdb
POSTGRES_USER=devuser
POSTGRES_PASSWORD=devpass123
POSTGRES_ROOT_PASSWORD=rootpass123
POSTGRES_DATA_DIR=postgres-data

# MariaDB Configuration (optional)
MARIADB_ENABLED=false
MARIADB_CONTAINER_NAME=tomcat-dev-mariadb
MARIADB_VERSION=latest
MARIADB_PORT=13306
MARIADB_DATABASE=devdb
MARIADB_USER=devuser
MARIADB_PASSWORD=devpass123
MARIADB_ROOT_PASSWORD=rootpass123
MARIADB_DATA_DIR=mariadb-data

# SQLite Configuration (optional)
SQLITE_ENABLED=false
SQLITE_DATABASE=devdb.sqlite
SQLITE_DATA_DIR=sqlite-data
EOF
  print_info ".env file created successfully"
}

check_docker() {
  if ! command -v docker > /dev/null 2>&1; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
  fi
  if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker service."
    exit 1
  fi
  print_info "Docker is available and running"
}

create_basic_directories() {
  print_info "Creating basic project directories..."
  mkdir -p webapps conf logs work temp uploads
  print_info "Project directories created"
}

# Create .gitignore file
create_gitignore() {
  if [ ! -f ".gitignore" ]; then
    print_info "Creating .gitignore file..."
    cat > ".gitignore" << 'EOF'
*
!archetypes/
!archetypes/**
!docs/
!docs/**
!examples/
!examples/**
!install.sh
!Makefile
!README.md
!LICENSE

**/target/
target/
*.war
*.class
EOF
    print_info ".gitignore file created"
  else
    print_info ".gitignore already exists, skipping creation"
  fi
}

# Create projects folder
create_projects_folder() {
  if [ ! -d "projects" ]; then
    print_info "Creating projects folder..."
    mkdir -p projects
    print_info "projects folder file created"
  else
    print_info "projects folder already exists, skipping creation"
  fi
}

# Create Docker network if it doesn't exist
create_docker_network() {
  NETWORK_NAME=$(grep NETWORK_NAME .env | cut -d= -f2)
  
  # Check if network already exists (idempotency)
  if docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
    print_info "Docker network $NETWORK_NAME already exists, skipping creation"
    return 0
  fi
  
  print_info "Creating Docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
  print_info "Docker network created successfully"
}

pull_tomcat_image() {
  TOMCAT_VERSION=$(grep TOMCAT_VERSION .env | cut -d= -f2)
  # Check if image already exists (idempotency)
  if docker image inspect "tomcat:$TOMCAT_VERSION" > /dev/null 2>&1; then
    print_info "Tomcat $TOMCAT_VERSION image already exists, skipping pull"
    return 0
  fi
  print_info "Pulling Tomcat $TOMCAT_VERSION image..."
  docker pull "tomcat:$TOMCAT_VERSION"
  print_info "Tomcat image pulled successfully"
}

create_tomcat_config() {
  print_info "Creating Tomcat configuration..."
  # Get credentials from .env
  ADMIN_USER=$(grep ADMIN_USER .env | cut -d= -f2)
  ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d= -f2)
  MANAGER_USER=$(grep MANAGER_USER .env | cut -d= -f2)
  MANAGER_PASSWORD=$(grep MANAGER_PASSWORD .env | cut -d= -f2)
  # Create tomcat-users.xml for manager access
  if [ ! -f "conf/tomcat-users.xml" ]; then
    cat > "conf/tomcat-users.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  
  <!-- Define roles -->
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  
  <!-- Define users -->
  <user username="$ADMIN_USER" password="$ADMIN_PASSWORD" roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>
  <user username="$MANAGER_USER" password="$MANAGER_PASSWORD" roles="manager-gui,manager-script,manager-status"/>
</tomcat-users>
EOF
  fi
  # Create manager context to allow access from any IP
  mkdir -p "conf/Catalina/localhost"
  if [ ! -f "conf/Catalina/localhost/manager.xml" ]; then
    cat > "conf/Catalina/localhost/manager.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="^.*$" />
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF
  fi
  print_info "Tomcat configuration created"
}

# Copy default Tomcat configuration
copy_default_config() {
  print_info "Copying default Tomcat configuration..."
  TOMCAT_VERSION=$(grep TOMCAT_VERSION .env | cut -d= -f2)
  # Create temporary container to copy default configs
  temp_container_id=$(docker create "tomcat:$TOMCAT_VERSION")
  # Copy default server.xml if it doesn't exist
  if [ ! -f "conf/server.xml" ]; then
    docker cp "$temp_container_id:/usr/local/tomcat/conf/server.xml" "conf/"
  fi
  # Copy other essential config files
  if [ ! -f "conf/web.xml" ]; then
      docker cp "$temp_container_id:/usr/local/tomcat/conf/web.xml" "conf/"
  fi
  if [ ! -f "conf/logging.properties" ]; then
    docker cp "$temp_container_id:/usr/local/tomcat/conf/logging.properties" "conf/"
  fi
  if [ ! -f "conf/catalina.properties" ]; then
    docker cp "$temp_container_id:/usr/local/tomcat/conf/catalina.properties" "conf/"
  fi
  # Copy default webapps (manager, docs, examples, etc.)
  if [ ! -d "webapps/manager" ]; then
    print_info "Copying default Tomcat webapps..."
    docker cp "$temp_container_id:/usr/local/tomcat/webapps.dist/." "webapps/"
  fi
  # Remove temporary container
  docker rm "$temp_container_id" > /dev/null
  print_info "Default Tomcat configuration copied"
}

start_container() {
  CONTAINER_NAME=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)
  HOST_PORT=$(grep HOST_PORT .env | cut -d= -f2)
  TOMCAT_VERSION=$(grep TOMCAT_VERSION .env | cut -d= -f2)
  HEAP_SIZE_MIN=$(grep HEAP_SIZE_MIN .env | cut -d= -f2)
  HEAP_SIZE_MAX=$(grep HEAP_SIZE_MAX .env | cut -d= -f2)
  PROJECT_DIR=$(pwd)
  
  # Check if container is already running (idempotency)
  if docker ps --format 'table {{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_info "Container ${CONTAINER_NAME} is already running, skipping container creation"
  else
    # Stop and remove existing stopped container
    if docker ps -a --format 'table {{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      print_warn "Stopping and removing existing container: ${CONTAINER_NAME}"
      docker stop "${CONTAINER_NAME}" > /dev/null 2>&1 || true
      docker rm "${CONTAINER_NAME}" > /dev/null 2>&1 || true
    fi
    
    print_info "Starting Tomcat container..."
    NETWORK_NAME=$(grep NETWORK_NAME .env | cut -d= -f2)
    
    docker run -d \
      --name "${CONTAINER_NAME}" \
      --network "${NETWORK_NAME}" \
      -p "${HOST_PORT}:8080" \
      -v "${PROJECT_DIR}:/workspace" \
      -w "/workspace" \
      -v "${PROJECT_DIR}/webapps:/usr/local/tomcat/webapps" \
      -v "${PROJECT_DIR}/conf:/usr/local/tomcat/conf" \
      -v "${PROJECT_DIR}/logs:/usr/local/tomcat/logs" \
      -v "${PROJECT_DIR}/work:/usr/local/tomcat/work" \
      -v "${PROJECT_DIR}/temp:/usr/local/tomcat/temp" \
      -e CATALINA_OPTS="-Xmx${HEAP_SIZE_MAX} -Xms${HEAP_SIZE_MIN}" \
      -e JAVA_HOME="/opt/java/openjdk" \
      "tomcat:${TOMCAT_VERSION}"
    
    print_info "Tomcat container started successfully"
  fi
}

wait_for_tomcat() {
  HOST_PORT=$(grep HOST_PORT .env | cut -d= -f2)
  print_info "Waiting for Tomcat to be ready..."
  max_attempts=30
  attempt=0
  while [ $attempt -lt $max_attempts ]; do
    if curl -f -s "http://localhost:${HOST_PORT}" > /dev/null 2>&1; then
      print_info "Tomcat is ready!"
      break
    fi
    attempt=$((attempt + 1))
    printf "."
    sleep 2
  done
  if [ $attempt -eq $max_attempts ]; then
    print_warn "Tomcat may not be fully ready yet. Check logs with: docker logs $(grep "^CONTAINER_NAME=" .env | cut -d= -f2)"
  fi
  echo ""
}

install_dev_tools() {
  CONTAINER_NAME=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)
  print_info "Installing development tools in container..."
  # Check if tools are already installed (idempotency)
  if docker exec "${CONTAINER_NAME}" which mvn > /dev/null 2>&1 && \
    docker exec "${CONTAINER_NAME}" which make > /dev/null 2>&1 && \
    docker exec "${CONTAINER_NAME}" which git > /dev/null 2>&1 && \
    docker exec "${CONTAINER_NAME}" which psql > /dev/null 2>&1; then
    print_info "Development tools already installed, skipping installation"
  else
    print_info "Installing missing development tools..."
    # Update package list
    docker exec "${CONTAINER_NAME}" apt-get update -qq > /dev/null 2>&1
    # Install development tools
    if docker exec "${CONTAINER_NAME}" apt-get install -y --no-install-recommends \
      make \
      openjdk-17-jdk-headless \
      git \
      maven \
      wget \
      curl \
      postgresql-client > /dev/null 2>&1; then
      print_info "Development tools packages installed"
    else
      print_warn "Some development tools packages may have failed to install"
    fi
    # Clean up
    docker exec "${CONTAINER_NAME}" apt-get clean > /dev/null 2>&1
    docker exec "${CONTAINER_NAME}" rm -rf /var/lib/apt/lists/* > /dev/null 2>&1
  fi
  # Verify installation
  if docker exec "${CONTAINER_NAME}" which mvn > /dev/null 2>&1; then
    MAVEN_VERSION=$(docker exec "${CONTAINER_NAME}" mvn -version 2>/dev/null | head -1 | cut -d' ' -f3)
    print_info "Development tools installed successfully (make, javac, jar, git, maven $MAVEN_VERSION)"
  else
    print_warn "Maven installation may have failed"
    print_info "Development tools installed (make, javac, jar, git)"
  fi
}

configure_git() {
  CONTAINER_NAME=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)
  # Check if git configuration is available
  if grep -q "^GIT_USER=" .env && grep -q "^GIT_MAIL=" .env; then
    GIT_USER=$(grep GIT_USER .env | cut -d= -f2)
    GIT_MAIL=$(grep GIT_MAIL .env | cut -d= -f2)
    if [ -n "$GIT_USER" ] && [ -n "$GIT_MAIL" ]; then
      print_info "Configuring git in container..."
      docker exec "${CONTAINER_NAME}" git config --global user.name "$GIT_USER"
      docker exec "${CONTAINER_NAME}" git config --global user.email "$GIT_MAIL"
      docker exec "${CONTAINER_NAME}" git config --global --add safe.directory /workspace
      print_info "Git configured with user: $GIT_USER <$GIT_MAIL>"
    fi
  else
    print_info "Git configuration not found in .env (optional: set GIT_USER and GIT_MAIL)"
  fi
}

configure_shell_aliases() {
  CONTAINER_NAME=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)
  
  print_info "Configuring shell aliases in container..."
  
  # Check if cls alias already exists in .bashrc
  if docker exec "${CONTAINER_NAME}" grep -q "alias cls=" /root/.bashrc 2>/dev/null; then
    print_info "Shell aliases already configured, skipping"
    return 0
  fi
  
  # Add cls alias to .bashrc
  docker exec "${CONTAINER_NAME}" sh -c "echo '' >> /root/.bashrc"
  docker exec "${CONTAINER_NAME}" sh -c "echo '# Custom aliases' >> /root/.bashrc"
  docker exec "${CONTAINER_NAME}" sh -c "echo 'alias cls=clear' >> /root/.bashrc"
  
  # Also add to current shell environment for immediate use
  docker exec "${CONTAINER_NAME}" sh -c "alias cls=clear"
  
  print_info "Shell aliases configured successfully (cls -> clear)"
}

# Pull PostgreSQL image
pull_postgres_image() {
  POSTGRES_VERSION=$(grep POSTGRES_VERSION .env | cut -d= -f2)
  
  # Check if image already exists (idempotency)
  if docker image inspect "postgres:$POSTGRES_VERSION" > /dev/null 2>&1; then
    print_info "PostgreSQL $POSTGRES_VERSION image already exists, skipping pull"
    return 0
  fi
  
  print_info "Pulling PostgreSQL $POSTGRES_VERSION image..."
  docker pull "postgres:$POSTGRES_VERSION"
  print_info "PostgreSQL image pulled successfully"
}

# Create PostgreSQL data volume
create_postgres_volume() {
  POSTGRES_CONTAINER_NAME=$(grep POSTGRES_CONTAINER_NAME .env | cut -d= -f2)
  VOLUME_NAME="${POSTGRES_CONTAINER_NAME}-data"

  # Check if volume already exists (idempotency)
  if docker volume inspect "$VOLUME_NAME" > /dev/null 2>&1; then
    print_info "PostgreSQL volume $VOLUME_NAME already exists, skipping creation"
    return 0
  fi

  print_info "Creating PostgreSQL data volume..."
  docker volume create "$VOLUME_NAME"
  print_info "PostgreSQL volume created: $VOLUME_NAME"
}

# Start PostgreSQL container
start_postgres_container() {
  POSTGRES_CONTAINER_NAME=$(grep POSTGRES_CONTAINER_NAME .env | cut -d= -f2)
  POSTGRES_VERSION=$(grep POSTGRES_VERSION .env | cut -d= -f2)
  POSTGRES_PORT=$(grep POSTGRES_PORT .env | cut -d= -f2)
  POSTGRES_DB=$(grep POSTGRES_DB .env | cut -d= -f2)
  POSTGRES_USER=$(grep POSTGRES_USER .env | cut -d= -f2)
  POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d= -f2)
  POSTGRES_ROOT_PASSWORD=$(grep POSTGRES_ROOT_PASSWORD .env | cut -d= -f2)
  POSTGRES_DATA_DIR=$(grep POSTGRES_DATA_DIR .env | cut -d= -f2)
  NETWORK_NAME=$(grep NETWORK_NAME .env | cut -d= -f2)
  
  # Check if container is already running (idempotency)
  if docker ps --format 'table {{.Names}}' | grep -q "^${POSTGRES_CONTAINER_NAME}$"; then
    print_info "Container ${POSTGRES_CONTAINER_NAME} is already running, skipping container creation"
    return 0
  fi
  
  # Stop and remove existing stopped container
  if docker ps -a --format 'table {{.Names}}' | grep -q "^${POSTGRES_CONTAINER_NAME}$"; then
    print_warn "Stopping and removing existing container: ${POSTGRES_CONTAINER_NAME}"
    docker stop "${POSTGRES_CONTAINER_NAME}" > /dev/null 2>&1 || true
    docker rm "${POSTGRES_CONTAINER_NAME}" > /dev/null 2>&1 || true
  fi
  
  print_info "Starting PostgreSQL container..."
  
  VOLUME_NAME="${POSTGRES_CONTAINER_NAME}-data"

  docker run -d \
    --name "${POSTGRES_CONTAINER_NAME}" \
    --network "${NETWORK_NAME}" \
    -p "${POSTGRES_PORT}:5432" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
    "postgres:${POSTGRES_VERSION}"
  
  print_info "PostgreSQL container started successfully"
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
  POSTGRES_CONTAINER_NAME=$(grep POSTGRES_CONTAINER_NAME .env | cut -d= -f2)
  POSTGRES_USER=$(grep POSTGRES_USER .env | cut -d= -f2)
  POSTGRES_DB=$(grep POSTGRES_DB .env | cut -d= -f2)
  
  print_info "Waiting for PostgreSQL to be ready..."
  max_attempts=30
  attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if docker exec "${POSTGRES_CONTAINER_NAME}" pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" > /dev/null 2>&1; then
      print_info "PostgreSQL is ready!"
      break
    fi
    attempt=$((attempt + 1))
    printf "."
    sleep 2
  done
  
  if [ $attempt -eq $max_attempts ]; then
    print_warn "PostgreSQL may not be fully ready yet. Check logs with: docker logs ${POSTGRES_CONTAINER_NAME}"
  fi
  echo ""
}

# Setup PostgreSQL environment
setup_postgres() {
  print_header "PostgreSQL Database Setup"
  echo ""

  pull_postgres_image
  create_postgres_volume
  start_postgres_container
  wait_for_postgres
  
  POSTGRES_PORT=$(grep POSTGRES_PORT .env | cut -d= -f2)
  POSTGRES_DB=$(grep POSTGRES_DB .env | cut -d= -f2)
  POSTGRES_USER=$(grep POSTGRES_USER .env | cut -d= -f2)
  POSTGRES_CONTAINER_NAME=$(grep POSTGRES_CONTAINER_NAME .env | cut -d= -f2)
  
  echo ""
  print_info "=== PostgreSQL Setup Complete ==="
  print_info "Database: ${POSTGRES_DB}"
  print_info "User: ${POSTGRES_USER}"
  print_info "Connection: localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
  print_info "JDBC URL: jdbc:postgresql://localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
  print_info "Network: ${POSTGRES_CONTAINER_NAME} (accessible from Tomcat container)"
  echo ""
}

# Pull MariaDB image
pull_mariadb_image() {
  MARIADB_VERSION=$(grep MARIADB_VERSION .env | cut -d= -f2)
  
  # Check if image already exists (idempotency)
  if docker image inspect "mariadb:$MARIADB_VERSION" > /dev/null 2>&1; then
    print_info "MariaDB $MARIADB_VERSION image already exists, skipping pull"
    return 0
  fi
  
  print_info "Pulling MariaDB $MARIADB_VERSION image..."
  docker pull "mariadb:$MARIADB_VERSION"
  print_info "MariaDB image pulled successfully"
}

# Create MariaDB data directory
create_mariadb_directories() {
  MARIADB_DATA_DIR=$(grep MARIADB_DATA_DIR .env | cut -d= -f2)
  print_info "Creating MariaDB data directory..."
  # Create directory with Docker to avoid sudo issues
  docker run --rm -v "$MARIADB_DATA_DIR":/data alpine mkdir -p /data 2>/dev/null || mkdir -p "$MARIADB_DATA_DIR" 2>/dev/null || true
  print_info "MariaDB directories created: $MARIADB_DATA_DIR"
}

# Start MariaDB container
start_mariadb_container() {
  MARIADB_CONTAINER_NAME=$(grep MARIADB_CONTAINER_NAME .env | cut -d= -f2)
  MARIADB_VERSION=$(grep MARIADB_VERSION .env | cut -d= -f2)
  MARIADB_PORT=$(grep MARIADB_PORT .env | cut -d= -f2)
  MARIADB_DATABASE=$(grep MARIADB_DATABASE .env | cut -d= -f2)
  MARIADB_USER=$(grep MARIADB_USER .env | cut -d= -f2)
  MARIADB_PASSWORD=$(grep MARIADB_PASSWORD .env | cut -d= -f2)
  MARIADB_ROOT_PASSWORD=$(grep MARIADB_ROOT_PASSWORD .env | cut -d= -f2)
  MARIADB_DATA_DIR=$(grep MARIADB_DATA_DIR .env | cut -d= -f2)
  NETWORK_NAME=$(grep NETWORK_NAME .env | cut -d= -f2)
  
  # Check if container is already running (idempotency)
  if docker ps --format 'table {{.Names}}' | grep -q "^${MARIADB_CONTAINER_NAME}$"; then
    print_info "Container ${MARIADB_CONTAINER_NAME} is already running, skipping container creation"
    return 0
  fi
  
  # Stop and remove existing stopped container
  if docker ps -a --format 'table {{.Names}}' | grep -q "^${MARIADB_CONTAINER_NAME}$"; then
    print_warn "Stopping and removing existing container: ${MARIADB_CONTAINER_NAME}"
    docker stop "${MARIADB_CONTAINER_NAME}" > /dev/null 2>&1 || true
    docker rm "${MARIADB_CONTAINER_NAME}" > /dev/null 2>&1 || true
  fi
  
  print_info "Starting MariaDB container..."
  
  docker run -d \
    --name "${MARIADB_CONTAINER_NAME}" \
    --network "${NETWORK_NAME}" \
    -p "${MARIADB_PORT}:3306" \
    -e MARIADB_DATABASE="${MARIADB_DATABASE}" \
    -e MARIADB_USER="${MARIADB_USER}" \
    -e MARIADB_PASSWORD="${MARIADB_PASSWORD}" \
    -e MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD}" \
    -v "${MARIADB_DATA_DIR}:/var/lib/mysql" \
    "mariadb:${MARIADB_VERSION}"
  
  print_info "MariaDB container started successfully"
}

# Wait for MariaDB to be ready
wait_for_mariadb() {
  MARIADB_CONTAINER_NAME=$(grep MARIADB_CONTAINER_NAME .env | cut -d= -f2)
  MARIADB_USER=$(grep MARIADB_USER .env | cut -d= -f2)
  MARIADB_DATABASE=$(grep MARIADB_DATABASE .env | cut -d= -f2)
  
  print_info "Waiting for MariaDB to be ready..."
  max_attempts=30
  attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if docker exec "${MARIADB_CONTAINER_NAME}" mysqladmin ping -h localhost > /dev/null 2>&1; then
      print_info "MariaDB is ready!"
      break
    fi
    attempt=$((attempt + 1))
    printf "."
    sleep 2
  done
  
  if [ $attempt -eq $max_attempts ]; then
    print_warn "MariaDB may not be fully ready yet. Check logs with: docker logs ${MARIADB_CONTAINER_NAME}"
  fi
  echo ""
}

# Setup MariaDB environment
setup_mariadb() {
  print_header "MariaDB Database Setup"
  echo ""
  
  pull_mariadb_image
  create_mariadb_directories
  start_mariadb_container
  wait_for_mariadb
  
  MARIADB_PORT=$(grep MARIADB_PORT .env | cut -d= -f2)
  MARIADB_DATABASE=$(grep MARIADB_DATABASE .env | cut -d= -f2)
  MARIADB_USER=$(grep MARIADB_USER .env | cut -d= -f2)
  MARIADB_CONTAINER_NAME=$(grep MARIADB_CONTAINER_NAME .env | cut -d= -f2)
  
  echo ""
  print_info "=== MariaDB Setup Complete ==="
  print_info "Database: ${MARIADB_DATABASE}"
  print_info "User: ${MARIADB_USER}"
  print_info "Connection: localhost:${MARIADB_PORT}/${MARIADB_DATABASE}"
  print_info "JDBC URL: jdbc:mariadb://localhost:${MARIADB_PORT}/${MARIADB_DATABASE}"
  print_info "Network: ${MARIADB_CONTAINER_NAME} (accessible from Tomcat container)"
  echo ""
}

# Create SQLite data directory
create_sqlite_directories() {
  SQLITE_DATA_DIR=$(grep SQLITE_DATA_DIR .env | cut -d= -f2)
  print_info "Creating SQLite data directory..."
  mkdir -p "$SQLITE_DATA_DIR"
  print_info "SQLite directories created"
}

# Install SQLite3 in Tomcat container
install_sqlite_in_container() {
  CONTAINER_NAME=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)
  
  # Check if SQLite3 is already installed
  if docker exec "${CONTAINER_NAME}" which sqlite3 > /dev/null 2>&1; then
    print_info "SQLite3 already installed in container"
    return 0
  fi
  
  print_info "Installing SQLite3 in Tomcat container..."
  docker exec "${CONTAINER_NAME}" apt-get update -qq > /dev/null 2>&1
  
  if docker exec "${CONTAINER_NAME}" apt-get install -y --no-install-recommends sqlite3 > /dev/null 2>&1; then
    print_info "SQLite3 installed successfully"
  else
    print_warn "SQLite3 installation may have failed"
  fi
  
  # Clean up
  docker exec "${CONTAINER_NAME}" apt-get clean > /dev/null 2>&1
  docker exec "${CONTAINER_NAME}" rm -rf /var/lib/apt/lists/* > /dev/null 2>&1
}

# Setup SQLite environment
setup_sqlite() {
  print_header "SQLite Database Setup"
  echo ""
  
  create_sqlite_directories
  install_sqlite_in_container
  
  SQLITE_DATABASE=$(grep SQLITE_DATABASE .env | cut -d= -f2)
  SQLITE_DATA_DIR=$(grep SQLITE_DATA_DIR .env | cut -d= -f2)
  CONTAINER_NAME=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)
  
  # Create SQLite database file
  print_info "Creating SQLite database..."
  touch "${SQLITE_DATA_DIR}/${SQLITE_DATABASE}"
  
  # Initialize database with a simple test table
  SQLITE_PATH="/workspace/${SQLITE_DATA_DIR}/${SQLITE_DATABASE}"
  docker exec "${CONTAINER_NAME}" sqlite3 "$SQLITE_PATH" "CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY, name TEXT);"
  
  echo ""
  print_info "=== SQLite Setup Complete ==="
  print_info "Database: ${SQLITE_DATABASE}"
  print_info "Location: ${SQLITE_DATA_DIR}/${SQLITE_DATABASE}"
  print_info "JDBC URL: jdbc:sqlite:/workspace/${SQLITE_DATA_DIR}/${SQLITE_DATABASE}"
  print_info "Access from container: sqlite3 /workspace/${SQLITE_DATA_DIR}/${SQLITE_DATABASE}"
  echo ""
}

# Install Claude Code in Tomcat container
install_claude_code() {
  print_info "Starting Claude Code installation..."
  CONTAINER_NAME=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)

  # Check if development container is running
  if ! docker ps --format 'table {{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_error "Development container '$CONTAINER_NAME' is not running"
    print_error "Cannot install Claude Code without development container"
    exit 1
  fi

  # Check if Claude Code is already installed
  if docker exec "$CONTAINER_NAME" bash -c "command -v claude >/dev/null 2>&1"; then
    print_info "Claude Code already installed"
    return 0
  fi

  # Execute installation inside container
  if ! docker exec -i "$CONTAINER_NAME" bash -c "
    export DEBIAN_FRONTEND=noninteractive && \

    # Install curl if needed
    if ! command -v curl >/dev/null 2>&1; then
      if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y curl
      elif command -v yum >/dev/null 2>&1; then yum install -y curl
      elif command -v apk >/dev/null 2>&1; then apk add --no-cache curl
      else echo 'ERROR: Install curl manually' && exit 1; fi
    fi && \

    # Install NVM if not present
    export NVM_DIR=\"\$HOME/.nvm\" && \
    if [ ! -s \"\$NVM_DIR/nvm.sh\" ]; then
      echo 'INFO: Installing NVM...' && \
      curl -o- 'https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh' | bash || { echo 'ERROR: NVM install failed'; exit 1; }
    fi && \

    # Source NVM for this session
    export NVM_DIR=\"\$HOME/.nvm\" && \
    [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && \
    [ -s \"\$NVM_DIR/bash_completion\" ] && . \"\$NVM_DIR/bash_completion\" && \

    # Add NVM to shell profiles
    for profile in ~/.bashrc ~/.bash_profile ~/.zshrc ~/.profile; do
      if [ -f \"\$profile\" ] && ! grep -q 'NVM_DIR' \"\$profile\"; then
        echo '' >> \"\$profile\" && \
        echo '# NVM Configuration' >> \"\$profile\" && \
        echo 'export NVM_DIR=\"\$HOME/.nvm\"' >> \"\$profile\" && \
        echo '[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"' >> \"\$profile\" && \
        echo '[ -s \"\$NVM_DIR/bash_completion\" ] && . \"\$NVM_DIR/bash_completion\"' >> \"\$profile\"
      fi
    done && \

    # Install Node.js 18
    echo 'INFO: Installing Node.js 18...' && \
    nvm install 18 && nvm use 18 && nvm alias default 18 && \

    # Verify Node installation
    command -v node >/dev/null 2>&1 || { echo 'ERROR: Node.js installation verification failed'; exit 1; } && \

    # Install Claude Code
    echo 'INFO: Installing Claude Code...' && \
    npm install -g @anthropic-ai/claude-code && \

    # Verify Claude Code installation
    command -v claude >/dev/null 2>&1 || { echo 'ERROR: Claude Code installation verification failed'; exit 1; }
  "; then
    print_error "Claude Code installation failed"
    exit 1
  fi

  # Create CLAUDE.md file in project root
  if [ ! -f "CLAUDE.md" ]; then
    cat > "CLAUDE.md" << 'EOF'
# Tomcat Development Environment

This is a Tomcat-based Java web development environment with Docker support.

## Project Structure
- `webapps/` - Tomcat web applications
- `projects/` - Maven projects and libraries
- `conf/` - Tomcat configuration
- `logs/` - Tomcat logs

## Available Tools
- Tomcat 10.1 with JDK 17
- Maven for project management
- PostgreSQL/MariaDB/SQLite support
- Development tools (make, git, etc.)

## Usage
- Access Tomcat Manager: http://localhost:9292/manager/html
- Create projects: `make app name=myapp`
- Build projects: `cd projects/myapp && mvn package`
EOF
    print_info "CLAUDE.md created in project root"
  fi

  print_info "Claude Code installation completed successfully!"
  print_info "Run 'source ~/.bashrc' or start a new shell session inside container to use 'claude'"
}

# Create database and user for webapp
create_webapp_database() {
  local app_name="$1"
  local db_type="$2"

  print_info "Creating database and user for webapp '$app_name'..."

  case "$db_type" in
    postgres)
      create_postgres_webapp_database "$app_name"
      ;;
    mariadb)
      create_mariadb_webapp_database "$app_name"
      ;;
    sqlite)
      create_sqlite_webapp_database "$app_name"
      ;;
    *)
      print_warn "Database creation not implemented for type: $db_type"
      ;;
  esac
}

# Create PostgreSQL database and user for webapp
create_postgres_webapp_database() {
  local app_name="$1"
  local container_name=$(grep POSTGRES_CONTAINER_NAME .env | cut -d= -f2)
  local admin_user=$(grep POSTGRES_USER .env | cut -d= -f2)
  local admin_password=$(grep POSTGRES_PASSWORD .env | cut -d= -f2)

  print_info "Creating PostgreSQL database '$app_name' with user '$app_name'..."

  # Connect to PostgreSQL via network using admin credentials
  export PGPASSWORD="$admin_password"

  # Create user and database using network connection
  # Check if user exists first
  if psql -h "$container_name" -p 5432 -U "$admin_user" -d postgres -t -c "SELECT 1 FROM pg_roles WHERE rolname='${app_name}';" | grep -q 1; then
    print_error "User '${app_name}' already exists in PostgreSQL. Please choose a different webapp name or manually drop the user first."
    return 1
  fi

  # Create user
  psql -h "$container_name" -p 5432 -U "$admin_user" -d postgres -c "CREATE USER ${app_name} WITH PASSWORD 'secret';" || {
    print_error "Failed to create user '${app_name}'"
    return 1
  }

  # Create database
  psql -h "$container_name" -p 5432 -U "$admin_user" -d postgres -c "CREATE DATABASE ${app_name} OWNER ${app_name};" || {
    print_error "Failed to create database '${app_name}'"
    return 1
  }

  # Grant privileges
  psql -h "$container_name" -p 5432 -U "$admin_user" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${app_name} TO ${app_name};" || {
    print_error "Failed to grant privileges to user '${app_name}'"
    return 1
  }

  # Unset password variable for security
  unset PGPASSWORD

  print_info "PostgreSQL setup complete for webapp '$app_name'"
  print_info "Database: $app_name | User: $app_name | Password: secret"
}

# Create MariaDB database and user for webapp
create_mariadb_webapp_database() {
  local app_name="$1"
  local container_name=$(grep MARIADB_CONTAINER_NAME .env | cut -d= -f2)
  local root_password=$(grep MARIADB_ROOT_PASSWORD .env | cut -d= -f2)

  print_info "Creating MariaDB database '$app_name' with user '$app_name'..."

  # Check if container is running
  if ! docker ps --format 'table {{.Names}}' | grep -q "^${container_name}$"; then
    print_error "MariaDB container '${container_name}' is not running. Start it with: ./install.sh --mariadb"
    return 1
  fi

  # Create user and database
  docker exec "${container_name}" mysql -u root -p"${root_password}" -e "CREATE DATABASE IF NOT EXISTS ${app_name};" 2>/dev/null
  docker exec "${container_name}" mysql -u root -p"${root_password}" -e "CREATE USER IF NOT EXISTS '${app_name}'@'%' IDENTIFIED BY 'secret';" 2>/dev/null
  docker exec "${container_name}" mysql -u root -p"${root_password}" -e "GRANT ALL PRIVILEGES ON ${app_name}.* TO '${app_name}'@'%';" 2>/dev/null
  docker exec "${container_name}" mysql -u root -p"${root_password}" -e "FLUSH PRIVILEGES;" 2>/dev/null

  print_info "MariaDB setup complete for webapp '$app_name'"
  print_info "Database: $app_name | User: $app_name | Password: secret"
}

# Create SQLite database for webapp
create_sqlite_webapp_database() {
  local app_name="$1"
  local sqlite_data_dir=$(grep SQLITE_DATA_DIR .env | cut -d= -f2)
  local container_name=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)

  print_info "Creating SQLite database for webapp '$app_name'..."

  # Create SQLite database file
  touch "${sqlite_data_dir}/${app_name}.sqlite"

  # Initialize database with a simple test table
  local sqlite_path="/workspace/${sqlite_data_dir}/${app_name}.sqlite"
  docker exec "${container_name}" sqlite3 "$sqlite_path" "CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY, name TEXT);" 2>/dev/null

  print_info "SQLite setup complete for webapp '$app_name'"
  print_info "Database: ${app_name}.sqlite | Location: ${sqlite_data_dir}/${app_name}.sqlite"
}

# Remove PostgreSQL database and user for webapp
remove_postgres_webapp_database() {
  local app_name="$1"
  local container_name=$(grep POSTGRES_CONTAINER_NAME .env | cut -d= -f2)
  local admin_user=$(grep POSTGRES_USER .env | cut -d= -f2)
  local admin_password=$(grep POSTGRES_PASSWORD .env | cut -d= -f2)

  print_info "Removing PostgreSQL database '$app_name' and user '$app_name'..."

  # Connect to PostgreSQL via network using admin credentials
  export PGPASSWORD="$admin_password"

  # Terminate all connections to the database
  docker exec "$container_name" psql -U "$admin_user" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$app_name';" 2>/dev/null || true

  # Drop database
  docker exec "$container_name" psql -U "$admin_user" -d postgres -c "DROP DATABASE IF EXISTS $app_name;" 2>/dev/null || print_info "Database '$app_name' not found"

  # Drop user
  docker exec "$container_name" psql -U "$admin_user" -d postgres -c "DROP USER IF EXISTS $app_name;" 2>/dev/null || print_info "User '$app_name' not found"

  print_info "PostgreSQL cleanup complete for webapp '$app_name'"
}

# Remove MariaDB database and user for webapp
remove_mariadb_webapp_database() {
  local app_name="$1"
  local container_name=$(grep MARIADB_CONTAINER_NAME .env | cut -d= -f2)
  local admin_user=$(grep MARIADB_USER .env | cut -d= -f2)
  local admin_password=$(grep MARIADB_PASSWORD .env | cut -d= -f2)

  print_info "Removing MariaDB database '$app_name' and user '$app_name'..."

  # Drop database and user
  docker exec "$container_name" mysql -u "$admin_user" -p"$admin_password" -e "DROP DATABASE IF EXISTS $app_name;" 2>/dev/null || print_info "Database '$app_name' not found"
  docker exec "$container_name" mysql -u "$admin_user" -p"$admin_password" -e "DROP USER IF EXISTS '$app_name'@'%';" 2>/dev/null || print_info "User '$app_name' not found"

  print_info "MariaDB cleanup complete for webapp '$app_name'"
}

# Remove SQLite database for webapp
remove_sqlite_webapp_database() {
  local app_name="$1"
  local sqlite_data_dir=$(grep SQLITE_DATA_DIR .env | cut -d= -f2)

  print_info "Removing SQLite database for webapp '$app_name'..."

  # Remove SQLite database file
  if [ -f "${sqlite_data_dir}/${app_name}.sqlite" ]; then
    rm -f "${sqlite_data_dir}/${app_name}.sqlite"
    print_info "Removed database file: ${sqlite_data_dir}/${app_name}.sqlite"
  else
    print_info "Database file not found: ${sqlite_data_dir}/${app_name}.sqlite"
  fi

  print_info "SQLite cleanup complete for webapp '$app_name'"
}

# Create new Maven webapp
create_webapp() {
  local app_name="$1"
  local db_type="$2"

  if [ -z "$app_name" ]; then
    print_error "Application name is required"
    exit 1
  fi

  if [ -d "projects/$app_name" ]; then
    print_error "Application '$app_name' already exists in projects/ directory"
    exit 1
  fi

  # Ensure all archetypes are installed before proceeding
  ensure_archetypes_installed
  
  if [ -n "$db_type" ]; then
    print_info "Creating webapp '$app_name' with $db_type database..."
    
    # Validate database type
    case "$db_type" in
      postgres|mariadb|sqlite)
        ;;
      *)
        print_error "Unsupported database type: $db_type. Supported: postgres, mariadb, sqlite"
        exit 1
        ;;
    esac
    
    cd projects || exit 1
    
    mvn archetype:generate \
      -DgroupId=com.example \
      -DartifactId="$app_name" \
      -DarchetypeGroupId=com.example.archetypes \
      -DarchetypeArtifactId=tomcat-webapp-database-archetype \
      -DarchetypeVersion=1.0.0 \
      -DdbType="$db_type" \
      -DinteractiveMode=false \
      -DarchetypeCatalog=local \
      -q

    # Return to original directory
    cd ..
  else
    print_info "Creating webapp '$app_name'..."
    cd projects || exit 1

    mvn archetype:generate \
      -DgroupId=com.example \
      -DartifactId="$app_name" \
      -DarchetypeGroupId=com.example.archetypes \
      -DarchetypeArtifactId=tomcat-webapp-archetype \
      -DarchetypeVersion=1.0.0 \
      -DinteractiveMode=false \
      -DarchetypeCatalog=local \
      -q

    # Return to original directory
    cd ..
  fi
    
  if [ ! -d "projects/$app_name" ]; then
    print_error "Failed to create webapp '$app_name'"
    exit 1
  fi

  # Automatically change groupId to app name
  print_info "Setting groupId to '$app_name'..."
  cd "projects/$app_name" || exit 1
  make groupid name="$app_name" >/dev/null 2>&1
  cd ../..

  # Create database and user for webapp if database type is specified
  if [ -n "$db_type" ]; then
    create_webapp_database "$app_name" "$db_type"
  fi

  print_info "Created: projects/$app_name/"
}

# Remove webapp and associated database
remove_webapp() {
  local app_name="$1"

  if [ -z "$app_name" ]; then
    print_error "Application name is required"
    exit 1
  fi

  if [ ! -d "projects/$app_name" ]; then
    print_error "Application '$app_name' not found in projects/ directory"
    exit 1
  fi

  print_info "Removing webapp '$app_name'..."

  # Determine database type by checking context.xml
  local context_xml="projects/$app_name/src/main/resources/META-INF/context.xml"
  if [ -f "$context_xml" ]; then
    if grep -q "postgresql" "$context_xml"; then
      print_info "Detected PostgreSQL database, removing..."
      remove_postgres_webapp_database "$app_name"
    elif grep -q "mariadb\|mysql" "$context_xml"; then
      print_info "Detected MariaDB database, removing..."
      remove_mariadb_webapp_database "$app_name"
    elif grep -q "sqlite" "$context_xml"; then
      print_info "Detected SQLite database, removing..."
      remove_sqlite_webapp_database "$app_name"
    else
      print_info "No database configuration detected"
    fi
  else
    print_info "No context.xml found, skipping database cleanup"
  fi

  # Remove deployed webapp from Tomcat
  local container_name=$(grep "^CONTAINER_NAME=" .env | cut -d= -f2)
  if [ -n "$container_name" ]; then
    print_info "Removing deployed webapp from Tomcat..."
    docker exec "$container_name" rm -rf "/usr/local/tomcat/webapps/${app_name}" 2>/dev/null || true
    docker exec "$container_name" rm -f "/usr/local/tomcat/webapps/${app_name}.war" 2>/dev/null || true
  fi

  # Remove project directory
  print_info "Removing project directory..."
  rm -rf "projects/$app_name"

  print_info "Webapp '$app_name' and associated resources removed successfully"
}

# Remove library
remove_library() {
  local lib_name="$1"

  if [ -z "$lib_name" ]; then
    print_error "Library name is required"
    exit 1
  fi

  if [ ! -d "projects/$lib_name" ]; then
    print_error "Library '$lib_name' not found in projects/ directory"
    exit 1
  fi

  print_info "Removing library '$lib_name'..."

  # Check if library has database support by looking for any database-related files
  if [ -f "projects/$lib_name/src/main/resources/database.properties" ] || [ -f "projects/$lib_name/src/main/resources/META-INF/context.xml" ]; then
    print_info "Library has database configuration, checking for cleanup..."

    # For libraries, we don't create dedicated databases, but we should check for any configuration
    local context_xml="projects/$lib_name/src/main/resources/META-INF/context.xml"
    if [ -f "$context_xml" ]; then
      print_info "Found database configuration in library, but libraries typically don't have dedicated databases"
    fi
  fi

  # Remove project directory
  print_info "Removing library directory..."
  rm -rf "projects/$lib_name"

  print_info "Library '$lib_name' removed successfully"
}

create_library() {
  local lib_name="$1"
  local db_type="$2"

  if [ -z "$lib_name" ]; then
    print_error "Library name is required"
    exit 1
  fi

  if [ -d "projects/$lib_name" ]; then
    print_error "Library '$lib_name' already exists in projects/ directory"
    exit 1
  fi

  # Ensure all archetypes are installed before proceeding
  ensure_archetypes_installed
  
  if [ -n "$db_type" ]; then
    print_info "Creating library '$lib_name' with $db_type database..."
    
    # Validate database type
    case "$db_type" in
      postgres|mariadb|sqlite)
        ;;
      *)
        print_error "Unsupported database type: $db_type. Supported: postgres, mariadb, sqlite"
        exit 1
        ;;
    esac
    
    cd projects || exit 1
    
    mvn archetype:generate \
      -DgroupId=com.example \
      -DartifactId="$lib_name" \
      -DarchetypeGroupId=com.example.archetypes \
      -DarchetypeArtifactId=tomcat-jar-database-archetype \
      -DarchetypeVersion=1.0.0 \
      -DdbType="$db_type" \
      -DinteractiveMode=false \
      -DarchetypeCatalog=local \
      -q

    # Return to original directory
    cd ..
  else
    print_info "Creating library '$lib_name'..."
    cd projects || exit 1

    mvn archetype:generate \
      -DgroupId=com.example \
      -DartifactId="$lib_name" \
      -DarchetypeGroupId=com.example.archetypes \
      -DarchetypeArtifactId=tomcat-jar-library \
      -DarchetypeVersion=1.0.0 \
      -DinteractiveMode=false \
      -DarchetypeCatalog=local \
      -q

    # Return to original directory
    cd ..
  fi

  if [ ! -d "projects/$lib_name" ]; then
    print_error "Failed to create library '$lib_name'"
    exit 1
  fi

  # Automatically change groupId to library name
  print_info "Setting groupId to '$lib_name'..."
  cd "projects/$lib_name" || exit 1
  make groupid name="$lib_name" >/dev/null 2>&1
  cd ../..

  print_info "Created: projects/$lib_name/"
}

# Parse command line arguments
parse_args() {
  while [ $# -gt 0 ]; do
    case $1 in
      --postgres)
        INSTALL_POSTGRES=true
        shift
        ;;
      --mariadb)
        INSTALL_MARIADB=true
        shift
        ;;
      --sqlite)
        INSTALL_SQLITE=true
        shift
        ;;
      --claude)
        INSTALL_CLAUDE=true
        shift
        ;;
      --create-webapp)
        if [ -z "$2" ]; then
          print_error "--create-webapp requires an application name"
          exit 1
        fi
        CREATE_WEBAPP="$2"
        shift 2
        ;;
      --create-library)
        if [ -z "$2" ]; then
          print_error "--create-library requires a library name"
          exit 1
        fi
        CREATE_LIBRARY="$2"
        shift 2
        ;;
      --remove-webapp)
        if [ -z "$2" ]; then
          print_error "--remove-webapp requires an application name"
          exit 1
        fi
        REMOVE_WEBAPP="$2"
        shift 2
        ;;
      --remove-library)
        if [ -z "$2" ]; then
          print_error "--remove-library requires a library name"
          exit 1
        fi
        REMOVE_LIBRARY="$2"
        shift 2
        ;;
      --database)
        if [ -z "$2" ]; then
          print_error "--database requires a database type (postgres, mariadb, sqlite)"
          exit 1
        fi
        DATABASE_TYPE="$2"
        shift 2
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
}

# Show usage information
show_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Sets up Tomcat development environment with Docker container."
  echo ""
  echo "Options:"
  echo "  --postgres             Also install and start PostgreSQL container"
  echo "  --mariadb              Also install and start MariaDB container"
  echo "  --sqlite               Also install SQLite3 in Tomcat container"
  echo "  --claude               Install Claude Code with NVM and Node.js 18"
  echo "  --create-webapp <name> Create new Maven webapp with Makefile and README"
  echo "  --create-library <name> Create new JAR library with Makefile and README"
  echo "  --remove-webapp <name>  Remove webapp and associated database"
  echo "  --remove-library <name> Remove JAR library"
  echo "  --database <type>       Add database support (postgres, mariadb, sqlite)"
  echo "  --help, -h             Show this help"
  echo ""
  echo "Examples:"
  echo "  $0                           # Setup Tomcat only"
  echo "  $0 --postgres                # Setup Tomcat + PostgreSQL"
  echo "  $0 --mariadb                 # Setup Tomcat + MariaDB"
  echo "  $0 --sqlite                  # Setup Tomcat + SQLite3"
  echo "  $0 --create-webapp myapp     # Create new webapp 'myapp'"
  echo "  $0 --create-library mylib    # Create new JAR library 'mylib'"
  echo "  $0 --remove-webapp myapp     # Remove webapp 'myapp' and database"
  echo "  $0 --remove-library mylib    # Remove library 'mylib'"
  echo "  $0 --postgres --sqlite       # Setup Tomcat + PostgreSQL + SQLite3"
  echo "  $0 --claude                  # Setup Tomcat + Claude Code"
}

# Main execution - Setup environment with two-phase .env check
main() {
  # Parse command line arguments
  parse_args "$@"
  
  # Handle create-webapp command
  if [ -n "$CREATE_WEBAPP" ]; then
    create_webapp "$CREATE_WEBAPP" "$DATABASE_TYPE"
    exit 0
  fi

  if [ -n "$REMOVE_WEBAPP" ]; then
    remove_webapp "$REMOVE_WEBAPP"
    exit 0
  fi

  if [ -n "$REMOVE_LIBRARY" ]; then
    remove_library "$REMOVE_LIBRARY"
    exit 0
  fi

  if [ -n "$CREATE_LIBRARY" ]; then
    create_library "$CREATE_LIBRARY" "$DATABASE_TYPE"
    exit 0
  fi
  
  print_header "Java Web Application Environment Setup"
  echo ""
  # Phase 1: Check if .env exists - if not, create it and exit
  if [ ! -f ".env" ]; then
    print_info ".env file not found, creating configuration file..."
    create_env_file
    echo ""
    print_info "=== Configuration Created ==="
    print_info "The .env configuration file has been created with default values."
    print_info "Please review and customize the settings in .env if needed."
    print_info "Then run the installation script again to proceed with setup."
    echo ""
    print_warn "Installation paused. Run './install.sh' again to continue."
    return 0
  fi
  # Phase 2: .env exists, proceed with full installation
  print_info "Configuration file .env found, proceeding with installation..."
  echo ""
  # Setup steps
  check_docker
  create_basic_directories
  create_gitignore
  create_projects_folder
  create_docker_network
  pull_tomcat_image
  copy_default_config
  create_tomcat_config
  start_container
  wait_for_tomcat
  install_dev_tools
  configure_git
  configure_shell_aliases
  echo ""
  print_info "=== Setup Complete ==="
  HOST_PORT=$(grep HOST_PORT .env | cut -d= -f2)
  print_info "Container: $(grep "^CONTAINER_NAME=" .env | cut -d= -f2) running"
  # Installation completed - no more automatic webapp setup
  echo ""
  print_info "Installation completed successfully"
  echo ""
  echo "Tomcat Manager URLs:"
  echo "  http://localhost:${HOST_PORT}/manager/html"
  echo "  http://localhost:${HOST_PORT}/host-manager/html"
  echo ""
  echo "Generate webapps with:"
  echo "  make app name=<app_name>           # Simple webapp"
  echo "  make app name=<app_name> db=<type> # Database webapp"
  echo ""
  ADMIN_USER=$(grep ADMIN_USER .env | cut -d= -f2)
  ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d= -f2)
  MANAGER_USER=$(grep MANAGER_USER .env | cut -d= -f2)
  MANAGER_PASSWORD=$(grep MANAGER_PASSWORD .env | cut -d= -f2)
  echo "Login: $ADMIN_USER / $ADMIN_PASSWORD (or $MANAGER_USER / $MANAGER_PASSWORD)"
  
  # Setup databases if requested
  if [ "$INSTALL_POSTGRES" = "true" ]; then
    echo ""
    setup_postgres
  fi
  
  if [ "$INSTALL_MARIADB" = "true" ]; then
    echo ""
    setup_mariadb
  fi
  
  if [ "$INSTALL_SQLITE" = "true" ]; then
    echo ""
    setup_sqlite
  fi

  if [ "$INSTALL_CLAUDE" = "true" ]; then
    echo ""
    install_claude_code
  fi
}

main "$@"
