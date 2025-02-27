# Makefile for Khoj - Development and Installation
# ==================================================

# Variables
VENV_DIR := .venv
PYTHON := python3
PIP := $(VENV_DIR)/bin/pip
KHOJ := $(VENV_DIR)/bin/khoj
PROJECT_DIR := $(shell pwd)
WEB_DIR := $(PROJECT_DIR)/src/interface/web
TMP_DIR := $(PROJECT_DIR)/.tmp
ROOT_DIR := $(PROJECT_DIR)
FRONTEND_DIR := $(PROJECT_DIR)/src/interface/web
SHELL := /bin/bash

# Color support and terminal capability detection
HAS_TPUT := $(shell command -v tput >/dev/null 2>&1 && echo 1 || echo 0)
COLOR_SUPPORT ?= $(HAS_TPUT)

ifeq ($(COLOR_SUPPORT),1)
	# Use tput for colors if available
	CYAN = $(shell tput setaf 6)
	GREEN = $(shell tput setaf 2)
	YELLOW = $(shell tput setaf 3)
	RED = $(shell tput setaf 1)
	BLUE = $(shell tput setaf 4)
	MAGENTA = $(shell tput setaf 5)
	BOLD = $(shell tput bold)
	DIM = $(shell tput dim 2>/dev/null || echo "")
	RESET = $(shell tput sgr0)
else
	# No colors
	CYAN :=
	GREEN :=
	YELLOW :=
	RED :=
	BLUE :=
	MAGENTA :=
	BOLD :=
	DIM :=
	RESET :=
endif

# Define badges for status messages
OK_BADGE := $(GREEN)$(BOLD)[OK]$(RESET)
ERROR_BADGE := $(RED)$(BOLD)[ERROR]$(RESET)
LOADING_BADGE := $(YELLOW)$(BOLD)[LOADING]$(RESET)
IDLE_BADGE := $(BLUE)$(BOLD)[IDLE]$(RESET)
INFO_BADGE := $(CYAN)$(BOLD)[INFO]$(RESET)
WARNING_BADGE := $(YELLOW)$(BOLD)[WARNING]$(RESET)
QUESTION_BADGE := $(MAGENTA)$(BOLD)[?]$(RESET)

# Default database configuration
DB_HOST := localhost
DB_PORT := 5432
DB_NAME := khoj
DB_USER := postgres
DB_PASS := postgres

# Default API key configuration
DEFAULT_MODEL := gpt-4o-mini

# Default frontend port
FRONTEND_PORT := 3000

# Detect OS for terminal commands and browser
ifeq ($(OS),Windows_NT)
	OPEN_TERMINAL = start cmd /c
	OPEN_BROWSER = start
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OPEN_TERMINAL = x-terminal-emulator -e
		OPEN_BROWSER = xdg-open
	endif
	ifeq ($(UNAME_S),Darwin)
		OPEN_TERMINAL = osascript -e 'tell app "Terminal" to do script "cd $(PROJECT_DIR) && '
		OPEN_BROWSER = open
	endif
endif

# Main targets
.PHONY: all install setup-db build-frontend run-backend run-frontend-dev dev run-dev run-dev-color check-deps logs-backend logs-frontend stop-servers clean help verify-db-access check-api-keys setup-api-keys initialize stop-dev check-env check-server-status monitor-servers

all: help

help:
	@echo "$(CYAN)Makefile for Khoj Development$(RESET)"
	@echo "----------------------------------------"
	@echo "$(GREEN)Available commands:$(RESET)"
	@echo "  $(YELLOW)make install$(RESET)          - Install Khoj and all dependencies"
	@echo "  $(YELLOW)make setup-db$(RESET)         - Configure PostgreSQL database"
	@echo "  $(YELLOW)make verify-db-access$(RESET) - Verify database access and configuration"
	@echo "  $(YELLOW)make check-api-keys$(RESET)   - Check for API provider keys"
	@echo "  $(YELLOW)make setup-api-keys$(RESET)   - Configure API provider keys"
	@echo "  $(YELLOW)make build-frontend$(RESET)   - Build frontend assets"
	@echo "  $(YELLOW)make run-backend$(RESET)      - Run Khoj backend server in anonymous mode"
	@echo "  $(YELLOW)make run-frontend-dev$(RESET) - Run frontend development server"
	@echo "  $(YELLOW)make run-dev$(RESET)          - Launch complete development environment following these steps:"
	@echo "                                1. Install dependencies"
	@echo "                                2. Set up PostgreSQL and database"
	@echo "                                3. Configure admin user if needed"
	@echo "                                4. Start servers with continuous monitoring"
	@echo "  $(YELLOW)make run-servers$(RESET)      - Start backend and frontend servers"
	@echo "  $(YELLOW)make monitor-servers$(RESET)  - Monitor running servers with status updates every 5 seconds"
	@echo "  $(YELLOW)make logs-backend$(RESET)     - View backend server logs in real-time"
	@echo "  $(YELLOW)make logs-frontend$(RESET)    - View frontend server logs in real-time"
	@echo "  $(YELLOW)make stop-servers$(RESET)     - Stop all running development servers"
	@echo "  $(YELLOW)make clean$(RESET)            - Clean temporary files and stop servers"
	@echo "  $(YELLOW)make edit-env$(RESET)         - Edit configuration in .env file"
	@echo ""
	@echo "$(CYAN)Typical workflow:$(RESET)"
	@echo "  1. make install"
	@echo "  2. make setup-db"
	@echo "  3. make check-api-keys"
	@echo "  4. make run-dev"

