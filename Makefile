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
# Icon set (emoji on Unix, safe ASCII on Windows to avoid mojibake *and* '>' redirection).
# You can force ASCII any time: make help USE_ICONS=0
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
  ICON_INSTALL := [install]
  ICON_START   := [start]
  ICON_RUN     := [run]
  ICON_STOP    := [stop]
  ICON_PURGE   := [purge]
  ICON_EXPORT  := [export]
  ICON_HELP    := [help]
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
	@echo $(ICON_RUN) Running the application setup (importing agents and tools)...
	@$(SHELL) $(RUN_SCRIPT)

stop:
	@echo $(ICON_STOP) Stopping the server and any related containers...
	@$(SHELL) $(STOP_SCRIPT)

purge:
	@echo $(ICON_PURGE) Purging the environment (stopping and removing all containers and images)...
	@$(SHELL) $(PURGE_SCRIPT)

# Export/import to cloud using scripts/export.sh (reads WO_INSTANCE/WO_API_KEY from .env).
export:
	@echo $(ICON_EXPORT) Exporting/importing assets to your cloud environment using .env...
	@$(SHELL) $(EXPORT_SCRIPT)
	@echo Done: Cloud export completed.

# Default target
.DEFAULT_GOAL := help
