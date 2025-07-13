#!/bin/bash

# Docker Compose v2 Installation Script for macOS
# Compatible with watsonx Orchestrate ADK
# Version 2.0 - Fixed to handle pre-existing Colima instances

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
    else
        print_color $GREEN "✓ Homebrew is already installed"
    fi
}

# Function to install Rancher Desktop
install_rancher() {
    print_header "Installing Rancher Desktop"
    
    # Check if already installed
    if [[ -d "/Applications/Rancher Desktop.app" ]]; then
        print_color $YELLOW "Rancher Desktop is already installed!"
        read -p "Do you want to reinstall it? (y/N): " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    print_color $BLUE "Installing Rancher Desktop via Homebrew..."
    brew install --cask rancher
    
    print_color $GREEN "✓ Rancher Desktop installed successfully!"
    
    # Architecture-specific recommendations
    arch=$(detect_arch)
    print_color $BLUE "Detected architecture: $arch"
    
    if [[ $arch == "Apple Silicon (M1/M2/M3)" ]]; then
        print_color $YELLOW "📝 IMPORTANT for Apple Silicon users:"
        print_color $YELLOW "   - Enable Rosetta support in Rancher Desktop settings"
        print_color $YELLOW "   - Use Apple Virtualization (VZ) framework"
    fi
    
    echo
    print_color $PURPLE "🚀 Next steps:"
    print_color $PURPLE "1. Launch Rancher Desktop from Applications"
    print_color $PURPLE "2. Complete the initial setup"
    print_color $PURPLE "3. Configure recommended settings for watsonx Orchestrate"
    print_color $PURPLE "4. Docker and Docker Compose v2 will be available automatically"
    
    echo
    print_color $BLUE "Recommended Rancher Desktop settings for watsonx Orchestrate:"
    print_color $BLUE "- Container Engine: dockerd (moby)"
    print_color $BLUE "- Kubernetes: Disabled (unless needed)"
    print_color $BLUE "- Memory: 8GB minimum, 16GB recommended"
    print_color $BLUE "- CPUs: 4 minimum, 8 recommended"
}

# Function to install Colima
install_colima() {
    print_header "Installing Colima"
    
    # Check if already installed
    if command_exists colima; then
        print_color $YELLOW "Colima is already installed!"
        read -p "Do you want to reinstall it? (y/N): " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            configure_colima
            return 0
        fi
        # If reinstalling, uninstall first to ensure a clean state
        brew uninstall colima docker docker-compose || true
    fi
    
    print_color $BLUE "Installing Colima..."
    brew install colima
    
    print_color $BLUE "Installing Docker CLI tools..."
    brew install docker docker-compose
    
    print_color $GREEN "✓ Colima and Docker tools installed successfully!"
    
    configure_colima
}

# Function to configure Colima
configure_colima() {
    print_header "Configuring Colima"
    
    # Check for a pre-existing Colima instance and delete it to avoid conflicts
    if colima status >/dev/null 2>&1; then
        print_color $YELLOW "An existing Colima instance was found."
        print_color $YELLOW "To prevent configuration errors, the existing instance must be deleted."
        read -p "Do you want to PERMANENTLY DELETE the existing Colima instance and create a new one? (y/N): " delete_confirm
        if [[ $delete_confirm =~ ^[Yy]$ ]]; then
            print_color $BLUE "Stopping and deleting existing Colima instance..."
            colima stop || true # Stop first, ignore error if already stopped
            colima delete
            print_color $GREEN "✓ Existing instance deleted."
        else
            print_color $RED "Configuration aborted. Cannot apply new settings without deleting the existing instance."
            return 1
        fi
    fi
    
    # Architecture-specific configuration
    arch=$(detect_arch)
    print_color $BLUE "Detected architecture: $arch"
    
    if [[ $arch == "Apple Silicon (M1/M2/M3)" ]]; then
        print_color $BLUE "Starting Colima with Apple Silicon optimized settings..."
        colima start --cpu 4 --memory 8 --disk 60 --vm-type=vz --vz-rosetta
    else
        print_color $BLUE "Starting Colima with Intel optimized settings..."
        colima start --cpu 4 --memory 8 --disk 60
    fi
    
    print_color $GREEN "✓ Colima configured and started successfully!"
    
    echo
    print_color $PURPLE "🚀 Colima is now running with recommended settings:"
    print_color $PURPLE "- CPUs: 4"
    print_color $PURPLE "- Memory: 8GB"
    print_color $PURPLE "- Disk: 60GB"
    if [[ $arch == "Apple Silicon (M1/M2/M3)" ]]; then
        print_color $PURPLE "- VM Type: VZ (Apple Virtualization)"
        print_color $PURPLE "- Rosetta: Enabled"
    fi
}