# Check if python3 is available
check-python:
	@command -v python3 >/dev/null 2>&1 || { echo "$(RED)Python3 is required but not installed.$(RESET)"; exit 1; }
	@echo "$(GREEN)Python3 is available.$(RESET)"

# Complete installation
install: create-venv install-backend install-frontend

# Create virtual environment
create-venv: check-python
	@echo "$(CYAN)Creating virtual environment...$(RESET)"
	@$(PYTHON) -m venv $(VENV_DIR) || (echo "$(RED)Error creating virtual environment$(RESET)" && exit 1)
	@. $(VENV_DIR)/bin/activate && pip install --upgrade pip setuptools wheel
	@. $(VENV_DIR)/bin/activate && pip install -e '.[dev]'
	@. $(VENV_DIR)/bin/activate && pip install -e src/
	@echo "$(GREEN)Virtual environment created successfully.$(RESET)"

# Install backend
install-backend: create-venv
	@echo "$(CYAN)Installing backend dependencies...$(RESET)"
	@. $(VENV_DIR)/bin/activate && pip install -e '.[dev]' || (echo "$(RED)Error installing backend dependencies$(RESET)" && exit 1)
	@echo "$(GREEN)Backend installed successfully.$(RESET)"

# Install frontend dependencies
install-frontend:
	@echo "$(CYAN)Installing frontend dependencies...$(RESET)"
	@# Check if yarn is installed
	@if ! command -v yarn >/dev/null 2>&1; then \
		echo "$(YELLOW)Yarn not found. Installing yarn...$(RESET)"; \
		npm install -g yarn || (echo "$(RED)Error installing yarn. Please install it manually.$(RESET)" && exit 1); \
	fi
	@cd $(WEB_DIR) && yarn install || (echo "$(RED)Error installing frontend dependencies$(RESET)" && exit 1)
	@echo "$(GREEN)Frontend dependencies installed successfully.$(RESET)"

# Database configuration
setup-db:
	@echo "$(CYAN)Configuring PostgreSQL database...$(RESET)"
	@echo "$(YELLOW)Starting PostgreSQL...$(RESET)"
	@sudo service postgresql start || (echo "$(RED)Error starting PostgreSQL$(RESET)" && exit 1)
	
	@echo "$(YELLOW)Setting up postgres user password...$(RESET)"
	@sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" 2>/dev/null || echo "$(YELLOW)Password already set.$(RESET)"
	
	@echo "$(YELLOW)Creating khoj database...$(RESET)"
	@sudo -u postgres createdb khoj 2>/dev/null || echo "$(YELLOW)khoj database already exists.$(RESET)"
	
	@echo "$(YELLOW)Setting environment variables...$(RESET)"
	@mkdir -p $(TMP_DIR)
	@echo "POSTGRES_PASSWORD=postgres" > $(TMP_DIR)/.env
	
	@echo "$(GREEN)Database configured successfully.$(RESET)"
	@$(MAKE) verify-db-access

# Verify database access
verify-db-access:
	@echo "$(CYAN)Verifying database access...$(RESET)"
	@mkdir -p $(TMP_DIR)
	
	@echo "$(YELLOW)Testing connection to PostgreSQL...$(RESET)"
	@if ! sudo -u postgres psql -c "SELECT 1" > /dev/null 2>&1; then \
		echo "$(RED)Error: Cannot connect to PostgreSQL server. Make sure it's running.$(RESET)"; \
		echo "$(YELLOW)Attempting to start PostgreSQL...$(RESET)"; \
		sudo service postgresql start || (echo "$(RED)Error starting PostgreSQL$(RESET)" && exit 1); \
	fi
	@echo "$(GREEN)PostgreSQL server is running.$(RESET)"
	
	@echo "$(YELLOW)Testing connection to khoj database...$(RESET)"
	@if ! sudo -u postgres psql -d khoj -c "SELECT 1" > /dev/null 2>&1; then \
		echo "$(YELLOW)Cannot connect to khoj database. Attempting to create it...$(RESET)"; \
		sudo -u postgres createdb khoj 2>/dev/null || \
		(echo "$(RED)Error: Failed to create khoj database.$(RESET)" && exit 1); \
	fi
	@echo "$(GREEN)Connection to khoj database successful.$(RESET)"
	
	@echo "$(YELLOW)Checking pgvector extension...$(RESET)"
	@if ! sudo -u postgres psql -d khoj -c "SELECT 1 FROM pg_extension WHERE extname = 'vector'" | grep -q 1; then \
		echo "$(YELLOW)pgvector extension not installed. Attempting to install...$(RESET)"; \
		sudo -u postgres psql -d khoj -c "CREATE EXTENSION IF NOT EXISTS vector" || \
		(echo "$(RED)Error: Failed to install pgvector extension.$(RESET)" && \
		echo "$(YELLOW)Please install pgvector manually. See: https://github.com/pgvector/pgvector#installation$(RESET)" && \
		exit 1); \
	fi
	@echo "$(GREEN)pgvector extension is properly installed.$(RESET)"
	
	@echo "$(OK_BADGE) Database configuration verified successfully.$(RESET)"

