#!/bin/bash
# /scripts/start.sh - Start watsonx Orchestrate Developer Edition
set -e

# --- CONFIGURATION ---
# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# The Project Root is the directory where the script is executed from.
PROJECT_ROOT="$(pwd)"
echo -e "${YELLOW}ℹ️  Project Root: ${PROJECT_ROOT}${NC}"

# Define all paths relative to the Project Root
VENV_DIR="${PROJECT_ROOT}/venv"
ENV_FILE="${PROJECT_ROOT}/.env"


# --- VIRTUAL ENVIRONMENT CHECK ---
if [[ -d "$VENV_DIR" ]]; then
  echo "📦 Activating virtual environment from: ${VENV_DIR}"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  
  ADK_VERSION=$(pip show ibm-watsonx-orchestrate 2>/dev/null | awk '/^Version:/{print $2}')
  if [[ -z "$ADK_VERSION" ]]; then
    echo -e "${YELLOW}⚠️  Could not detect installed ADK version inside the venv.${NC}"
  else
    echo -e "${GREEN}✅ ADK version ${ADK_VERSION} detected.${NC}"
  fi
else
  echo -e "${RED}❌ Virtual environment not found at '${VENV_DIR}'.${NC}"
  echo "   Please run the installer first."
  exit 1
fi


# --- .ENV FILE CHECK ---
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Error: .env file not found at '${ENV_FILE}'${NC}"
    echo "   Please ensure a correctly configured .env file exists in your project root."
    exit 1
fi


# --- ORCHESTRATE COMMAND CHECK ---
if ! command -v orchestrate &> /dev/null; then
    echo -e "${RED}❌ Error: 'orchestrate' command not found.${NC}"
    echo "   This usually means the virtual environment is not activated correctly or the ADK is not installed."
    exit 1
fi


# --- START THE SERVER ---
echo -e "${GREEN}🚀 Starting watsonx Orchestrate server...${NC}"
echo -e "${YELLOW}   Using configuration from: ${ENV_FILE}${NC}"
orchestrate server start --env-file="$ENV_FILE"