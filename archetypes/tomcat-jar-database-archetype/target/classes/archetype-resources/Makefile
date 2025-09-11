MAKEFLAGS += --no-print-directory

# ${artifactId} Library Build System
# Usage: make [target]

.DEFAULT_GOAL := help

# Build targets
build:
	@echo "Building ${artifactId} library..."
	@mvn package -q

compile:
	@echo "Compiling ${artifactId} library..."
	@mvn compile -q

# Testing
test:
	@echo "Running unit tests for ${artifactId}..."
	@mvn test

test-verbose:
	@echo "Running unit tests with verbose output..."
	@mvn test -X

# Install to local Maven repository
install:
	@echo "Installing ${artifactId} to local Maven repository..."
	@mvn install -q

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@mvn clean -q

# Generate Javadoc
docs:
	@echo "Generating Javadoc..."
	@mvn javadoc:javadoc -q

# Development targets
dev-build: clean compile test
	@echo "${artifactId} development build completed"

dev-install: clean install
	@echo "${artifactId} installed to local repository"

# Check if library is available in local repo
check-repo:
	@echo "Checking if ${artifactId} is installed in local Maven repository:"
	@find ~/.m2/repository -name "*${artifactId}*" -type f 2>/dev/null | head -5 || echo "Library not found in local repository"

# Show Maven coordinates for using this library
coordinates:
	@echo "To use this library in other projects, add this dependency:"
	@echo ""
	@echo "<dependency>"
	@echo "    <groupId>${groupId}</groupId>"
	@echo "    <artifactId>${artifactId}</artifactId>"
	@echo "    <version>${version}</version>"
	@echo "</dependency>"

# Display help
help:
	@echo "${artifactId} Library - Available targets:"
	@echo ""
	@echo "  build          - Build JAR library"
	@echo "  compile        - Compile source code"
	@echo "  test          - Run unit tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  install       - Install to local Maven repository"
	@echo "  clean         - Clean build artifacts"
	@echo "  docs          - Generate Javadoc"
	@echo ""
	@echo "  dev-build     - Full development build (clean + compile + test)"
	@echo "  dev-install   - Clean install to local repository"
	@echo "  check-repo    - Check if library is in local Maven repo"
	@echo "  coordinates   - Show Maven dependency coordinates"
	@echo ""
	@echo "  help          - Show this help message"

.PHONY: build compile test test-verbose install clean docs dev-build dev-install check-repo coordinates help