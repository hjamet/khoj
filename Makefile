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
SHELL := /bin/bash

# Disable colors by default
COLOR_SUPPORT ?= 0
ifeq ($(COLOR_SUPPORT),1)
	# Colors for messages
	CYAN := \033[36m
	GREEN := \033[32m
	YELLOW := \033[33m
	RED := \033[31m
	BLUE := \033[34m
	MAGENTA := \033[35m
	BOLD := \033[1m
	DIM := \033[2m
	RESET := \033[0m
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

OK_BADGE := $(BOLD)$(GREEN)[OK]$(RESET)
ERROR_BADGE := $(BOLD)$(RED)[ERROR]$(RESET)
LOADING_BADGE := $(BOLD)$(YELLOW)[LOADING]$(RESET)
IDLE_BADGE := $(BOLD)$(BLUE)[IDLE]$(RESET)

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
.PHONY: all install setup-db build-frontend run-backend run-frontend-dev dev run-dev run-dev-color check-deps logs-backend logs-frontend stop-servers clean help

all: help

help:
	@echo "$(CYAN)Makefile for Khoj Development$(RESET)"
	@echo "----------------------------------------"
	@echo "$(GREEN)Available commands:$(RESET)"
	@echo "  $(YELLOW)make install$(RESET)          - Install Khoj and all dependencies"
	@echo "  $(YELLOW)make setup-db$(RESET)         - Configure PostgreSQL database"
	@echo "  $(YELLOW)make build-frontend$(RESET)   - Build frontend assets"
	@echo "  $(YELLOW)make run-backend$(RESET)      - Run Khoj backend server in anonymous mode"
	@echo "  $(YELLOW)make run-frontend-dev$(RESET) - Run frontend development server"
	@echo "  $(YELLOW)make dev$(RESET)              - Instructions for complete development setup"
	@echo "  $(YELLOW)make run-dev$(RESET)          - Launch and monitor backend and frontend servers (no colors)"
	@echo "  $(YELLOW)make run-dev-color$(RESET)    - Launch and monitor servers with colored output"
	@echo "  $(YELLOW)make logs-backend$(RESET)     - View backend server logs in real-time"
	@echo "  $(YELLOW)make logs-frontend$(RESET)    - View frontend server logs in real-time"
	@echo "  $(YELLOW)make stop-servers$(RESET)     - Stop all running development servers"
	@echo "  $(YELLOW)make clean$(RESET)            - Clean temporary files and stop servers"
	@echo ""
	@echo "$(CYAN)Typical workflow:$(RESET)"
	@echo "  1. make install"
	@echo "  2. make setup-db"
	@echo "  3. make run-dev"

# Complete installation
install: create-venv install-backend install-frontend

# Create virtual environment
create-venv:
	@echo "$(CYAN)Creating virtual environment...$(RESET)"
	@$(PYTHON) -m venv $(VENV_DIR) || (echo "$(RED)Error creating virtual environment$(RESET)" && exit 1)
	@echo "$(GREEN)Virtual environment created successfully.$(RESET)"

# Install backend
install-backend: create-venv
	@echo "$(CYAN)Installing backend dependencies...$(RESET)"
	@. $(VENV_DIR)/bin/activate && pip install -e '.[dev]' || (echo "$(RED)Error installing backend dependencies$(RESET)" && exit 1)
	@echo "$(GREEN)Backend installed successfully.$(RESET)"

# Install frontend dependencies
install-frontend:
	@echo "$(CYAN)Installing frontend dependencies...$(RESET)"
	@cd $(WEB_DIR) && yarn install || (echo "$(RED)Error installing frontend dependencies$(RESET)" && exit 1)
	@echo "$(GREEN)Frontend dependencies installed successfully.$(RESET)"

# Database configuration
setup-db:
	@echo "$(CYAN)Configuring PostgreSQL database...$(RESET)"
	@echo "$(YELLOW)Starting PostgreSQL...$(RESET)"
	@sudo service postgresql start || (echo "$(RED)Error starting PostgreSQL$(RESET)" && exit 1)
	@echo "$(YELLOW)Creating khoj database...$(RESET)"
	@sudo -u postgres createdb khoj 2>/dev/null || echo "$(YELLOW)khoj database already exists.$(RESET)"
	@echo "$(GREEN)Database configured successfully.$(RESET)"

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
	@echo "$(YELLOW)Server will be accessible at http://localhost:3000$(RESET)"
	@cd $(WEB_DIR) && yarn dev

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
	@echo "- Development frontend will be accessible at http://localhost:3000"
	@echo "- Streaming doesn't work on the frontend development server"
	@echo "- To test with all integrated components, use only 'make run-backend'"
	@echo ""
	@echo "$(YELLOW)For automatic setup with live monitoring, run:$(RESET)"
	@echo "  make run-dev"

# Check dependencies
check-deps:
	@echo "$(CYAN)Checking dependencies...$(RESET)"
	@# Create temporary directory
	@mkdir -p $(TMP_DIR)
	@# Check virtual environment
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "$(RED)Virtual environment not found. Running installation...$(RESET)"; \
		$(MAKE) install; \
	fi
	@# Check PostgreSQL
	@if ! sudo service postgresql status >/dev/null 2>&1; then \
		echo "$(YELLOW)PostgreSQL is not running. Starting PostgreSQL...$(RESET)"; \
		$(MAKE) setup-db; \
	fi
	@# Check frontend dependencies
	@if [ ! -d "$(WEB_DIR)/node_modules" ]; then \
		echo "$(RED)Frontend dependencies not installed. Installing...$(RESET)"; \
		$(MAKE) install-frontend; \
	fi
	@echo "$(GREEN)All dependencies are properly installed.$(RESET)"

# Open browser when servers are ready
open-browser:
	@echo "$(CYAN)Opening browser...$(RESET)"
	@$(OPEN_BROWSER) http://localhost:3000 >/dev/null 2>&1 || true

# Open logs in separate terminals
open-logs-backend:
	@echo "$(CYAN)Opening backend logs in a new terminal...$(RESET)"
	@$(OPEN_TERMINAL) "cd $(PROJECT_DIR) && make logs-backend" >/dev/null 2>&1 &

open-logs-frontend:
	@echo "$(CYAN)Opening frontend logs in a new terminal...$(RESET)"
	@$(OPEN_TERMINAL) "cd $(PROJECT_DIR) && make logs-frontend" >/dev/null 2>&1 &

# Run both servers with live monitoring
run-dev: check-deps
	@echo "$(CYAN)$(BOLD)╔════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)$(BOLD)║     KHOJ DEVELOPMENT ENVIRONMENT       ║$(RESET)"
	@echo "$(CYAN)$(BOLD)╚════════════════════════════════════════╝$(RESET)"
	@echo ""
	@# First clean up any existing servers
	@-$(MAKE) stop-servers >/dev/null 2>&1
	@# Create temporary directory for logs and PIDs
	@mkdir -p $(TMP_DIR)/logs
	@# Start the backend server in background
	@echo "$(CYAN)Starting backend server...$(RESET)"
	@. $(VENV_DIR)/bin/activate && khoj -vv --anonymous-mode > $(TMP_DIR)/logs/backend.log 2>&1 & echo $$! > $(TMP_DIR)/backend.pid
	@echo ""
	
	@# Simplified waiting for backend initialization (with pauses between each step)
	@echo "$(YELLOW)Waiting for backend to initialize...$(RESET)"
	@count=0; \
	while [ ! -s $(TMP_DIR)/logs/backend.log ] && [ $$count -lt 30 ]; do \
		sleep 1; \
		count=$$((count+1)); \
		if [ $$((count % 3)) -eq 0 ]; then \
			echo "$(YELLOW)Still waiting for backend ($$count seconds)...$(RESET)"; \
		fi; \
	done
	@echo "$(GREEN)Backend started successfully.$(RESET)"
	
	@# Start the frontend server in background only after backend is ready
	@echo "$(CYAN)Starting frontend development server...$(RESET)"
	@cd $(WEB_DIR) && yarn dev > $(TMP_DIR)/logs/frontend.log 2>&1 & echo $$! > $(TMP_DIR)/frontend.pid
	@echo ""
	
	@# No animation, just a time counter for frontend initialization
	@echo "$(YELLOW)Waiting for frontend to start (this may take up to 30 seconds)...$(RESET)"
	@count=0; \
	while [ $$count -lt 15 ]; do \
		sleep 2; \
		count=$$((count+1)); \
		if [ $$((count % 5)) -eq 0 ]; then \
			echo "$(YELLOW)Still waiting for frontend ($$((count*2)) seconds)...$(RESET)"; \
		fi; \
	done
	@echo "$(GREEN)Frontend started successfully.$(RESET)"
	
	@echo ""
	@echo "$(CYAN)$(BOLD)╔════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)$(BOLD)║     KHOJ DEVELOPMENT ENVIRONMENT       ║$(RESET)"
	@echo "$(CYAN)$(BOLD)╚════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(GREEN)$(BOLD)✅ Development environment is running!$(RESET)"
	@echo ""
	@echo "$(MAGENTA)$(BOLD)Server URLs (access in your browser):$(RESET)"
	@echo "  $(DIM)• Backend API: http://127.0.0.1:42110$(RESET)"
	@echo "  $(DIM)• Frontend UI: http://localhost:3000$(RESET)"
	@echo ""
	@# Single static status display
	@timestamp=$$(date +"%H:%M:%S")
	@echo "$(CYAN)$(BOLD)╔════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)$(BOLD)║     KHOJ SERVERS STATUS MONITOR        ║$(RESET)"
	@echo "$(CYAN)$(BOLD)╚════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(YELLOW)Status as of: $$timestamp$(RESET)"
	@echo ""
	@echo "$(BOLD)BACKEND SERVER:$(RESET)"
	@if pgrep -f "khoj -vv" > /dev/null; then \
		echo "$(GREEN)$(BOLD)[RUNNING]$(RESET) Backend server is active"; \
		if [ -s $(TMP_DIR)/logs/backend.log ]; then \
			echo "$(BOLD)Latest logs:$(RESET)"; \
			tail -n 3 $(TMP_DIR)/logs/backend.log | sed 's/^/  /'; \
		else \
			echo "$(YELLOW)No logs yet.$(RESET)"; \
		fi; \
	else \
		echo "$(RED)$(BOLD)[STOPPED]$(RESET) Backend server is not running"; \
	fi
	@echo ""
	@echo "$(BOLD)FRONTEND SERVER:$(RESET)"
	@if pgrep -f "yarn dev" > /dev/null; then \
		echo "$(GREEN)$(BOLD)[RUNNING]$(RESET) Frontend server is active"; \
		if [ -s $(TMP_DIR)/logs/frontend.log ]; then \
			echo "$(BOLD)Latest logs:$(RESET)"; \
			tail -n 3 $(TMP_DIR)/logs/frontend.log | sed 's/^/  /'; \
		else \
			echo "$(YELLOW)No logs yet.$(RESET)"; \
		fi; \
	else \
		echo "$(RED)$(BOLD)[STOPPED]$(RESET) Frontend server is not running"; \
	fi
	@echo ""
	@echo "$(MAGENTA)$(BOLD)Commands to use in separate terminals:$(RESET)"
	@echo "  $(DIM)• To view backend logs:$(RESET) $(BOLD)make logs-backend$(RESET)"
	@echo "  $(DIM)• To view frontend logs:$(RESET) $(BOLD)make logs-frontend$(RESET)"
	@echo "  $(DIM)• To stop all servers:$(RESET) $(BOLD)make stop-servers$(RESET)"
	@echo ""
	@echo "$(GREEN)Servers are running in the background. Press Ctrl+C to exit this view.$(RESET)"
	@# Keep the terminal open without updates until user presses Ctrl+C
	@sleep infinity || exit 0

# Stop all running servers from run-dev
stop-servers:
	@echo "$(YELLOW)Stopping Khoj development servers...$(RESET)"
	@-if [ -f $(TMP_DIR)/backend.pid ]; then \
		kill $$(cat $(TMP_DIR)/backend.pid) 2>/dev/null || true; \
		rm -f $(TMP_DIR)/backend.pid; \
		echo "$(GREEN)Backend server stopped.$(RESET)"; \
	else \
		echo "$(YELLOW)No backend PID file found.$(RESET)"; \
	fi
	@-if [ -f $(TMP_DIR)/frontend.pid ]; then \
		kill -9 $$(cat $(TMP_DIR)/frontend.pid) 2>/dev/null || true; \
		rm -f $(TMP_DIR)/frontend.pid; \
		echo "$(GREEN)Frontend server stopped.$(RESET)"; \
	else \
		echo "$(YELLOW)No frontend PID file found.$(RESET)"; \
	fi
	@-pkill -f "yarn dev" 2>/dev/null || true
	@-pkill -f "khoj -vv" 2>/dev/null || true
	@-pkill -f "node.*$(WEB_DIR)" 2>/dev/null || true
	@echo "$(GREEN)All development servers stopped.$(RESET)"

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