# Use bash as the default shell for all recipes.
SHELL := /bin/bash

# Define the location of the main installation script.
INSTALL_SCRIPT := scripts/install.sh

# ==============================================================================
# HELP
# This target provides a self-documenting way to see available commands.
# Run `make help` to see the list.
# ==============================================================================
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make install   - Installs the environment by running all setup scripts."
	@echo "  make help      - Shows this help message."

# ==============================================================================
# MAIN TARGETS
# ==============================================================================

# The .PHONY declaration tells Make that 'install' is a recipe name,
# not a file to be created. This ensures it always runs when you call `make install`.
.PHONY: install
install:
	@echo "🚀 Starting environment installation..."
	@$(SHELL) $(INSTALL_SCRIPT)
	@echo "✅ Makefile finished."

# A default target to run when you just type `make`. It will show the help message.
.DEFAULT_GOAL := help