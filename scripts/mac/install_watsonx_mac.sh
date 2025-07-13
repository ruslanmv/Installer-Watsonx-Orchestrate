#!/bin/bash
# ┌────────────────────────────────────────────────────────────────────────────┐
# │                                                                            │
# │ ██╗    ██╗ █████╗ ████████╗███████╗ ██████╗ ███╗   ██╗██╗  ██╗             │
# │ ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██╔═══██╗████╗  ██║╚██╗██╔╝             │
# │ ██║ █╗ ██║███████║   ██║   ███████╗██║   ██║██╔██╗ ██║ ╚███╔╝              │
# │ ██║███╗██║██╔══██║   ██║   ╚════██║██║   ██║██║╚██╗██║ ██╔██╗              │
# │ ╚███╔███╔╝██║  ██║   ██║   ███████║╚██████╔╝██║ ╚████║██╔╝ ██╗             │
# │  ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝             │
# │                                                                            │
# │            watsonx Orchestrate  DEV EDITION  by ruslanmv.com               │
# └────────────────────────────────────────────────────────────────────────────┘
#
# Installs a chosen STABLE version of IBM watsonx Orchestrate ADK in an
# isolated Python virtual-environment (./venv).
#
# This script prepares the environment but does NOT start the server.
#
# If a ./venv directory already exists, installation is skipped.
#
# ── ACCOUNT TYPES ────────────────────────────────────────────────────────────
#   Account type is determined by the WO_DEVELOPER_EDITION_SOURCE variable:
#   1. 'orchestrate': Uses watsonx Orchestrate credentials (WO_INSTANCE + WO_API_KEY)
#   2. 'myibm': Uses watsonx.ai credentials (WO_ENTITLEMENT_KEY + WATSONX_APIKEY + WATSONX_SPACE_ID)
#
# Ensure an appropriate `.env` exists in this directory before running.
# ---------------------------------------------------------------------------
# The first argument to this script is the root directory for the installation.
INSTALL_ROOT="$1"

# Exit if the installation directory was not provided.
if [ -z "$INSTALL_ROOT" ]; then
  echo "❌ Error: Installation root directory not provided to script." >&2
  exit 1
fi
set -euo pipefail