# Check for API keys
check-api-keys:
	@echo "$(CYAN)Checking for API provider keys...$(RESET)"
	@mkdir -p $(TMP_DIR)
	
	@echo "$(YELLOW)Looking for existing API keys...$(RESET)"
	@if [ -f "$(PROJECT_DIR)/.env" ] && grep -q "OPENAI_API_KEY" "$(PROJECT_DIR)/.env"; then \
		echo "$(GREEN)OpenAI API key found in .env file.$(RESET)"; \
		KEY_VALUE=$$(grep "OPENAI_API_KEY" "$(PROJECT_DIR)/.env" | cut -d= -f2); \
		if [ -n "$$KEY_VALUE" ]; then \
			echo "$(GREEN)OpenAI API key is configured.$(RESET)"; \
		else \
			echo "$(YELLOW)OpenAI API key is empty in .env file.$(RESET)"; \
			$(MAKE) setup-api-keys; \
		fi; \
	else \
		echo "$(YELLOW)No API keys found in .env file.$(RESET)"; \
		$(MAKE) setup-api-keys; \
	fi

# Setup API keys
setup-api-keys:
	@echo "$(CYAN)Setting up API provider keys...$(RESET)"
	
	@# Create .env file if it doesn't exist
	@if [ ! -f "$(PROJECT_DIR)/.env" ]; then \
		echo "$(YELLOW)Creating new .env file...$(RESET)"; \
		echo "POSTGRES_PASSWORD=$(DB_PASS)" > $(PROJECT_DIR)/.env; \
		echo "POSTGRES_USER=$(DB_USER)" >> $(PROJECT_DIR)/.env; \
		echo "POSTGRES_DB=$(DB_NAME)" >> $(PROJECT_DIR)/.env; \
		echo "POSTGRES_HOST=$(DB_HOST)" >> $(PROJECT_DIR)/.env; \
		echo "POSTGRES_PORT=$(DB_PORT)" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_ANONYMOUS_MODE=true" >> $(PROJECT_DIR)/.env; \
		echo "DEFAULT_MODEL=$(DEFAULT_MODEL)" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_ADMIN_EMAIL=admin@example.com" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_ADMIN_PASSWORD=adminpassword" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_SKIP_ADMIN_INIT=true" >> $(PROJECT_DIR)/.env; \
		echo "TRANSFORMERS_OFFLINE=1" >> $(PROJECT_DIR)/.env; \
		echo "HF_HUB_OFFLINE=1" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_DISABLE_EMBEDDINGS=true" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_DISABLE_MODELS=true" >> $(PROJECT_DIR)/.env; \
	fi
	
	@echo "$(QUESTION_BADGE) Do you want to configure an OpenAI API key? (y/n) $(RESET)"
	@read -p "" setup_openai; \
	if [ "$$setup_openai" = "y" ]; then \
		echo "$(QUESTION_BADGE) Enter your OpenAI API key: $(RESET)"; \
		read -p "" openai_key; \
		if [ -n "$$openai_key" ]; then \
			# Remove any existing OpenAI key from .env \
			grep -v "OPENAI_API_KEY" "$(PROJECT_DIR)/.env" > "$(PROJECT_DIR)/.env.tmp" || true; \
			mv "$(PROJECT_DIR)/.env.tmp" "$(PROJECT_DIR)/.env"; \
			# Add the new key \
			echo "OPENAI_API_KEY=$$openai_key" >> "$(PROJECT_DIR)/.env"; \
			echo "$(GREEN)OpenAI API key saved to .env file.$(RESET)"; \
			echo "$(INFO_BADGE) The API key will be configured in the database when you start the server.$(RESET)"; \
		else \
			echo "$(YELLOW)No API key provided.$(RESET)"; \
		fi; \
	else \
		echo "$(WARNING_BADGE) Skipping OpenAI API key configuration.$(RESET)"; \
		echo "$(INFO_BADGE) You can still use offline models, but some features may be limited.$(RESET)"; \
	fi

# Build frontend assets
build-frontend:
	@echo "$(CYAN)Building frontend assets...$(RESET)"
	@cd $(WEB_DIR) && yarn export || (echo "$(RED)Error building frontend assets$(RESET)" && exit 1)
	@echo "$(GREEN)Frontend assets built successfully.$(RESET)"

# Run backend server
run-backend:
	@echo "$(CYAN)Starting Khoj backend server in anonymous mode...$(RESET)"
	@echo "$(YELLOW)Server will be accessible at http://127.0.0.1:42110$(RESET)"
	@. $(VENV_DIR)/bin/activate && khoj -vv --anonymous-mode

# Run frontend development server
run-frontend-dev:
	@echo "$(CYAN)Starting frontend development server...$(RESET)"
	@echo "$(YELLOW)Server will be accessible at http://localhost:$(FRONTEND_PORT)$(RESET)"
	@cd $(WEB_DIR) && PORT=$(FRONTEND_PORT) yarn dev

# View backend logs in real-time
logs-backend:
	@if [ ! -f "$(TMP_DIR)/logs/backend.log" ]; then \
		echo "$(RED)No backend logs found. Is the server running?$(RESET)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Showing backend logs. Press Ctrl+C to exit...$(RESET)"
	@tail -f $(TMP_DIR)/logs/backend.log

