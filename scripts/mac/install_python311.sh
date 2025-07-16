#!/bin/bash

# Python Installation Script for macOS
# Compatible with watsonx Orchestrate ADK (supports Python 3.11-3.13)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect macOS architecture
detect_arch() {
    if [[ $(uname -m) == "arm64" ]]; then
        echo "Apple Silicon (M1/M2/M3)"
    else
        echo "Intel"
    fi
}

# Function to detect shell
detect_shell() {
    if [[ -n "$ZSH_VERSION" ]]; then
        echo "zsh"
    elif [[ -n "$BASH_VERSION" ]]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

# Function to get shell config file
get_shell_config() {
    local shell_type=$(detect_shell)
    case $shell_type in
        "zsh")
            echo "$HOME/.zshrc"
            ;;
        "bash")
            echo "$HOME/.bash_profile"
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

# Function to check if Homebrew is installed
check_homebrew() {
    if ! command_exists brew; then
        print_color $YELLOW "Homebrew is not installed. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for current session
        if [[ $(uname -m) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        # Add to shell config
        local shell_config=$(get_shell_config)
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$shell_config"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$shell_config"
        fi

        print_color $GREEN "✓ Homebrew installed successfully"
    else
        print_color $GREEN "✓ Homebrew is already installed"
    fi
}

# Function to get current Python version
get_current_python_version() {
    if command_exists python3; then
        python3 --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown"
    else
        echo "not installed"
    fi
}

# Function to check if Python version is installed via Homebrew
check_python_installed() {
    local version=$1
    brew list python@$version >/dev/null 2>&1
}

# Function to install Python version
install_python() {
    local version=$1
    print_header "Installing Python $version"

    # Check if already installed
    if check_python_installed $version; then
        print_color $YELLOW "Python $version is already installed via Homebrew!"
        read -p "Do you want to reinstall it? (y/N): " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            setup_python_links $version
            return 0
        fi

        print_color $BLUE "Uninstalling existing Python $version..."
        brew uninstall python@$version || true
    fi

    print_color $BLUE "Installing Python $version via Homebrew..."
    brew install python@$version

    print_color $GREEN "✓ Python $version installed successfully!"

    setup_python_links $version
}

# Function to setup Python links and PATH
setup_python_links() {
    local version=$1
    print_header "Setting up Python $version as default"

    # Get Homebrew prefix
    local brew_prefix
    if [[ $(uname -m) == "arm64" ]]; then
        brew_prefix="/opt/homebrew"
    else
        brew_prefix="/usr/local"
    fi

    local python_path="$brew_prefix/opt/python@$version/bin"
    local shell_config=$(get_shell_config)

    print_color $BLUE "Setting up symbolic links..."

    # Create symbolic links in Homebrew bin
    if [[ -f "$python_path/python$version" ]]; then
        ln -sf "$python_path/python$version" "$brew_prefix/bin/python3" 2>/dev/null || true
        ln -sf "$python_path/python$version" "$brew_prefix/bin/python" 2>/dev/null || true
    fi

    if [[ -f "$python_path/pip$version" ]]; then
        ln -sf "$python_path/pip$version" "$brew_prefix/bin/pip3" 2>/dev/null || true
        ln -sf "$python_path/pip$version" "$brew_prefix/bin/pip" 2>/dev/null || true
    fi

    print_color $BLUE "Updating PATH in $shell_config..."

    # Remove any existing Python PATH entries
    if [[ -f "$shell_config" ]]; then
        # Create backup
        cp "$shell_config" "$shell_config.backup.$(date +%Y%m%d_%H%M%S)"

        # Remove old Python PATH entries
        grep -v "python@" "$shell_config" > "$shell_config.tmp" && mv "$shell_config.tmp" "$shell_config"
    fi

    # Add new PATH entry
    echo "" >> "$shell_config"
    echo "# Python $version PATH (added by Python installer script)" >> "$shell_config"
    echo "export PATH=\"$python_path:\$PATH\"" >> "$shell_config"

    # Also add general Homebrew path if not present
    if ! grep -q "brew shellenv" "$shell_config" 2>/dev/null; then
        echo "" >> "$shell_config"
        echo "# Homebrew PATH" >> "$shell_config"
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$shell_config"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$shell_config"
        fi
    fi

    # Update current session PATH
    export PATH="$python_path:$PATH"

    print_color $GREEN "✓ Python $version is now set as default!"

    # Show current setup
    print_color $PURPLE "Current Python setup:"
    print_color $PURPLE "- Python path: $python_path"
    print_color $PURPLE "- Shell config: $shell_config"
    print_color $PURPLE "- Architecture: $(detect_arch)"
}

# --- FIXED FUNCTION ---
# This function now creates a virtual environment to avoid the 'externally-managed-environment' error.
install_adk_requirements() {
    print_header "Setup Project Environment for watsonx ADK"

    # Explain why a venv is necessary due to PEP 668.
    print_color $YELLOW "Your Python is 'externally managed' (by Homebrew)."
    print_color $YELLOW "To prevent system conflicts, we must install packages in a safe, isolated virtual environment."
    print_color $YELLOW "This is the recommended best practice for all Python projects. 🐍"
    echo

    # Define venv path and get user confirmation.
    local venv_path="./venv"
    read -p "Enter path for virtual environment [Default: $venv_path]: " user_venv_path
    venv_path="${user_venv_path:-$venv_path}"

    # Check if the directory already exists.
    if [ -d "$venv_path" ]; then
        print_color $RED "Directory '$venv_path' already exists."
        read -p "Do you want to remove it and recreate the environment? (y/N): " confirm_delete
        if [[ $confirm_delete =~ ^[Yy]$ ]]; then
            print_color $BLUE "Removing existing directory..."
            rm -rf "$venv_path"
        else
            print_color $YELLOW "Using existing virtual environment for installation."
        fi
    fi

    # Create the virtual environment if it doesn't exist.
    if [ ! -d "$venv_path" ]; then
        print_color $BLUE "Creating virtual environment at '$venv_path'..."
        if ! python3 -m venv "$venv_path"; then
            print_color $RED "✗ Failed to create virtual environment." >&2
            print_color $RED "Please check your Python 3 installation." >&2
            return 1
        fi
        print_color $GREEN "✓ Virtual environment created successfully."
    fi

    # Define the path to pip inside the venv.
    local venv_pip="$venv_path/bin/pip"

    # Check if pip exists in the venv.
    if [ ! -f "$venv_pip" ]; then
        print_color $RED "✗ Could not find pip inside the virtual environment at '$venv_pip'." >&2
        return 1
    fi

    # Install packages *inside* the virtual environment.
    print_color $BLUE "Installing/upgrading packages inside '$venv_path'..."
    if ! "$venv_pip" install --upgrade pip setuptools wheel; then
        print_color $RED "✗ Failed to upgrade pip, setuptools, and wheel." >&2
        return 1
    fi
    print_color $GREEN "✓ Upgraded pip, setuptools, and wheel."

    print_color $YELLOW "Ready to install watsonx Orchestrate ADK!"
    read -p "Do you want to install it now into your new environment? (y/N): " install_adk
    if [[ $install_adk =~ ^[Yy]$ ]]; then
        print_color $BLUE "Installing ibm-watsonx-orchestrate..."
        if ! "$venv_pip" install ibm-watsonx-orchestrate; then
            print_color $RED "✗ Failed to install watsonx Orchestrate ADK." >&2
            return 1
        fi
        print_color $GREEN "✓ watsonx Orchestrate ADK installed successfully!"
    fi
    echo
    print_color $PURPLE "======================================================"
    print_color $PURPLE "                      ✅ All Done!                     "
    print_color $PURPLE "======================================================"
    print_color $GREEN "Your project environment is ready."
    print_color $BLUE "To use it, you MUST activate it in your terminal:"
    echo
    print_color $YELLOW "source $venv_path/bin/activate"
    echo
    print_color $BLUE "Once activated, your command prompt will change."
    print_color $BLUE "To exit the environment later, just type: deactivate"
}

# Function to verify installation
verify_installation() {
    print_header "Verifying Python Installation"

    echo "Checking Python..."
    if command_exists python3; then
        python_version=$(python3 --version)
        python_path=$(which python3)
        print_color $GREEN "✓ Python3: $python_version"
        print_color $GREEN "✓ Location: $python_path"
    else
        print_color $RED "✗ Python3 not found"
        return 1
    fi

    if command_exists python; then
        python_version=$(python --version)
        python_path=$(which python)
        print_color $GREEN "✓ Python: $python_version"
        print_color $GREEN "✓ Location: $python_path"
    else
        print_color $YELLOW "⚠ 'python' command not available (only 'python3')"
    fi

    echo "Checking pip..."
    if command_exists pip3; then
        pip_version=$(pip3 --version)
        pip_path=$(which pip3)
        print_color $GREEN "✓ pip3: $pip_version"
        print_color $GREEN "✓ Location: $pip_path"
    else
        print_color $RED "✗ pip3 not found"
        return 1
    fi

    if command_exists pip; then
        pip_version=$(pip --version)
        pip_path=$(which pip)
        print_color $GREEN "✓ pip: $pip_version"
        print_color $GREEN "✓ Location: $pip_path"
    else
        print_color $YELLOW "⚠ 'pip' command not available (only 'pip3')"
    fi

    echo "Testing Python functionality..."
    if python3 -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" >/dev/null 2>&1; then
        python_info=$(python3 -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
        print_color $GREEN "✓ $python_info is working correctly"
    else
        print_color $RED "✗ Python is not working correctly"
        return 1
    fi

    # Check if it's compatible with watsonx Orchestrate ADK
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if [[ "$python_version" == "3.11" ]] || [[ "$python_version" == "3.12" ]] || [[ "$python_version" == "3.13" ]]; then
        print_color $GREEN "✓ Python $python_version is compatible with watsonx Orchestrate ADK"
    else
        print_color $YELLOW "⚠ Python $python_version compatibility with watsonx Orchestrate ADK is not guaranteed"
    fi

    print_color $GREEN "🎉 Python installation verification completed successfully!"
}

# Function to show post-installation instructions
show_post_install() {
    print_header "Post-Installation Instructions"

    local shell_config=$(get_shell_config)

    print_color $PURPLE "Your Python setup is ready for watsonx Orchestrate ADK!"
    echo
    print_color $BLUE "Important: Restart your terminal or run:"
    print_color $YELLOW "source $shell_config"
    echo
    print_color $BLUE "Next steps:"
    print_color $BLUE "1. Restart your terminal to apply PATH changes."
    print_color $BLUE "2. Verify the global install: python3 --version"
    print_color $BLUE "3. Go to your project directory and activate the virtual environment:"
    print_color $YELLOW "   cd /path/to/your/project"
    print_color $YELLOW "   source watsonx-venv/bin/activate"
    print_color $BLUE "4. You can now run 'orchestrate' commands."
    echo
    print_color $YELLOW "Troubleshooting tips:"
    print_color $YELLOW "- If 'python' command doesn't work globally, use 'python3'"
    print_color $YELLOW "- Always activate your virtual environment before working on your project."
    echo
    print_color $GREEN "For more information, visit the watsonx Orchestrate ADK documentation."
}

# Function to show current Python status
show_python_status() {
    print_header "Current Python Status"

    print_color $BLUE "System Information:"
    print_color $BLUE "- macOS: $(sw_vers -productVersion)"
    print_color $BLUE "- Architecture: $(detect_arch)"
    print_color $BLUE "- Shell: $(detect_shell)"
    print_color $BLUE "- Shell config: $(get_shell_config)"
    echo

    print_color $BLUE "Python Status:"

    # Check system Python
    if command_exists python3; then
        current_version=$(get_current_python_version)
        current_path=$(which python3)
        print_color $GREEN "✓ Current Python3: $current_version"
        print_color $GREEN "  Location: $current_path"
    else
        print_color $RED "✗ No Python3 found"
    fi

    if command_exists python; then
        python_version=$(python --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        python_path=$(which python)
        print_color $GREEN "✓ Python: $python_version"
        print_color $GREEN "  Location: $python_path"
    else
        print_color $YELLOW "⚠ 'python' command not available"
    fi

    echo
    print_color $BLUE "Available Python versions via Homebrew:"
    for version in 3.11 3.12 3.13; do
        if check_python_installed $version; then
            print_color $GREEN "✓ Python $version (installed)"
        else
            print_color $YELLOW "○ Python $version (not installed)"
        fi
    done

    echo
    print_color $BLUE "watsonx Orchestrate ADK Compatibility:"
    current_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
    if [[ "$current_version" == "3.11" ]] || [[ "$current_version" == "3.12" ]] || [[ "$current_version" == "3.13" ]]; then
        print_color $GREEN "✓ Current Python $current_version is compatible"
    elif [[ "$current_version" == "unknown" ]]; then
        print_color $RED "✗ No Python found"
    else
        print_color $YELLOW "⚠ Current Python $current_version may not be compatible (requires 3.11-3.13)"
    fi
}

# Main menu function
show_menu() {
    clear
    print_header "Python Installation for macOS"
    print_color $BLUE "Compatible with watsonx Orchestrate ADK (Python 3.11-3.13)"
    echo
    print_color $BLUE "Detected system: macOS $(sw_vers -productVersion) ($(detect_arch))"
    print_color $BLUE "Current shell: $(detect_shell)"
    echo

    # Show current Python status briefly
    current_version=$(get_current_python_version)
    if [[ "$current_version" != "not installed" ]]; then
        print_color $GREEN "Current Python: $current_version"
    else
        print_color $YELLOW "No Python3 currently available"
    fi
    echo

    print_color $YELLOW "Choose your preferred Python version:"
    echo
    print_color $GREEN "1) Python 3.12 (Recommended)"
    print_color $GREEN "   - Latest stable version"
    print_color $GREEN "   - Best performance and features"
    print_color $GREEN "   - Fully compatible with watsonx Orchestrate ADK"
    echo
    print_color $BLUE "2) Python 3.11 (Stable)"
    print_color $BLUE "   - Mature and well-tested"
    print_color $BLUE "   - Good compatibility with most packages"
    print_color $BLUE "   - Fully compatible with watsonx Orchestrate ADK"
    echo
    print_color $PURPLE "3) Python 3.13 (Latest)"
    print_color $PURPLE "   - Newest features and improvements"
    print_color $PURPLE "   - May have some package compatibility issues"
    print_color $PURPLE "   - Compatible with watsonx Orchestrate ADK"
    echo
    print_color $YELLOW "4) Show current Python status"
    print_color $YELLOW "5) Verify existing installation"
    print_color $YELLOW "6) Set up Project Environment & Install ADK"
    print_color $RED "7) Exit"
    echo
}

# Function to handle Python installation choice
handle_python_choice() {
    local choice=$1
    local version=""

    case $choice in
        1)
            version="3.12"
            ;;
        2)
            version="3.11"
            ;;
        3)
            version="3.13"
            ;;
        *)
            print_color $RED "Invalid Python version choice"
            return 1
            ;;
    esac

    print_color $BLUE "You selected Python $version"
    echo

    # Show what will happen
    print_color $YELLOW "This will:"
    print_color $YELLOW "1. Install Python $version via Homebrew"
    print_color $YELLOW "2. Set up symbolic links for 'python' and 'python3'"
    print_color $YELLOW "3. Update your PATH in $(get_shell_config)"
    print_color $YELLOW "4. Make Python $version the default in your new terminal sessions"
    echo

    read -p "Do you want to continue? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Installation cancelled."
        return 0
    fi

    check_homebrew
    install_python $version
    verify_installation && show_post_install
}

