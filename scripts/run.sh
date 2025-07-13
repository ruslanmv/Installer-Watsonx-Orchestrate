#!/bin/bash
# scripts/run.sh - Import agents and tools, then optionally start the chat UI

set -e

# --- CONFIGURATION & PATHS ---
# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# FIX 1: Define the Project Root as the directory where the script is executed from.
# This makes all paths robust, regardless of the script's location.
PROJECT_ROOT="$(pwd)"
echo -e "${YELLOW}ℹ️  Project Root identified as: ${PROJECT_ROOT}${NC}"

# Define all paths relative to the Project Root
VENV_DIR="${PROJECT_ROOT}/venv"
ENV_FILE="${PROJECT_ROOT}/.env"
TOOLS_DIR="${PROJECT_ROOT}/tools"
AGENTS_DIR="${PROJECT_ROOT}/agents"


# --- VIRTUAL ENVIRONMENT ACTIVATION ---
if [[ -d "$VENV_DIR" ]]; then
  echo "📦 Activating virtual environment from: ${VENV_DIR}"
  # FIX 2: Use the full path to activate the venv
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  echo -n "🔧 Python " && python --version
  ADK_VERSION=$(pip show ibm-watsonx-orchestrate 2>/dev/null | awk '/^Version:/{print $2}')
  if [[ -z "$ADK_VERSION" ]]; then
    echo -e "${YELLOW}⚠️  Could not detect installed ADK version.${NC}"
  else
    echo -e "${GREEN}✅ Detected ADK version ${ADK_VERSION}${NC}"
  fi
else
  echo -e "${RED}❌ Virtual environment not found at '${VENV_DIR}'. Cannot proceed.${NC}"
  echo "   Please run the installer first (e.g., 'make install')."
  exit 1
fi


# --- HELPER FUNCTIONS ---

# Function to check if a command was successful
check_command() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 successful${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# Function to check if orchestrate command is available
check_orchestrate() {
    if ! command -v orchestrate &> /dev/null; then
        echo -e "${RED}Error: 'orchestrate' command not found.${NC}"
        echo "Please make sure the watsonx Orchestrate ADK is installed and the venv is active."
        exit 1
    fi
}

# Function to check if server is running
check_server() {
    echo -e "${YELLOW}Checking if orchestrate server is running...${NC}"
    if curl -s http://localhost:4321/api/v1/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Server is running${NC}"
    else
        echo -e "${RED}✗ Server is not running or not ready.${NC}"
        # FIX 3: Update instructions with correct paths
        echo "  Please start the server first with: bash scripts/start.sh"
        echo "  Or run: orchestrate server start --env-file=\"${ENV_FILE}\""
        exit 1
    fi
}

# Function to activate local environment
activate_environment() {
    echo -e "${CYAN}Step 1: Activating local environment...${NC}"
    orchestrate env activate local
    check_command "Environment activation"
}

# Function to import tools
import_tools() {
    echo -e "${CYAN}Step 2: Importing tools...${NC}"
    # MODIFIED: Check if the tools directory exists. If not, show a warning and skip.
    if [ ! -d "$TOOLS_DIR" ]; then
        echo -e "${YELLOW}⚠️  Warning: 'tools' directory not found. Skipping tool import.${NC}"
        return
    fi

    # Import tools using full paths
    for tool_file in "${TOOLS_DIR}"/*.py "${TOOLS_DIR}"/*.{yaml,yml}; do
        if [ -f "$tool_file" ]; then
            tool_name=$(basename "$tool_file")
            tool_type="python"
            [[ "$tool_file" == *.yaml || "$tool_file" == *.yml ]] && tool_type="openapi"

            echo "Importing ${tool_name}..."
            orchestrate tools import -k "$tool_type" -f "$tool_file"
            check_command "${tool_name} import"
        fi
    done
}

# Function to import agents
import_agents() {
    echo -e "${CYAN}Step 3: Importing agents...${NC}"
    # MODIFIED: Check if the agents directory exists. If not, show a warning and skip.
    if [ ! -d "$AGENTS_DIR" ]; then
        echo -e "${YELLOW}⚠️  Warning: 'agents' directory not found. Skipping agent import.${NC}"
        return
    fi
    
    # Import all agent files using full paths
    for agent_file in "${AGENTS_DIR}"/*.{yaml,yml}; do
        if [ -f "$agent_file" ]; then
            agent_name=$(basename "$agent_file")
            # Skip the orchestrator agent to import it last
            if [[ "$agent_name" == "orchestrator_agent.yaml" ]]; then
                continue
            fi
            echo "Importing ${agent_name}..."
            orchestrate agents import -f "$agent_file"
            check_command "${agent_name} import"
        fi
    done

    # Import orchestrator agent last
    local orchestrator_file="${AGENTS_DIR}/orchestrator_agent.yaml"
    if [ -f "$orchestrator_file" ]; then
        echo "Importing orchestrator agent (final step)..."
        orchestrate agents import -f "$orchestrator_file"
        check_command "Orchestrator agent import"
    else
        echo -e "${YELLOW}Warning: orchestrator_agent.yaml not found, skipping.${NC}"
    fi
}

# Function to list imported agents
list_agents() {
    echo -e "${CYAN}Step 4: Checking imported agents...${NC}"
    echo "Currently imported agents:"
    orchestrate agents list
    check_command "Agent listing"
}

# Function to ask about starting UI
ask_start_ui() {
    echo -e "${CYAN}Step 5: Chat Interface${NC}"
    echo ""
    echo "All agents have been imported successfully!"
    echo ""
    
    while true; do
        read -p "Would you like to start the chat UI now? (y/n): " choice
        case $choice in
            [Yy]*)
                echo -e "${GREEN}Starting chat UI in the background...${NC}"
                orchestrate chat start &
                sleep 2
                echo ""
                echo -e "${GREEN}✓ Chat UI is starting!${NC}"
                echo -e "${YELLOW}📌 Open your browser and go to: http://localhost:3000/chat-lite${NC}"
                echo ""
                break
                ;;
            [Nn]*)
                echo -e "${YELLOW}You can start the chat UI later with: orchestrate chat start${NC}"
                break
                ;;
            *)
                echo "Please enter y or n"
                ;;
        esac
    done
}

# Function to show helpful information
show_info() {
    echo ""
    echo -e "${BLUE}=== Helpful Information ===${NC}"
    echo "• Chat UI is available at: http://localhost:3000/chat-lite"
    echo "• API documentation: http://localhost:4321/docs"
    echo "• To stop the server: orchestrate server stop"
    echo "• To view logs: orchestrate server logs"
    echo ""
}

# --- Main Execution ---
main() {
    echo ""
    echo -e "${GREEN}=== watsonx Orchestrate Agent & Tool Setup ===${NC}"
    
    check_orchestrate
    check_server
    activate_environment
    import_tools
    import_agents
    list_agents
    show_info
    ask_start_ui
    
    echo ""
    echo -e "${GREEN}=== Setup Complete! ===${NC}"
}

# Run the main function
main