# Function to verify installation
verify_installation() {
    print_header "Verifying Installation"
    
    echo "Checking Docker..."
    if command_exists docker; then
        docker_version=$(docker --version)
        print_color $GREEN "✓ Docker: $docker_version"
    else
        print_color $RED "✗ Docker not found"
        return 1
    fi
    
    echo "Checking Docker Compose..."
    # Use 'docker compose' (with a space) for v2 verification
    if docker compose version >/dev/null 2>&1; then
        compose_version=$(docker compose version)
        print_color $GREEN "✓ Docker Compose: $compose_version"
        print_color $GREEN "✓ Docker Compose v2 detected!"
    elif command_exists docker-compose; then
        compose_version=$(docker-compose --version)
        print_color $YELLOW "⚠ Found legacy docker-compose: $compose_version"
        print_color $YELLOW "   The script requires Docker Compose v2 (docker compose command)."
    else
        print_color $RED "✗ Docker Compose not found"
        return 1
    fi
    
    echo "Testing Docker functionality..."
    if docker info >/dev/null 2>&1; then
        print_color $GREEN "✓ Docker daemon is running"
    else
        print_color $RED "✗ Docker daemon is not running. Try starting Rancher Desktop or Colima."
        return 1
    fi
    
    print_color $GREEN "🎉 Installation verification completed successfully!"
}

# Function to show post-installation instructions
show_post_install() {
    print_header "Post-Installation Instructions"
    
    print_color $PURPLE "Your Docker Compose v2 setup is ready for watsonx Orchestrate ADK!"
    echo
    print_color $BLUE "Next steps:"
    print_color $BLUE "1. Ensure your .env file is properly configured"
    print_color $BLUE "2. Run: orchestrate server start --env-file=.env"
    print_color $BLUE "3. Access the UI at: http://localhost:3000/chat-lite"
    echo
    print_color $YELLOW "Troubleshooting tips:"
    print_color $YELLOW "- If you encounter issues, try: orchestrate server reset"
    print_color $YELLOW "- Check logs with: orchestrate server logs"
    print_color $YELLOW "- Ensure you have 8+ GB RAM and 8+ CPU cores available"
    echo
    print_color $GREEN "For more information, visit the watsonx Orchestrate ADK documentation."
}

# Main menu function
show_menu() {
    clear
    print_header "Docker Compose v2 Installation for macOS"
    print_color $BLUE "Compatible with watsonx Orchestrate ADK"
    echo
    print_color $BLUE "Detected system: macOS $(sw_vers -productVersion) ($(detect_arch))"
    echo
    print_color $YELLOW "Choose your preferred container management solution:"
    echo
    print_color $GREEN "1) Rancher Desktop "
    print_color $GREEN "   - Complete container management solution"
    print_color $GREEN "   - Includes Docker Compose v2 by default"
    print_color $GREEN "   - GUI interface available"
    print_color $GREEN "   - Best for users who prefer graphical tools"
    echo
    print_color $BLUE "2) Colima (Recommended)"
    print_color $BLUE "   - Lightweight Docker runtime"
    print_color $BLUE "   - Command-line focused"
    print_color $BLUE "   - Lower resource usage"
    print_color $BLUE "   - Best for developers who prefer CLI tools"
    echo
    print_color $PURPLE "3) Verify existing installation"
    print_color $RED "4) Exit"
    echo
}

# Main script execution
main() {
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_color $RED "This script is designed for macOS only!"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Enter your choice (1-4): " choice
        
        case $choice in
            1)
                check_homebrew
                install_rancher
                verify_installation && show_post_install
                read -p "Press Enter to continue..."
                ;;
            2)
                check_homebrew
                install_colima
                verify_installation && show_post_install
                read -p "Press Enter to continue..."
                ;;
            3)
                verify_installation
                read -p "Press Enter to continue..."
                ;;
            4)
                print_color $GREEN "Goodbye!"
                exit 0
                ;;
            *)
                print_color $RED "Invalid option. Please choose 1-4."
                sleep 2
                ;;
        esac
    done
}

# Run the main function
main "$@"