# Function to fix common Python issues
fix_python_issues() {
    print_header "Fixing Common Python Issues"

    print_color $BLUE "Checking for common Python issues..."

    # Check if python command exists
    if ! command_exists python; then
        print_color $YELLOW "Issue found: 'python' command not available"
        print_color $BLUE "Creating 'python' symlink..."

        local brew_prefix
        if [[ $(uname -m) == "arm64" ]]; then
            brew_prefix="/opt/homebrew"
        else
            brew_prefix="/usr/local"
        fi

        if [[ -f "$brew_prefix/bin/python3" ]]; then
            ln -sf "$brew_prefix/bin/python3" "$brew_prefix/bin/python"
            print_color $GREEN "✓ Created 'python' symlink"
        else
            print_color $RED "✗ python3 not found in expected location"
        fi
    else
        print_color $GREEN "✓ 'python' command is available"
    fi

    # Check if pip command exists
    if ! command_exists pip; then
        print_color $YELLOW "Issue found: 'pip' command not available"
        print_color $BLUE "Creating 'pip' symlink..."

        local brew_prefix
        if [[ $(uname -m) == "arm64" ]]; then
            brew_prefix="/opt/homebrew"
        else
            brew_prefix="/usr/local"
        fi

        if [[ -f "$brew_prefix/bin/pip3" ]]; then
            ln -sf "$brew_prefix/bin/pip3" "$brew_prefix/bin/pip"
            print_color $GREEN "✓ Created 'pip' symlink"
        else
            print_color $RED "✗ pip3 not found in expected location"
        fi
    else
        print_color $GREEN "✓ 'pip' command is available"
    fi

    # Check PATH
    print_color $BLUE "Checking PATH configuration..."
    local shell_config=$(get_shell_config)

    if [[ -f "$shell_config" ]]; then
        if grep -q "python@" "$shell_config"; then
            print_color $GREEN "✓ Python PATH found in $shell_config"
        else
            print_color $YELLOW "⚠ Python PATH not found in shell config"
            print_color $BLUE "You may need to restart your terminal or run: source $shell_config"
        fi
    else
        print_color $YELLOW "⚠ Shell config file not found: $shell_config"
    fi

    print_color $BLUE "Refreshing Homebrew links..."
    brew link --overwrite python@3.12 2>/dev/null || brew link --overwrite python@3.11 2>/dev/null || brew link --overwrite python@3.13 2>/dev/null || true

    print_color $GREEN "✓ Common issues check completed"
    print_color $YELLOW "If you still have issues, try restarting your terminal"
}