# ── Blue runtime logo ────────────────────────────────────────────────────────
print_logo() {
  local BLUE="\033[1;34m"; local NC="\033[0m"
  echo -e "${BLUE}"
  cat <<'EOF'
                _
               | |
 _ __ _   _ ___| | __ _ _ __   _ __ _____   __
| '__| | | / __| |/ _` | '_ \| '_ ` _ \ \ / /
| |  | |_| \__ \ | (_| | | | | | | | | \ V /
|_|   \__,_|___/_|\__,_|_| |_|_| |_| |_|\_/

EOF
  echo -e "${NC}"
}

print_logo

# watsonx Orchestrate ADK Virtual Environment Setup Script
# Creates a Python virtual environment and installs watsonx Orchestrate ADK

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ────────────────────────────────────────────────────────────────────────────
#  Configuration
# ────────────────────────────────────────────────────────────────────────────
ADK_VERSIONS=( "1.5.0" "1.5.1" "1.6.0" "1.6.1" "1.6.2" "1.7.0" )
ENV_FILE="${INSTALL_ROOT}/.env"
VENV_DIR="${INSTALL_ROOT}/venv"
ADK_VERSION=""
ACCOUNT_TYPE=""
PYTHON_VERSIONS=( "python3.11" "python3.12" "python3.13" "python3" )

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Function to print header
print_header() {
    echo
    print_color $BLUE "=============================================="
    print_color $BLUE "$1"
    print_color $BLUE "=============================================="
    echo
}

# Function to print step
print_step() {
    print_color $CYAN "🔧 $1"
}

# Function to print success
print_success() {
    print_color $GREEN "✅ $1"
}

# Function to print warning
print_warning() {
    print_color $YELLOW "⚠️  $1"
}

# Function to print error
print_error() {
    print_color $RED "❌ $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to find available Python
find_python_old() {
    for python_cmd in "${PYTHON_VERSIONS[@]}"; do
        if command_exists "$python_cmd"; then
            # Check if it's a supported version
            local version=$($python_cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
            if [[ "$version" == "3.11" ]] || [[ "$version" == "3.12" ]] || [[ "$version" == "3.13" ]]; then
                echo "$python_cmd"
                return 0
            fi
        fi
    done
    return 1
}

# Function to find available Python
find_python() {
    for python_cmd in "${PYTHON_VERSIONS[@]}"; do
        if command_exists "$python_cmd"; then
            # Check if it's a supported version
            local version=$($python_cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
            if [[ "$version" == "3.11" ]] || [[ "$version" == "3.12" ]] || [[ "$version" == "3.13" ]]; then
                echo "$python_cmd"
                return 0
            fi
        fi
    done
    return 1
}



# Function to check .env file
check_env_file() {
    print_step "Checking for .env file..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        print_error ".env file not found in current directory"
        echo
        print_color $YELLOW "Please create a .env file with one of these configurations:"
        echo
        print_color $BLUE "For watsonx Orchestrate account:"
        cat << 'EOF'
WO_DEVELOPER_EDITION_SOURCE=orchestrate
WO_INSTANCE=https://api.<region>.watson-orchestrate.ibm.com/instances/<instance-id>
WO_API_KEY=your_orchestrate_api_key
EOF
        echo
        print_color $BLUE "For watsonx.ai account:"
        cat << 'EOF'
WO_DEVELOPER_EDITION_SOURCE=myibm
WO_ENTITLEMENT_KEY=your_entitlement_key
WATSONX_APIKEY=your_watsonx_api_key
WATSONX_SPACE_ID=your_space_id
WO_DEVELOPER_EDITION_SKIP_LOGIN=false
EOF
        echo
        exit 1
    fi
    
    print_success ".env file found"
}

# Function to load and validate .env
load_env() {
    print_step "Loading environment variables..."
    
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
    
    # Detect account type
    if [[ "${WO_DEVELOPER_EDITION_SOURCE:-}" == "orchestrate" ]]; then
        ACCOUNT_TYPE="orchestrate"
    elif [[ "${WO_DEVELOPER_EDITION_SOURCE:-}" == "myibm" ]]; then
        ACCOUNT_TYPE="watsonx.ai"
    else
        print_error "WO_DEVELOPER_EDITION_SOURCE is not set or has an invalid value in .env"
        print_error "It must be either 'orchestrate' or 'myibm'"
        exit 1
    fi
    
    print_success "Detected account source: ${WO_DEVELOPER_EDITION_SOURCE} (Account Type: ${ACCOUNT_TYPE})"
    
    # Validate required variables
    if [[ "$ACCOUNT_TYPE" == "orchestrate" ]]; then
        for var in WO_DEVELOPER_EDITION_SOURCE WO_INSTANCE WO_API_KEY; do
            if [[ -z "${!var:-}" ]]; then
                print_error "$var is missing in .env for 'orchestrate' source"
                exit 1
            fi
        done
    else # watsonx.ai
        for var in WO_DEVELOPER_EDITION_SOURCE WO_ENTITLEMENT_KEY WATSONX_APIKEY WATSONX_SPACE_ID; do
            if [[ -z "${!var:-}" ]]; then
                print_error "$var is missing in .env for 'myibm' source"
                exit 1
            fi
        done
    fi
    
    print_success "Environment variables validated"
}

# Function to check Python installation
check_python_old() {
    print_step "Checking Python installation..."
    
    local python_cmd
    if ! python_cmd=$(find_python); then
        print_error "No compatible Python version found (requires 3.11, 3.12, or 3.13)"
        echo
        print_color $YELLOW "Please install Python 3.11, 3.12, or 3.13 first:"
        print_color $YELLOW "• Using Homebrew: brew install python@3.12"
        print_color $YELLOW "• Or run the Python installation script first"
        exit 1
    fi
    
    local python_version=$($python_cmd --version)
    print_success "Found compatible Python: $python_version ($python_cmd)"
    echo "$python_cmd"
}

# Function to check Python installation
check_python() {
    print_step "Checking Python installation..."
    
    local python_cmd
    if ! python_cmd=$(find_python); then
        print_error "No compatible Python version found (requires 3.11, 3.12, or 3.13)"
        echo
        print_color $YELLOW "Please install Python 3.11, 3.12, or 3.13 first:"
        print_color $YELLOW "• Using Homebrew: brew install python@3.12"
        print_color $YELLOW "• Or run the Python installation script first"
        exit 1
    fi
    
    local python_version=$($python_cmd --version)
    print_success "Found compatible Python: $python_version ($python_cmd)"
    
    # Return the python command without any output
    echo "$python_cmd"
}

# Function to handle existing virtual environment
handle_existing_venv() {
    if [[ -d "$VENV_DIR" ]]; then
        print_warning "Virtual environment already exists at $VENV_DIR"
        echo
        print_color $YELLOW "What would you like to do?"
        print_color $BLUE "1) Use existing virtual environment"
        print_color $BLUE "2) Recreate virtual environment (removes existing)"
        print_color $BLUE "3) Exit and handle manually"
        echo
        
        while true; do
            read -p "Enter your choice (1-3): " choice
            case $choice in
                1)
                    print_step "Using existing virtual environment..."
                    return 0
                    ;;
                2)
                    print_step "Removing existing virtual environment..."
                    rm -rf "$VENV_DIR"
                    print_success "Existing virtual environment removed"
                    return 1
                    ;;
                3)
                    print_color $YELLOW "Exiting. Please handle the existing venv manually."
                    exit 0
                    ;;
                *)
                    print_error "Invalid choice. Please enter 1, 2, or 3."
                    ;;
            esac
        done
    fi
    return 1
}