# View frontend logs in real-time
logs-frontend:
	@if [ ! -f "$(TMP_DIR)/logs/frontend.log" ]; then \
		echo "$(RED)No frontend logs found. Is the server running?$(RESET)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Showing frontend logs. Press Ctrl+C to exit...$(RESET)"
	@tail -f $(TMP_DIR)/logs/frontend.log

# Development instructions
dev:
	@echo "$(CYAN)Development setup:$(RESET)"
	@echo "$(YELLOW)For a complete development experience, run these commands in separate terminals:$(RESET)"
	@echo ""
	@echo "$(GREEN)Terminal 1 (Backend):$(RESET)"
	@echo "  make run-backend"
	@echo ""
	@echo "$(GREEN)Terminal 2 (Frontend):$(RESET)"
	@echo "  make run-frontend-dev"
	@echo ""
	@echo "$(YELLOW)Notes:$(RESET)"
	@echo "- Backend will be accessible at http://127.0.0.1:42110"
	@echo "- Development frontend will be accessible at http://localhost:$(FRONTEND_PORT)"
	@echo "- Streaming doesn't work on the frontend development server"
	@echo "- To test with all integrated components, use only 'make run-backend'"
	@echo ""
	@echo "$(YELLOW)For automatic setup with live monitoring, run:$(RESET)"
	@echo "  make run-dev"

# Check dependencies
check-deps:
	@echo "$(CYAN)Checking dependencies...$(RESET)"
	@# Check if virtual environment exists
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "$(RED)Virtual environment not found. Installing project...$(RESET)"; \
		$(MAKE) install; \
	fi
	@# Check PostgreSQL
	@if ! sudo service postgresql status >/dev/null 2>&1; then \
		echo "$(YELLOW)PostgreSQL is not running. Starting PostgreSQL...$(RESET)"; \
		sudo service postgresql start || (echo "$(RED)Failed to start PostgreSQL. Setting up database...$(RESET)" && $(MAKE) setup-db); \
	fi
	@# Verify database access
	@$(MAKE) verify-db-access || (echo "$(WARNING_BADGE) Database configuration issue detected. Attempting to fix...$(RESET)" && $(MAKE) setup-db)
	@# Check API keys
	@$(MAKE) check-api-keys || echo "$(WARNING_BADGE) Continuing with anonymous mode.$(RESET)"
	@# Check frontend dependencies
	@if [ ! -d "$(WEB_DIR)/node_modules" ]; then \
		echo "$(RED)Frontend dependencies not installed. Installing...$(RESET)"; \
		$(MAKE) install-frontend; \
	fi
	@echo "$(GREEN)All dependencies are properly checked.$(RESET)"

# Check if servers are running
check-server-status:
	@echo "$(CYAN)Checking server status...$(RESET)"
	@# Check if backend is running
	@if pgrep -f "python -m khoj.main" > /dev/null; then \
		echo "$(GREEN)Backend server is already running.$(RESET)"; \
		BACKEND_RUNNING=1; \
	else \
		echo "$(YELLOW)Backend server is not running.$(RESET)"; \
		BACKEND_RUNNING=0; \
	fi
	@# Check if frontend is running
	@if pgrep -f "next dev" > /dev/null; then \
		echo "$(GREEN)Frontend server is already running.$(RESET)"; \
		FRONTEND_RUNNING=1; \
	else \
		echo "$(YELLOW)Frontend server is not running.$(RESET)"; \
		FRONTEND_RUNNING=0; \
	fi

# Open browser when servers are ready
open-browser:
	@echo "$(CYAN)Opening browser...$(RESET)"
	@$(OPEN_BROWSER) http://localhost:$(FRONTEND_PORT) >/dev/null 2>&1 || true

# Open logs in separate terminals
open-logs-backend:
	@echo "$(CYAN)Opening backend logs in a new terminal...$(RESET)"
	@$(OPEN_TERMINAL) "cd $(PROJECT_DIR) && make logs-backend" >/dev/null 2>&1 &

open-logs-frontend:
	@echo "$(CYAN)Opening frontend logs in a new terminal...$(RESET)"
	@$(OPEN_TERMINAL) "cd $(PROJECT_DIR) && make logs-frontend" >/dev/null 2>&1 &

# Initialize the backend interactively
initialize:
	@echo "$(CYAN)Initializing Khoj backend interactively...$(RESET)"
	@mkdir -p $(TMP_DIR)/logs
	@if [ ! -f "$(PROJECT_DIR)/.env" ]; then \
		echo "$(YELLOW)Creating new .env file with default configuration...$(RESET)"; \
		echo "POSTGRES_PASSWORD=$(DB_PASS)" > $(PROJECT_DIR)/.env; \
		echo "POSTGRES_USER=$(DB_USER)" >> $(PROJECT_DIR)/.env; \
	fi
	
	@echo "$(CYAN)Launching Khoj in interactive mode...$(RESET)"
	@echo "$(YELLOW)You'll be prompted to configure an admin user and optionally an OpenAI API key.$(RESET)"
	@echo "$(YELLOW)After finishing the configuration, stop the server with Ctrl+C.$(RESET)"
	@( \
		cd $(ROOT_DIR) && \
		. $(PROJECT_DIR)/$(VENV_DIR)/bin/activate && \
		export PYTHONPATH=$(PYTHONPATH):$(shell pwd)/src && \
		# Load variables from .env file into the environment \
		export $$(grep -v '^#' $(PROJECT_DIR)/.env | xargs) && \
		# Run the backend server in interactive mode \
		python -m khoj.main -vv --anonymous-mode \
	)
	
	@echo "$(GREEN)Initialization completed.$(RESET)"
	@echo "$(INFO_BADGE) Administrator information has been saved.$(RESET)"
	@echo ""
	@echo "$(CYAN)To launch servers in normal mode, run:$(RESET)"
	@echo "make run-servers"

