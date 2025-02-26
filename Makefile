# Makefile for Khoj - Development and Installation
# ==================================================

# Variables
VENV_DIR := .venv
PYTHON := python3
PIP := $(VENV_DIR)/bin/pip
KHOJ := $(VENV_DIR)/bin/khoj
PROJECT_DIR := $(shell pwd)
WEB_DIR := $(PROJECT_DIR)/src/interface/web

# Colors for messages
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Main targets
.PHONY: all install setup-db build-frontend run-backend run-frontend-dev dev clean help

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
	@echo "  $(YELLOW)make clean$(RESET)            - Clean temporary files"
	@echo ""
	@echo "$(CYAN)Typical workflow:$(RESET)"
	@echo "  1. make install"
	@echo "  2. make setup-db"
	@echo "  3. make dev"

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

# Cleanup
clean:
	@echo "$(CYAN)Cleaning temporary files...$(RESET)"
	@echo "$(YELLOW)Stopping Khoj processes...$(RESET)"
	@-pkill -f khoj || true
	@echo "$(YELLOW)Removing build files...$(RESET)"
	@-rm -rf $(WEB_DIR)/out
	@-rm -rf $(WEB_DIR)/.next
	@-rm -rf $(WEB_DIR)/node_modules/.cache
	@echo "$(GREEN)Cleanup completed.$(RESET)" 