# Main script execution
main() {
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_color $RED "This script is designed for macOS only!"
        exit 1
    fi

    # Check for required tools
    if ! command_exists curl; then
        print_color $RED "curl is required but not installed. Please install curl first."
        exit 1
    fi

    while true; do
        show_menu
        read -p "Enter your choice (1-7): " choice

        case $choice in
            1|2|3)
                handle_python_choice $choice
                read -p "Press Enter to continue..."
                ;;
            4)
                show_python_status
                read -p "Press Enter to continue..."
                ;;
            5)
                verify_installation
                read -p "Press Enter to continue..."
                ;;
            6)
                if command_exists python3; then
                    install_adk_requirements
                else
                    print_color $RED "Python3 is not installed. Please install Python first."
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                print_color $GREEN "Goodbye!"
                exit 0
                ;;
            "fix"|"f")
                # Hidden option for fixing common issues
                fix_python_issues
                read -p "Press Enter to continue..."
                ;;
            *)
                print_color $RED "Invalid option. Please choose 1-7."
                print_color $YELLOW "Tip: You can also type 'fix' to attempt to fix common issues."
                sleep 2
                ;;
        esac
    done
}

# Cleanup function
cleanup() {
    print_color $YELLOW "\nScript interrupted. Cleaning up..."
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Show welcome message
print_header "Welcome to Python Installer for macOS"
print_color $PURPLE "This script will help you install Python 3.11, 3.12, or 3.13"
print_color $PURPLE "and configure it for use with watsonx Orchestrate ADK"
echo
print_color $BLUE "Features:"
print_color $BLUE "• Interactive installation process"
print_color $BLUE "• Automatic PATH configuration"
print_color $BLUE "• Sets up 'python' and 'pip' commands"
print_color $BLUE "• Guides you to create a safe virtual environment for your project"
print_color $BLUE "• Supports both Intel and Apple Silicon Macs"
echo
read -p "Press Enter to continue..."

# Run the main function
main "$@"