# Run only the servers (without interactive initialization)
run-servers: check-env
	@echo "$(CYAN)Starting Khoj servers...$(RESET)"
	
	@# Stop any existing servers to avoid port conflicts
	@$(MAKE) stop-servers > /dev/null 2>&1 || true
	
	@# Make sure KHOJ_DISABLE_EMBEDDINGS is set in .env
	@if ! grep -q "KHOJ_DISABLE_EMBEDDINGS" .env; then \
		echo "$(YELLOW)Adding KHOJ_DISABLE_EMBEDDINGS=true to .env...$(RESET)"; \
		echo "KHOJ_DISABLE_EMBEDDINGS=true" >> .env; \
	fi
	
	@# Start backend server in background
	@echo "$(LOADING_BADGE) Starting backend server...$(RESET)"
	@mkdir -p $(TMP_DIR)/logs
	@. .venv/bin/activate && \
	  export $$(grep -v '^#' $(PROJECT_DIR)/.env | xargs) && \
	  export TRANSFORMERS_OFFLINE=1 && \
	  export HF_HUB_OFFLINE=1 && \
	  export KHOJ_SKIP_ADMIN_INIT=true && \
	  export KHOJ_DISABLE_EMBEDDINGS=true && \
	  export KHOJ_DISABLE_MODELS=true && \
	  export SENTENCE_TRANSFORMERS_HOME=/tmp/non-existent-dir && \
	  export HF_HOME=/tmp/non-existent-dir && \
	  python -m khoj.main --host 127.0.0.1 --port 42110 --anonymous-mode --non-interactive > $(TMP_DIR)/logs/backend.log 2>&1 &
	@echo "$(INFO_BADGE) Backend server starting at http://localhost:42110$(RESET)"
	@echo "$(LOADING_BADGE) Waiting for backend to initialize...$(RESET)"
	@sleep 5
	
	@# Check if backend started successfully
	@if ! curl -s http://localhost:42110/api/health > /dev/null 2>&1; then \
		echo "$(ERROR_BADGE) Backend server failed to start properly. Check logs: make logs-backend$(RESET)"; \
	else \
		echo "$(OK_BADGE) Backend server started successfully.$(RESET)"; \
	fi
	
	@# Create admin user if needed
	@if ! grep -q "KHOJ_SKIP_ADMIN_INIT=true" .env || [ "$$(grep KHOJ_SKIP_ADMIN_INIT .env | cut -d '=' -f2)" != "true" ]; then \
		echo "$(LOADING_BADGE) Creating admin user if needed...$(RESET)"; \
		. .venv/bin/activate && \
		export $$(grep -v '^#' $(PROJECT_DIR)/.env | xargs) && \
		python -c "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(email='$$(grep KHOJ_ADMIN_EMAIL .env | cut -d '=' -f2)').exists() or User.objects.create_superuser('$$(grep KHOJ_ADMIN_EMAIL .env | cut -d '=' -f2)', '$$(grep KHOJ_ADMIN_PASSWORD .env | cut -d '=' -f2)')" 2>/dev/null || echo "$(INFO_BADGE) Admin user creation will be handled by the app$(RESET)"; \
	else \
		echo "$(INFO_BADGE) Skipping admin user initialization as KHOJ_SKIP_ADMIN_INIT=true$(RESET)"; \
	fi
	
	@# Start frontend server in background
	@echo "$(LOADING_BADGE) Starting frontend server...$(RESET)"
	@mkdir -p $(TMP_DIR)/logs
	@cd $(FRONTEND_DIR) && PORT=$(FRONTEND_PORT) yarn dev > $(TMP_DIR)/logs/frontend.log 2>&1 &
	@echo "$(INFO_BADGE) Frontend server starting at http://localhost:$(FRONTEND_PORT)$(RESET)"
	@echo "$(LOADING_BADGE) Waiting for frontend to initialize...$(RESET)"
	@sleep 5
	
	@# Check if frontend started successfully
	@if ! curl -s http://localhost:$(FRONTEND_PORT) > /dev/null 2>&1; then \
		echo "$(WARNING_BADGE) Frontend server might not have started properly. Trying alternate port...$(RESET)"; \
		for port in 3001 3002 3003; do \
			if curl -s http://localhost:$$port > /dev/null 2>&1; then \
				echo "$(OK_BADGE) Frontend server started on port $$port instead of $(FRONTEND_PORT).$(RESET)"; \
				break; \
			fi; \
		done; \
	else \
		echo "$(OK_BADGE) Frontend server started successfully on port $(FRONTEND_PORT).$(RESET)"; \
	fi
	
	@echo "$(OK_BADGE) Both servers are now running.$(RESET)"
	@echo "$(INFO_BADGE) Backend API: http://localhost:42110$(RESET)"
	@echo "$(INFO_BADGE) Frontend UI: http://localhost:$(FRONTEND_PORT) (check other ports if unavailable: 3001, 3002)$(RESET)"
	@echo "$(INFO_BADGE) Starting server monitoring...$(RESET)"
	@$(MAKE) monitor-servers