# Function to create virtual environment
create_venv_old() {
    local python_cmd=$1
    
    print_step "Creating Python virtual environment in $VENV_DIR..."
    
    $python_cmd -m venv "$VENV_DIR"
    print_success "Virtual environment created successfully"
}


# Function to create virtual environment
create_venv() {
    local python_cmd=$1
    
    print_step "Creating Python virtual environment in $VENV_DIR..."
    
    # Validate python command exists before using it
    if ! command_exists "$python_cmd"; then
        print_error "Python command '$python_cmd' not found"
        return 1
    fi
    
    # Create the virtual environment
    if $python_cmd -m venv "$VENV_DIR"; then
        print_success "Virtual environment created successfully"
    else
        print_error "Failed to create virtual environment"
        return 1
    fi
}

# Function to activate virtual environment
activate_venv() {
    print_step "Activating virtual environment..."
    
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
    
    local python_version=$(python --version)
    print_success "Virtual environment activated - $python_version"
}

# Function to check existing ADK installation
check_existing_adk() {
    print_step "Checking for existing ADK installation..."
    
    local existing_version
    existing_version=$(pip show ibm-watsonx-orchestrate 2>/dev/null | awk '/^Version:/{print $2}')
    
    if [[ -n "$existing_version" ]]; then
        print_success "Found existing ADK version: $existing_version"
        echo
        print_color $YELLOW "What would you like to do?"
        print_color $BLUE "1) Keep existing version ($existing_version)"
        print_color $BLUE "2) Upgrade/change to a different version"
        print_color $BLUE "3) Reinstall same version"
        echo
        
        while true; do
            read -p "Enter your choice (1-3): " choice
            case $choice in
                1)
                    ADK_VERSION="$existing_version"
                    print_success "Keeping existing ADK version: $existing_version"
                    return 0
                    ;;
                2|3)
                    return 1
                    ;;
                *)
                    print_error "Invalid choice. Please enter 1, 2, or 3."
                    ;;
            esac
        done
    fi
    return 1
}

