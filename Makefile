# Cross-platform Makefile: Linux/macOS/WSL/Git Bash/Windows (cmd.exe)

# ---------------- Shell selection ----------------
# On Windows, use cmd so GNU Make doesn't look for sh.exe.
# We still run .sh scripts via "bash <script>" explicitly.
ifeq ($(OS),Windows_NT)
  SHELL := cmd
  .SHELLFLAGS := /C
  BASH := bash
  # Check for bash (Git for Windows provides it). This prints a friendly error if missing.
  CHECK_BASH := where bash >NUL 2>NUL || (echo Bash not found. Install Git for Windows and ensure "bash" is in PATH. & exit 1)
else
  SHELL := /bin/bash
  .SHELLFLAGS := -c
  BASH := bash
  CHECK_BASH := command -v bash >/dev/null 2>&1 || { echo "bash not found in PATH"; exit 1; }
endif

# ---------------- Script paths ----------------
INSTALL_SCRIPT := scripts/install.sh
START_SCRIPT   := scripts/start.sh
RUN_SCRIPT     := scripts/run.sh
STOP_SCRIPT    := scripts/stop.sh
PURGE_SCRIPT   := scripts/purge.sh
EXPORT_SCRIPT  := scripts/export.sh

# ---------------- Icons (emoji on Unix, ASCII on Windows) ----------------
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
	@$(CHECK_BASH)
	@$(BASH) "$(INSTALL_SCRIPT)"
	@echo Done: Installation finished.

start:
	@echo $(ICON_START) Starting the watsonx Orchestrate server...
	@$(CHECK_BASH)
	@$(BASH) "$(START_SCRIPT)"

run:
	@echo $(ICON_RUN) Running the application setup (importing agents and tools)...
	@$(CHECK_BASH)
	@$(BASH) "$(RUN_SCRIPT)"

stop:
	@echo $(ICON_STOP) Stopping the server and any related containers...
	@$(CHECK_BASH)
	@$(BASH) "$(STOP_SCRIPT)"

purge:
	@echo $(ICON_PURGE) Purging the environment (stopping and removing all containers and images)...
	@$(CHECK_BASH)
	@$(BASH) "$(PURGE_SCRIPT)"

# Export/import to cloud using scripts/export.sh (reads WO_INSTANCE/WO_API_KEY from .env).
export:
	@echo $(ICON_EXPORT) Exporting/importing assets to your cloud environment using .env...
	@$(CHECK_BASH)
	@$(BASH) "$(EXPORT_SCRIPT)"
	@echo Done: Cloud export completed.

# Default target
.DEFAULT_GOAL := help