# Modify run-dev to run the interactive initialization first
run-dev: check-deps
	@echo "$(CYAN)Starting development environment...$(RESET)"
	@echo "$(YELLOW)Following the specified setup sequence:$(RESET)"
	
	@echo "$(CYAN)Step 1: Checking dependencies...$(RESET)"
	@# Dependencies are checked by check-deps dependency
	@# Ensure .env file exists with all necessary values
	@if [ ! -f ".env" ]; then \
		echo "$(YELLOW)Creating .env file with default settings...$(RESET)"; \
		echo "POSTGRES_PASSWORD=postgres" > .env; \
		echo "POSTGRES_USER=postgres" >> .env; \
		echo "POSTGRES_DB=khoj" >> .env; \
		echo "POSTGRES_HOST=localhost" >> .env; \
		echo "POSTGRES_PORT=5432" >> .env; \
		echo "KHOJ_ANONYMOUS_MODE=true" >> .env; \
		echo "DEFAULT_MODEL=gpt-4o-mini" >> .env; \
		echo "KHOJ_ADMIN_EMAIL=admin@example.com" >> .env; \
		echo "KHOJ_ADMIN_PASSWORD=adminpassword" >> .env; \
		echo "TRANSFORMERS_OFFLINE=1" >> .env; \
		echo "HF_HUB_OFFLINE=1" >> .env; \
		echo "KHOJ_DISABLE_EMBEDDINGS=true" >> .env; \
		echo "KHOJ_DISABLE_MODELS=true" >> .env; \
		echo "KHOJ_SKIP_ADMIN_INIT=true" >> .env; \
	else \
		# Ensure all required variables are present \
		echo "$(YELLOW)Checking for required environment variables...$(RESET)"; \
		for VAR in POSTGRES_PASSWORD POSTGRES_USER POSTGRES_DB POSTGRES_HOST POSTGRES_PORT KHOJ_ANONYMOUS_MODE KHOJ_DISABLE_EMBEDDINGS KHOJ_DISABLE_MODELS KHOJ_SKIP_ADMIN_INIT; do \
			if ! grep -q "$$VAR" .env; then \
				case $$VAR in \
					POSTGRES_PASSWORD) echo "$$VAR=postgres" >> .env ;; \
					POSTGRES_USER) echo "$$VAR=postgres" >> .env ;; \
					POSTGRES_DB) echo "$$VAR=khoj" >> .env ;; \
					POSTGRES_HOST) echo "$$VAR=localhost" >> .env ;; \
					POSTGRES_PORT) echo "$$VAR=5432" >> .env ;; \
					KHOJ_ANONYMOUS_MODE) echo "$$VAR=true" >> .env ;; \
					KHOJ_DISABLE_EMBEDDINGS) echo "$$VAR=true" >> .env ;; \
					KHOJ_DISABLE_MODELS) echo "$$VAR=true" >> .env ;; \
					KHOJ_SKIP_ADMIN_INIT) echo "$$VAR=true" >> .env ;; \
				esac; \
				echo "$(YELLOW)Added missing variable: $$VAR$(RESET)"; \
			fi; \
		done; \
	fi
	
	@echo "$(CYAN)Step 2: Setting up PostgreSQL and database...$(RESET)"
	@$(MAKE) verify-db-access || $(MAKE) setup-db
	
	@echo "$(CYAN)Step 3: Checking for user configuration...$(RESET)"
	@# Make sure environment variables are set for offline mode
	@if ! grep -q "TRANSFORMERS_OFFLINE" .env; then \
		echo "$(YELLOW)Adding offline mode settings to .env...$(RESET)"; \
		echo "TRANSFORMERS_OFFLINE=1" >> .env; \
		echo "HF_HUB_OFFLINE=1" >> .env; \
	fi
	
	@# Check if admin setup should be skipped
	@if grep -q "KHOJ_SKIP_ADMIN_INIT=true" .env; then \
		echo "$(GREEN)Skipping admin setup as KHOJ_SKIP_ADMIN_INIT is set to true.$(RESET)"; \
	elif grep -q "KHOJ_ADMIN_EMAIL" .env && grep -q "KHOJ_ADMIN_PASSWORD" .env; then \
		EMAIL=$$(grep KHOJ_ADMIN_EMAIL .env | cut -d '=' -f2); \
		PASS=$$(grep KHOJ_ADMIN_PASSWORD .env | cut -d '=' -f2); \
		if [ "$$EMAIL" = "admin@example.com" ] && [ "$$PASS" = "adminpassword" ]; then \
			echo "$(YELLOW)Default admin user detected. Interactive setup recommended.$(RESET)"; \
			read -p "Do you want to set up a custom admin user and API key? (y/n) " answer; \
			if [ "$$answer" = "y" ]; then \
				$(MAKE) run-interactive; \
				echo "$(GREEN)Configuration completed. Starting servers...$(RESET)"; \
			else \
				echo "$(YELLOW)Keeping default admin credentials.$(RESET)"; \
				echo "KHOJ_SKIP_ADMIN_INIT=true" >> .env; \
			fi; \
		else \
			echo "$(GREEN)Admin user already configured.$(RESET)"; \
		fi; \
	else \
		echo "$(YELLOW)Admin user not configured. Running setup...$(RESET)"; \
		$(MAKE) run-interactive; \
		echo "$(GREEN)Configuration completed. Starting servers...$(RESET)"; \
	fi
	
	@echo "$(CYAN)Step 4: Starting servers and monitoring...$(RESET)"
	@$(MAKE) run-servers