# Function to select ADK version
select_adk_version() {
    print_header "Select watsonx Orchestrate ADK Version"
    
    print_color $BLUE "Available ADK versions:"
    echo
    for i in "${!ADK_VERSIONS[@]}"; do
        printf "   %2d) %s\n" $((i+1)) "${ADK_VERSIONS[$i]}"
    done
    echo
    print_color $YELLOW "   0) Install latest version"
    echo
    
    while true; do
        read -p "Select ADK version number (0-${#ADK_VERSIONS[@]}): " idx
        
        if [[ "$idx" == "0" ]]; then
            ADK_VERSION="latest"
            print_success "Selected: Latest version"
            break
        elif [[ "$idx" =~ ^[0-9]+$ && "$idx" -ge 1 && "$idx" -le "${#ADK_VERSIONS[@]}" ]]; then
            ADK_VERSION="${ADK_VERSIONS[$((idx-1))]}"
            print_success "Selected: ADK version $ADK_VERSION"
            break
        else
            print_error "Invalid selection. Please enter a number between 0 and ${#ADK_VERSIONS[@]}"
        fi
    done
}

# Function to install ADK
install_adk() {
    print_header "Installing watsonx Orchestrate ADK"
    
    print_step "Upgrading pip..."
    pip install --quiet --upgrade pip
    
    if [[ "$ADK_VERSION" == "latest" ]]; then
        print_step "Installing latest ibm-watsonx-orchestrate..."
        pip install --upgrade ibm-watsonx-orchestrate
        
        # Get the installed version
        ADK_VERSION=$(pip show ibm-watsonx-orchestrate | awk '/^Version:/{print $2}')
    else
        print_step "Installing ibm-watsonx-orchestrate==$ADK_VERSION..."
        pip install --upgrade "ibm-watsonx-orchestrate==$ADK_VERSION"
    fi
    
    print_success "ADK version $ADK_VERSION installed successfully"
}

