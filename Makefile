# Cross-platform Makefile: Linux/macOS/WSL/Git Bash/MSYS2/Cygwin/Windows (cmd.exe)

# ---------------- Shell selection ----------------
ifeq ($(OS),Windows_NT)
  SHELL := $(ComSpec)
  .SHELLFLAGS := /C

  # --- Prefer real Git Bash; never fall back to WSL's System32\bash.exe ---
  BASH_CANDIDATE := $(shell if exist "%ProgramFiles%\Git\bin\bash.exe" echo %ProgramFiles%\Git\bin\bash.exe)
  ifeq ($(strip $(BASH_CANDIDATE)),)
    BASH_CANDIDATE := $(shell if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" echo %ProgramFiles(x86)%\Git\bin\bash.exe)
  endif
  ifeq ($(strip $(BASH_CANDIDATE)),)
    BASH_CANDIDATE := $(shell if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" echo %LOCALAPPDATA%\Programs\Git\bin\bash.exe)
  endif
  ifneq ($(strip $(BASH_CANDIDATE)),)
    BASH := $(BASH_CANDIDATE)
  else
    BASH_WHERE := $(shell where bash 2>NUL)
    ifneq (,$(filter %\Git\bin\bash.exe %\Git\usr\bin\bash.exe,$(BASH_WHERE)))
      BASH := $(firstword $(filter %\Git\bin\bash.exe %\Git\usr\bin\bash.exe,$(BASH_WHERE)))
    else
      # Don't default to plain "bash" on Windows; it might be WSL. We’ll still set BASH so other targets can use it if present,
      # but install target below *never* uses bash now.
      BASH := bash
    endif
  endif

  CHECK_BASH := "$(BASH)" --version >NUL 2>NUL || (echo Git Bash not found. Install Git for Windows and ensure bash is in PATH. & exit 1)

  PLATFORM := Windows
  ifdef MSYSTEM
    PLATFORM_FLAVOR := Git Bash / MSYS2 ($(MSYSTEM))
    PLATFORM_HINT := Use Git Bash. Recipes run via cmd.exe; scripts run with bash.
  else
    PLATFORM_FLAVOR := cmd.exe / PowerShell
    PLATFORM_HINT := Use Command Prompt or PowerShell. Scripts run with bash from Git for Windows.
  endif

  ECHOBLANK := echo.
else
  SHELL := /usr/bin/env bash
  .SHELLFLAGS := -e -o pipefail -c
  BASH := bash
  CHECK_BASH := command -v bash >/dev/null 2>&1 || { echo "bash not found in PATH"; exit 1; }

  UNAME_S := $(shell uname -s 2>/dev/null || echo Unknown)
  UNAME_R := $(shell uname -r 2>/dev/null || echo Unknown)

  ifneq (,$(findstring Microsoft,$(UNAME_R)))
    PLATFORM := WSL (Windows Subsystem for Linux)
    PLATFORM_FLAVOR :=
    PLATFORM_HINT := Run make target inside WSL. Scripts are executed with bash.
  else ifeq ($(UNAME_S),Darwin)
    PLATFORM := macOS
    PLATFORM_FLAVOR := Darwin
    PLATFORM_HINT := Run make target in Terminal. Scripts are executed with bash.
  else ifeq ($(UNAME_S),Linux)
    PLATFORM := Linux
    PLATFORM_FLAVOR :=
    PLATFORM_HINT := Run make target in your shell. Scripts are executed with bash.
  else ifneq (,$(filter MSYS% MINGW%,$(UNAME_S)))
    PLATFORM := Windows
    PLATFORM_FLAVOR := MSYS2/MinGW
    PLATFORM_HINT := Use Git Bash (MSYS2). Scripts are executed with bash.
  else ifneq (,$(filter CYGWIN%,$(UNAME_S)))
    PLATFORM := Windows
    PLATFORM_FLAVOR := Cygwin
    PLATFORM_HINT := Use Cygwin terminal. Scripts are executed with bash.
  else
    PLATFORM := Unknown
    PLATFORM_FLAVOR :=
    PLATFORM_HINT := Unknown platform; scripts attempt to use bash.
  endif

  ECHOBLANK := printf "\n"
endif

PLATFORM_LABEL := $(PLATFORM)$(if $(PLATFORM_FLAVOR), - $(PLATFORM_FLAVOR),)

STRICT ?= 1
ifeq ($(STRICT),1)
  MAKEFLAGS += --warn-undefined-variables
endif

# ---------------- Script paths ----------------
INSTALL_SCRIPT := scripts/install.sh
START_SCRIPT   := scripts/start.sh
RUN_SCRIPT     := scripts/run.sh
STOP_SCRIPT    := scripts/stop.sh
PURGE_SCRIPT   := scripts/purge.sh
EXPORT_SCRIPT  := scripts/export.sh

# ---------------- Icons ----------------
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
	@echo Environment:
	@echo ---------------------------------------------
	@echo   Detected OS   : $(PLATFORM_LABEL)
	@echo   Make shell    : $(SHELL) $(.SHELLFLAGS)
	@echo   Script runner : $(BASH)
	@echo   Notes         : $(PLATFORM_HINT)
	@$(ECHOBLANK)
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

# --- INSTALL: OS-specific dispatch ---
ifeq ($(OS),Windows_NT)

# Windows: run *only* the PowerShell installers, never bash (prevents WSL hijack)
install:
	@echo "$(ICON_INSTALL) Starting environment installation for Windows..."
	@powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/windows/install_python_win.ps1" "$(CURDIR)"
	@powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/windows/install_docker.ps1"      "$(CURDIR)"
	@powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/windows/install_watsonx_win.ps1" "$(CURDIR)"
	@echo "Done: Installation finished (Windows)."

else

# macOS/Linux: keep using the cross-platform dispatcher script
install:
	@echo "$(ICON_INSTALL) Starting environment installation..."
	@$(CHECK_BASH)
	@"$(BASH)" "$(INSTALL_SCRIPT)"
	@echo "Done: Installation finished."

endif

start:
	@echo "$(ICON_START) Starting the watsonx Orchestrate server..."
	@$(CHECK_BASH)
	@"$(BASH)" "$(START_SCRIPT)"

run:
	@echo "$(ICON_RUN) Running the application setup (importing agents and tools)..."
	@$(CHECK_BASH)
	@"$(BASH)" "$(RUN_SCRIPT)"

stop:
	@echo "$(ICON_STOP) Stopping the server and any related containers..."
	@$(CHECK_BASH)
	@"$(BASH)" "$(STOP_SCRIPT)"

purge:
	@echo "$(ICON_PURGE) Purging the environment (stopping and removing all containers and images)..."
	@$(CHECK_BASH)
	@"$(BASH)" "$(PURGE_SCRIPT)"

export:
	@echo "$(ICON_EXPORT) Exporting/importing assets to your cloud environment using .env..."
	@$(CHECK_BASH)
	@"$(BASH)" "$(EXPORT_SCRIPT)"
	@echo "Done: Cloud export completed."

.DEFAULT_GOAL := help