run-interactive:
	@echo "$(CYAN)Initializing Khoj backend interactively...$(RESET)"
	@echo "$(YELLOW)This will guide you through setting up an administrator account and API keys.$(RESET)"
	@echo "$(YELLOW)--------------------------------------------------$(RESET)"
	@echo "$(INFO_BADGE) After configuration is complete, please stop the server with Ctrl+C"
	@echo "$(INFO_BADGE) You'll then be returned to the automated setup process."
	@echo "$(YELLOW)--------------------------------------------------$(RESET)"
	@echo ""
	@read -p "Press Enter to continue to the interactive setup..." dummy
	@if ! grep -q "KHOJ_ANONYMOUS_MODE" .env; then \
		echo "KHOJ_ANONYMOUS_MODE=true" >> .env; \
	fi
	@# Ensure offline mode is properly set with KHOJ_DISABLE_EMBEDDINGS to prevent HF download attempts
	@if ! grep -q "KHOJ_DISABLE_EMBEDDINGS" .env; then \
		echo "KHOJ_DISABLE_EMBEDDINGS=true" >> .env; \
	fi
	@# Add trap to handle Ctrl+C gracefully
	@( \
		trap 'echo "$(YELLOW)Interactive setup interrupted. Proceeding to next step.$(RESET)"; exit 0' INT; \
		. .venv/bin/activate && \
		export $$(grep -v '^#' .env | xargs) && \
		export TRANSFORMERS_OFFLINE=1 && \
		export HF_HUB_OFFLINE=1 && \
		export KHOJ_DISABLE_EMBEDDINGS=true && \
		export KHOJ_DISABLE_MODELS=true && \
		export SENTENCE_TRANSFORMERS_HOME=/tmp/non-existent-dir && \
		export HF_HOME=/tmp/non-existent-dir && \
		python -m khoj.main --anonymous-mode; \
	)
	@# Add KHOJ_SKIP_ADMIN_INIT=true to .env after interactive setup
	@echo "$(YELLOW)Setting KHOJ_SKIP_ADMIN_INIT=true to avoid future interactive setup...$(RESET)"
	@if ! grep -q "KHOJ_SKIP_ADMIN_INIT" .env; then \
		echo "KHOJ_SKIP_ADMIN_INIT=true" >> .env; \
	else \
		sed -i 's/KHOJ_SKIP_ADMIN_INIT=.*/KHOJ_SKIP_ADMIN_INIT=true/' .env; \
	fi

# Open the .env file for editing
edit-env:
	@if [ ! -f "$(PROJECT_DIR)/.env" ]; then \
		echo "$(YELLOW)No .env file found. Creating one with default values...$(RESET)"; \
		echo "POSTGRES_PASSWORD=$(DB_PASS)" > $(PROJECT_DIR)/.env; \
		echo "POSTGRES_USER=$(DB_USER)" >> $(PROJECT_DIR)/.env; \
		echo "POSTGRES_DB=$(DB_NAME)" >> $(PROJECT_DIR)/.env; \
		echo "POSTGRES_HOST=$(DB_HOST)" >> $(PROJECT_DIR)/.env; \
		echo "POSTGRES_PORT=$(DB_PORT)" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_ANONYMOUS_MODE=true" >> $(PROJECT_DIR)/.env; \
		echo "DEFAULT_MODEL=$(DEFAULT_MODEL)" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_ADMIN_EMAIL=admin@example.com" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_ADMIN_PASSWORD=adminpassword" >> $(PROJECT_DIR)/.env; \
		echo "KHOJ_SKIP_ADMIN_INIT=true" >> $(PROJECT_DIR)/.env; \
		echo "TRANSFORMERS_OFFLINE=1" >> $(PROJECT_DIR)/.env; \
		echo "HF_HUB_OFFLINE=1" >> $(PROJECT_DIR)/.env; \
	fi
	@echo "$(CYAN)Opening .env file for editing...$(RESET)"
	@$${EDITOR:-vi} $(PROJECT_DIR)/.env

# Stop all running servers from run-dev
stop-servers:
	@echo "$(CYAN)Stopping Khoj servers...$(RESET)"
	@pkill -f "python -m khoj.main" 2>/dev/null || echo "$(YELLOW)No backend server running$(RESET)"
	@pkill -f "next dev" 2>/dev/null || echo "$(YELLOW)No frontend server running$(RESET)"
	@echo "$(GREEN)All servers stopped.$(RESET)"