# Function to verify installation
verify_installation() {
    print_header "Verifying Installation"
    
    print_step "Checking ADK installation..."
    
    if command_exists orchestrate; then
        local adk_version=$(orchestrate --version 2>/dev/null || echo "unknown")
        print_success "orchestrate command available - version: $adk_version"
    else
        print_warning "orchestrate command not found in PATH"
        print_color $YELLOW "Try reactivating the virtual environment: source venv/bin/activate"
    fi
    
    # Check Python packages
    print_step "Checking installed packages..."
    local installed_version=$(pip show ibm-watsonx-orchestrate | awk '/^Version:/{print $2}')
    print_success "ibm-watsonx-orchestrate version: $installed_version"
    
    # Show Python info
    local python_info=$(python -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
    print_success "Python: $python_info"
    
    # Show virtual environment location
    print_success "Virtual environment: $VIRTUAL_ENV"
}

# Function to setup IBM Cloud CLI (optional)
setup_ibm_cli() {
    print_header "IBM Cloud CLI Setup (Optional)"
    
    if ! command_exists ibmcloud; then
        print_warning "IBM Cloud CLI not found"
        echo
        read -p "Do you want to install IBM Cloud CLI? (y/N): " install_cli
        if [[ $install_cli =~ ^[Yy]$ ]]; then
            print_step "Installing IBM Cloud CLI..."
            if [[ "$(uname)" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install ibmcloud-cli
                else
                    curl -fsSL https://clis.cloud.ibm.com/install/osx | sh
                fi
            else
                curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
            fi
            print_success "IBM Cloud CLI installed"
        else
            print_warning "Skipping IBM Cloud CLI installation"
            return 0
        fi
    fi
    
    # Login to IBM Cloud
    print_step "Setting up IBM Cloud login..."
    
    local region="us-south"
    if [[ "$ACCOUNT_TYPE" == "orchestrate" ]]; then
        # Extract region from WO_INSTANCE URL
        region=$(echo "$WO_INSTANCE" | sed -n 's/.*api\.\([^.]*\)\.watson.*/\1/p')
        [[ -z "$region" ]] && region="us-south"
    fi
    
    print_step "Logging into IBM Cloud (region: $region)..."
    if ibmcloud login --apikey "${WO_API_KEY:-$WO_ENTITLEMENT_KEY}" -r "$region"; then
        print_success "IBM Cloud login successful"
        
        print_step "Logging Docker into IBM Container Registry..."
        if ibmcloud cr login; then
            print_success "Container Registry login successful"
        else
            print_warning "Container Registry login failed"
        fi
    else
        print_warning "IBM Cloud login failed"
    fi
}

# Function to show post-installation instructions
show_post_install() {
    print_header "Installation Complete! 🎉"
    
    print_color $GREEN "✅ Environment setup for ADK v$ADK_VERSION is complete"
    echo
    print_color $PURPLE "📋 Next Steps:"
    print_color $BLUE "1. Activate the virtual environment:"
    print_color $YELLOW "   source venv/bin/activate"
    echo
    print_color $BLUE "2. Verify the installation:"
    print_color $YELLOW "   orchestrate --version"
    echo
    print_color $BLUE "3. Start the watsonx Orchestrate server:"
    print_color $YELLOW "   orchestrate server start --env-file=.env"
    echo
    print_color $BLUE "4. Access the UI at:"
    print_color $YELLOW "   http://localhost:3000/chat-lite"
    echo
    print_color $PURPLE "🔧 Useful Commands:"
    print_color $BLUE "• Check server status:"
    print_color $YELLOW "  orchestrate server logs"
    echo
    print_color $BLUE "• Stop the server:"
    print_color $YELLOW "  orchestrate server stop"
    echo
    print_color $BLUE "• Reset the server (if issues occur):"
    print_color $YELLOW "  orchestrate server reset"
    echo
    print_color $BLUE "• Activate environment (when needed):"
    print_color $YELLOW "  source venv/bin/activate"
    echo
    print_color $BLUE "• Deactivate environment:"
    print_color $YELLOW "  deactivate"
    echo
    print_color $PURPLE "📁 Project Structure:"
    print_color $BLUE "• Virtual environment: ./venv/"
    print_color $BLUE "• Environment config: ./.env"
    print_color $BLUE "• ADK version: $ADK_VERSION"
    echo
    print_color $GREEN "Happy building! 🚀"
    print_color $CYAN "For more information, visit: https://ruslanmv.com"
}

# Function to show current status
show_status() {
    print_header "Current Environment Status"
    
    # Check if venv exists
    if [[ -d "$VENV_DIR" ]]; then
        print_success "Virtual environment exists at: $VENV_DIR"
        
        # Check if activated
        if [[ -n "${VIRTUAL_ENV:-}" ]]; then
            print_success "Virtual environment is currently activated"
            print_color $BLUE "Active environment: $VIRTUAL_ENV"
        else
            print_warning "Virtual environment exists but is not activated"
            print_color $YELLOW "To activate: source venv/bin/activate"
        fi
        
        # Check ADK installation in venv
        if [[ -f "$VENV_DIR/bin/pip" ]]; then
            local adk_version=$("$VENV_DIR/bin/pip" show ibm-watsonx-orchestrate 2>/dev/null | awk '/^Version:/{print $2}')
            if [[ -n "$adk_version" ]]; then
                print_success "ADK installed in venv: version $adk_version"
            else
                print_warning "ADK not installed in virtual environment"
            fi
        fi
    else
        print_warning "Virtual environment not found at: $VENV_DIR"
    fi
    
    # Check .env file
    if [[ -f "$ENV_FILE" ]]; then
        print_success ".env file exists"
        if [[ -n "${WO_DEVELOPER_EDITION_SOURCE:-}" ]]; then
            print_color $BLUE "Account type: ${WO_DEVELOPER_EDITION_SOURCE}"
        fi
    else
        print_warning ".env file not found"
    fi
    
    # Check Python
    if command_exists python3; then
        local python_version=$(python3 --version)
        print_success "System Python: $python_version"
    else
        print_warning "Python3 not found"
    fi
    
    # Check if orchestrate command is available
    if command_exists orchestrate; then
        local orchestrate_version=$(orchestrate --version 2>/dev/null || echo "unknown")
        print_success "orchestrate command available: $orchestrate_version"
    else
        print_warning "orchestrate command not available"
    fi
}

# Function to clean up environment
cleanup_environment() {
    print_header "Environment Cleanup"
    
    print_color $YELLOW "This will remove the virtual environment and all installed packages."
    print_color $RED "This action cannot be undone!"
    echo
    
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Cleanup cancelled."
        return 0
    fi
    
    if [[ -d "$VENV_DIR" ]]; then
        print_step "Removing virtual environment..."
        rm -rf "$VENV_DIR"
        print_success "Virtual environment removed"
    else
        print_warning "No virtual environment found to remove"
    fi
    
    print_success "Cleanup completed"
}

# Function to update ADK
update_adk() {
    print_header "Update watsonx Orchestrate ADK"
    
    if [[ ! -d "$VENV_DIR" ]]; then
        print_error "Virtual environment not found. Please create it first."
        return 1
    fi
    
    # Activate venv
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
    
    # Check current version
    local current_version=$(pip show ibm-watsonx-orchestrate 2>/dev/null | awk '/^Version:/{print $2}')
    if [[ -n "$current_version" ]]; then
        print_color $BLUE "Current ADK version: $current_version"
    else
        print_warning "ADK not currently installed"
    fi
    
    echo
    print_color $YELLOW "Update options:"
    print_color $BLUE "1) Update to latest version"
    print_color $BLUE "2) Install specific version"
    print_color $BLUE "3) Cancel"
    echo
    
    while true; do
        read -p "Enter your choice (1-3): " choice
        case $choice in
            1)
                print_step "Updating to latest version..."
                pip install --upgrade ibm-watsonx-orchestrate
                local new_version=$(pip show ibm-watsonx-orchestrate | awk '/^Version:/{print $2}')
                print_success "Updated to version: $new_version"
                break
                ;;
            2)
                select_adk_version
                install_adk
                break
                ;;
            3)
                print_color $YELLOW "Update cancelled."
                return 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
}

