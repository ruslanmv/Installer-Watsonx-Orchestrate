# Use bash as the default shell for all recipes.
SHELL := /bin/bash
# Define the locations of the scripts.
INSTALL_SCRIPT := scripts/install.sh
START_SCRIPT   := scripts/start.sh
RUN_SCRIPT     := scripts/run.sh
STOP_SCRIPT    := scripts/stop.sh
PURGE_SCRIPT   := scripts/purge.sh

# ==============================================================================
# HELP
# This target provides a self-documenting way to see available commands.
# ==============================================================================
.PHONY: help
help:
	@echo "Available commands:"
	@echo ""
	@echo "  make install   - ⚙️  Installs the environment by running all setup scripts."
	@echo "  make start     - 🚀 Loads the watsonx Orchestrate server."
	@echo "  make run       - 🏃 Imports agents/tools and starts the application."
	@echo "  make stop      - 🛑 Stops the watsonx Orchestrate server and related containers."
	@echo "  make purge     - 🔥 Stops and removes all containers and Docker images."
	@echo "  make help      - ℹ️  Shows this help message."
	@echo ""

# ==============================================================================
# MAIN TARGETS
# ==============================================================================

# Declare all targets that are not files as .PHONY.
.PHONY: install start run stop purge

# Installs the complete environment.
install:
	@echo "🚀 Starting environment installation..."
	@$(SHELL) $(INSTALL_SCRIPT)
	@echo "✅ Makefile: Installation finished."

# Starts the watsonx Orchestrate server.
start:
	@echo "🚀 Starting the watsonx Orchestrate server..."
	@$(SHELL) $(START_SCRIPT)

# Runs the application logic (imports agents/tools).
run:
	@echo "🏃 Running the application setup (importing agents and tools)..."
	@$(SHELL) $(RUN_SCRIPT)

# Stops the watsonx Orchestrate server and related containers.
stop:
	@echo "🛑 Stopping the server and any related containers..."
	@$(SHEE) $(STOP_SCRIPT)

# Purges the environment by removing all containers and Docker images.
purge:
	@echo "🔥 Purging the environment (stopping and removing all containers and images)..."
	@$(SHELL) $(PURGE_SCRIPT)

# A default target to run when you just type `make`.
.DEFAULT_GOAL := help