# Cleanup
clean: 
	@echo "$(CYAN)Cleaning temporary files...$(RESET)"
	@-$(MAKE) stop-servers
	@echo "$(YELLOW)Removing build files...$(RESET)"
	@-rm -rf $(WEB_DIR)/out
	@-rm -rf $(WEB_DIR)/.next
	@-rm -rf $(WEB_DIR)/node_modules/.cache
	@-rm -rf $(TMP_DIR)
	@echo "$(GREEN)Cleanup completed.$(RESET)"

# Run with colors
run-dev-color:
	@$(MAKE) COLOR_SUPPORT=1 run-dev 

# Stop development server
stop-dev:
	@echo "$(YELLOW)Stopping development servers...$(RESET)"
	@$(MAKE) stop-servers
	@echo "$(GREEN)All development servers stopped.$(RESET)"

check-env:
	@echo "$(CYAN)Checking dependencies...$(RESET)"
	@# Check if .env file exists and create it if it doesn't
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creating .env file with default settings...$(RESET)"; \
		echo "POSTGRES_PASSWORD=postgres" > .env; \
		echo "POSTGRES_USER=postgres" >> .env; \
		echo "POSTGRES_DB=khoj" >> .env; \
		echo "POSTGRES_HOST=localhost" >> .env; \
		echo "POSTGRES_PORT=5432" >> .env; \
		echo "KHOJ_ANONYMOUS_MODE=true" >> .env; \
		echo "DEFAULT_MODEL=gpt-4o-mini" >> .env; \
		echo "KHOJ_ADMIN_EMAIL=admin@example.com" >> .env; \
		echo "KHOJ_ADMIN_PASSWORD=adminpassword" >> .env; \
		echo "KHOJ_SKIP_ADMIN_INIT=true" >> .env; \
		echo "TRANSFORMERS_OFFLINE=1" >> .env; \
		echo "HF_HUB_OFFLINE=1" >> .env; \
		echo "KHOJ_DISABLE_EMBEDDINGS=true" >> .env; \
		echo "KHOJ_DISABLE_MODELS=true" >> .env; \
	fi
	@$(MAKE) check-deps 

# Monitor servers with status updates every 5 seconds
monitor-servers:
	@echo "$(CYAN)Monitoring servers. Press Ctrl+C to stop...$(RESET)"
	@mkdir -p $(TMP_DIR)/logs
	@while true; do \
		clear; \
		echo "$(CYAN)===== Khoj Server Status [$(shell date '+%H:%M:%S')] =====$(RESET)"; \
		echo ""; \
		# Check backend status \
		if curl -s http://localhost:42110/api/health > /dev/null 2>&1; then \
			echo "$(GREEN)Backend server:$(RESET) Running $(GREEN)✓$(RESET) [http://localhost:42110]"; \
		else \
			# Check for specific errors in the backend log \
			if [ -f "$(TMP_DIR)/logs/backend.log" ] && grep -q "ERROR" "$(TMP_DIR)/logs/backend.log"; then \
				LAST_ERROR=$$(grep -a "ERROR" "$(TMP_DIR)/logs/backend.log" | tail -1); \
				echo "$(RED)Backend server:$(RESET) Error detected $(RED)✗$(RESET)"; \
				echo "$(YELLOW)Last error:$(RESET) $${LAST_ERROR:0:80}..."; \
			else \
				echo "$(RED)Backend server:$(RESET) Not running $(RED)✗$(RESET)"; \
			fi; \
		fi; \
		# Check frontend status \
		if curl -s http://localhost:3000 > /dev/null 2>&1; then \
			echo "$(GREEN)Frontend server:$(RESET) Running $(GREEN)✓$(RESET) [http://localhost:3000]"; \
		else \
			if curl -s http://localhost:3001 > /dev/null 2>&1; then \
				echo "$(GREEN)Frontend server:$(RESET) Running $(GREEN)✓$(RESET) [http://localhost:3001]"; \
			elif curl -s http://localhost:3002 > /dev/null 2>&1; then \
				echo "$(GREEN)Frontend server:$(RESET) Running $(GREEN)✓$(RESET) [http://localhost:3002]"; \
			else \
				# Check for specific errors in the frontend log \
				if [ -f "$(TMP_DIR)/logs/frontend.log" ] && grep -q "ERROR" "$(TMP_DIR)/logs/frontend.log"; then \
					LAST_ERROR=$$(grep -a "ERROR" "$(TMP_DIR)/logs/frontend.log" | tail -1); \
					echo "$(RED)Frontend server:$(RESET) Error detected $(RED)✗$(RESET)"; \
					echo "$(YELLOW)Last error:$(RESET) $${LAST_ERROR:0:80}..."; \
				else \
					echo "$(RED)Frontend server:$(RESET) Not running $(RED)✗$(RESET)"; \
				fi; \
			fi; \
		fi; \
		echo ""; \
		echo "$(CYAN)Commands:$(RESET)"; \
		echo "  $(YELLOW)make logs-backend$(RESET)  - View backend logs"; \
		echo "  $(YELLOW)make logs-frontend$(RESET) - View frontend logs"; \
		echo "  $(YELLOW)make stop-servers$(RESET)  - Stop all servers"; \
		echo ""; \
		sleep 5; \
	done 