# Main menu function
show_menu() {
    clear
    print_header "watsonx Orchestrate ADK Environment Manager"
    print_color $BLUE "Virtual Environment Setup and Management Tool"
    echo
    
    # Show current status briefly
    if [[ -d "$VENV_DIR" ]]; then
        if [[ -n "${VIRTUAL_ENV:-}" ]]; then
            print_color $GREEN "Status: Virtual environment active"
        else
            print_color $YELLOW "Status: Virtual environment exists (not active)"
        fi
    else
        print_color $YELLOW "Status: No virtual environment found"
    fi
    
    if [[ -f "$ENV_FILE" ]]; then
        print_color $GREEN "Config: .env file found"
    else
        print_color $RED "Config: .env file missing"
    fi
    echo
    
    print_color $YELLOW "Choose an option:"
    echo
    print_color $GREEN "1) 🚀 Full Setup (Create venv + Install ADK)"
    print_color $GREEN "   - Creates virtual environment"
    print_color $GREEN "   - Installs watsonx Orchestrate ADK"
    print_color $GREEN "   - Sets up IBM Cloud CLI (optional)"
    echo
    print_color $BLUE "2) 📦 Create Virtual Environment Only"
    print_color $BLUE "3) 🔧 Install/Update ADK in Existing Environment"
    print_color $BLUE "4) ☁️  Setup IBM Cloud CLI"
    echo
    print_color $PURPLE "5) 📊 Show Environment Status"
    print_color $PURPLE "6) ✅ Verify Installation"
    print_color $PURPLE "7) 🔄 Update ADK"
    echo
    print_color $YELLOW "8) 🧹 Clean Up Environment"
    print_color $RED "9) 🚪 Exit"
    echo
}

