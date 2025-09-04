# Main Project Makefile

.PHONY: build deploy help

help:
	@echo "Usage:"
	@echo "  make build app=<app_name>   - Build specific app"
	@echo "  make deploy app=<app_name>  - Deploy specific app"
	@echo ""
	@echo "Examples:"
	@echo "  make build app=helloworld"
	@echo "  make deploy app=helloworld"
	@echo "  make build app=todo"
	@echo "  make deploy app=todo"

build:
	@if [ -z "$(app)" ]; then \
		echo "Error: app parameter required. Usage: make build app=<app_name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(app)" ]; then \
		echo "Error: App '$(app)' not found in current directory"; \
		exit 1; \
	fi
	@if [ ! -f "$(app)/Makefile" ]; then \
		echo "Error: No Makefile found in $(app)/ directory"; \
		exit 1; \
	fi
	@cd $(app) && $(MAKE) build

deploy:
	@if [ -z "$(app)" ]; then \
		echo "Error: app parameter required. Usage: make deploy app=<app_name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(app)" ]; then \
		echo "Error: App '$(app)' not found in current directory"; \
		exit 1; \
	fi
	@if [ ! -f "$(app)/Makefile" ]; then \
		echo "Error: No Makefile found in $(app)/ directory"; \
		exit 1; \
	fi
	@cd $(app) && $(MAKE) deploy