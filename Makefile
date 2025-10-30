# Use bash as the default shell for all recipes (Git Bash/WSL/macOS/Linux).
SHELL := /bin/bash

# Script paths
INSTALL_SCRIPT := scripts/install.sh
START_SCRIPT   := scripts/start.sh
RUN_SCRIPT     := scripts/run.sh
STOP_SCRIPT    := scripts/stop.sh
PURGE_SCRIPT   := scripts/purge.sh
EXPORT_SCRIPT  := scripts/export.sh

# ------------------------------------------------------------------------------
# Icon set (emoji on Unix, ASCII on Windows to avoid mojibake).
# Force ASCII at any time via: make help USE_ICONS=0
# ------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
  USE_ICONS ?= 0
else
  USE_ICONS ?= 1
endif

ifeq ($(USE_ICONS),1)
  ICON_INSTALL := ⚙️
  ICON_START   := 🚀
  ICON_RUN     := 🏃
  ICON_STOP    := 🛑
  ICON_PURGE   := 🔥
  ICON_EXPORT  := ☁️
  ICON_HELP    := ℹ️
else
  ICON_INSTALL := [*]
  ICON_START   := [>]
  ICON_RUN     := [-]
  ICON_STOP    := [X]
  ICON_PURGE   := [!]
  ICON_EXPORT  := [^]
  ICON_HELP    := [i]
endif

# ==============================================================================
# HELP
# ==============================================================================
.PHONY: help
help:
	@echo Available commands:
	@echo ---------------------------------------------
	@echo   make install  - $(ICON_INSTALL) Installs the environment by running all setup scripts.
	@echo   make start    - $(ICON_START) Loads the watsonx Orchestrate server.
	@echo   make run      - $(ICON_RUN) Imports agents/tools and starts the application.
	@echo   make stop     - $(ICON_STOP) Stops the watsonx Orchestrate server and related containers.
	@echo   make purge    - $(ICON_PURGE) Stops and removes all containers and Docker images.
	@echo   make export   - $(ICON_EXPORT) Pushes tools/KBs/agents to your cloud env using values from .env.
	@echo   make help     - $(ICON_HELP) Shows this help message.

# ==============================================================================
# MAIN TARGETS
# ==============================================================================
.PHONY: install start run stop purge export

install:
	@echo $(ICON_START) Starting environment installation...
	@$(SHELL) $(INSTALL_SCRIPT)
	@echo Done: Installation finished.

start:
	@echo $(ICON_START) Starting the watsonx Orchestrate server...
	@$(SHELL) $(START_SCRIPT)

run:
	@echo $(ICON_RUN) Running the application setup \(importing agents and tools\)...
	@$(SHELL) $(RUN_SCRIPT)

stop:
	@echo $(ICON_STOP) Stopping the server and any related containers...
	@$(SHELL) $(STOP_SCRIPT)

purge:
	@echo $(ICON_PURGE) Purging the environment \(stopping and removing all containers and images\)...
	@$(SHELL) $(PURGE_SCRIPT)

# Export/import to cloud using scripts/export.sh (reads WO_INSTANCE/WO_API_KEY from .env).
export:
	@echo $(ICON_EXPORT) Exporting/importing assets to your cloud environment using .env...
	@if [ ! -f ".env" ]; then \
		echo ".env not found in project root. Please fill Option 2 (WO_INSTANCE / WO_API_KEY)."; \
		exit 1; \
	fi
	@if [ ! -x "$(EXPORT_SCRIPT)" ]; then \
		echo "Making $(EXPORT_SCRIPT) executable..."; \
		chmod +x "$(EXPORT_SCRIPT)"; \
	fi
	@$(SHELL) $(EXPORT_SCRIPT)
	@echo Done: Cloud export completed.

# Default target
.DEFAULT_GOAL := help