# Main script execution
main() {
    # Check if .env exists for operations that need it
    local needs_env=true
    
    while true; do
        show_menu
        read -p "Enter your choice (1-9): " choice
        
        case $choice in
  
            1)
                # Full setup
                check_env_file
                load_env
                
                # Get python command properly
                local python_cmd
                #python_cmd=$(check_python)
                python_cmd="python" 
                if ! handle_existing_venv; then
                    create_venv "$python_cmd"
                fi
                
                activate_venv
                
                if ! check_existing_adk; then
                    select_adk_version
                    install_adk
                fi
                
                verify_installation
                
                echo
                read -p "Do you want to setup IBM Cloud CLI? (y/N): " setup_cli
                if [[ $setup_cli =~ ^[Yy]$ ]]; then
                    setup_ibm_cli
                fi
                
                show_post_install
                read -p "Press Enter to continue..."
                ;;
            2)
                # Create venv only
                local python_cmd
                python_cmd=$(check_python)
                
                if ! handle_existing_venv; then
                    create_venv "$python_cmd"
                fi
                
                activate_venv
                print_success "Virtual environment ready!"
                read -p "Press Enter to continue..."
                ;;
            3)
                # Install/Update ADK
                if [[ ! -d "$VENV_DIR" ]]; then
                    print_error "Virtual environment not found. Please create it first (option 2)."
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                activate_venv
                
                if ! check_existing_adk; then
                    select_adk_version
                    install_adk
                fi
                
                verify_installation
                read -p "Press Enter to continue..."
                ;;
            4)
                # Setup IBM Cloud CLI
                check_env_file
                load_env
                setup_ibm_cli
                read -p "Press Enter to continue..."
                ;;
            5)
                # Show status
                show_status
                read -p "Press Enter to continue..."
                ;;
            6)
                # Verify installation
                if [[ -d "$VENV_DIR" ]]; then
                    activate_venv
                    verify_installation
                else
                    print_error "Virtual environment not found. Please create it first."
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                # Update ADK
                update_adk
                read -p "Press Enter to continue..."
                ;;
            8)
                # Clean up
                cleanup_environment
                read -p "Press Enter to continue..."
                ;;
            9)
                # Exit
                print_color $GREEN "Goodbye! 👋"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-9."
                sleep 2
                ;;
        esac
    done
}

# Function to handle script interruption
cleanup_on_exit() {
    echo
    print_warning "Script interrupted. Cleaning up..."
    exit 1
}

# Set up signal handlers
trap cleanup_on_exit SIGINT SIGTERM

# Welcome message
print_header "Welcome to watsonx Orchestrate ADK Environment Manager"
print_color $PURPLE "This script will help you set up a Python virtual environment"
print_color $PURPLE "and install the watsonx Orchestrate ADK for development."
echo
print_color $BLUE "Features:"
print_color $BLUE "• 🐍 Creates isolated Python virtual environment"
print_color $BLUE "• 📦 Installs watsonx Orchestrate ADK"
print_color $BLUE "• ☁️  Optional IBM Cloud CLI setup"
print_color $BLUE "• 🔧 Environment management and updates"
print_color $BLUE "• ✅ Installation verification"
echo
print_color $YELLOW "Requirements:"
print_color $YELLOW "• Python 3.11, 3.12, or 3.13"
print_color $YELLOW "• .env file with proper credentials"
print_color $YELLOW "• Internet connection for package downloads"
echo

# Check if we're in the right directory context
if [[ ! -f "$ENV_FILE" ]] && [[ "$1" != "--skip-env-check" ]]; then
    print_warning "No .env file found in current directory"
    print_color $YELLOW "Make sure you're in the correct project directory"
    print_color $YELLOW "or create a .env file with your credentials first."
    echo
    read -p "Do you want to continue anyway? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Please create your .env file first, then run this script again."
        exit 0
    fi
fi

read -p "Press Enter to continue..."

# Run the main function
main "$@"