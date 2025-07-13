#!/usr/bin/env bash
#
# Docker Engine + Docker Compose v2 Installer for Ubuntu & Debian
# Version 1.2 — 2025-07-13
# Author: ruslanmv.com
set -euo pipefail

### ── COLORS ────────────────────────────────────────────────────────────────
RED='\033[0;31m'      # errors
GREEN='\033[0;32m'    # success
YELLOW='\033[1;33m'   # warnings/info
BLUE='\033[0;34m'     # headers
NC='\033[0m'          # no color

print_color() {
    # $1 = color, $2 = message
    printf "${1}%b${NC}\n" "$2"
}

print_header() {
    echo
    print_color "$BLUE" "────────────────────────────────────────────────────"
    print_color "$BLUE" " $1"
    print_color "$BLUE" "────────────────────────────────────────────────────"
    echo
}

### ── PRECHECKS ───────────────────────────────────────────────────────────
# Source /etc/os-release to get the OS ID
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    source /etc/os-release
else
    print_color "$RED" "Error: Cannot find /etc/os-release to determine the OS."
    exit 1
fi

# Check if the OS is Ubuntu or Debian
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    print_color "$RED" "Error: This script only supports Ubuntu and Debian-based systems."
    lsb_release -a || true
    exit 1
fi
print_color "$GREEN" "✓ Detected compatible OS: $PRETTY_NAME"

# Ensure running as root or via sudo
if [[ "$EUID" -ne 0 ]]; then
    print_color "$YELLOW" "Info: Re-running script with sudo..."
    exec sudo bash "$0" "$@"
fi

### ── EXISTING DOCKER CHECK ─────────────────────────────────────────────────
if command -v docker &> /dev/null; then
    existing_version=$(docker --version)
    print_header "Docker Already Installed"
    print_color "$YELLOW" "Detected: $existing_version"

    # ── FIX: Skip interactive prompt in CI environments ────────────────
    # If we're running under CI (e.g. GitHub Actions), just exit success.
    if [[ -n "${CI:-}" ]]; then
        print_color "$GREEN" "ⓘ CI environment detected, skipping Docker installation."
        exit 0
    fi

    read -rp "Do you want to reinstall Docker completely? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color "$GREEN" "No changes made. Exiting."
        exit 0
    fi

    print_header "Removing existing Docker installation"
    apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    rm -rf /var/lib/docker /var/lib/containerd
    print_color "$GREEN" "✓ Old Docker removed"
fi

### ── FUNCTIONS ────────────────────────────────────────────────────────────
install_prereqs() {
    print_header "Installing prerequisites"
    apt-get update -qq
    apt-get install -y ca-certificates curl gnupg lsb-release
    print_color "$GREEN" "✓ Prerequisites installed"
}

add_docker_repo() {
    print_header "Adding Docker’s official repository"
    install -m 0755 -d /etc/apt/keyrings
    
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/${ID} \
      $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    print_color "$GREEN" "✓ Docker repository for ${ID} added"
}

install_docker() {
    print_header "Installing Docker Engine & components"
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    print_color "$GREEN" "✓ Docker Engine and plugins installed"
}

post_install_config() {
    print_header "Post-installation configuration"
    local usr="${SUDO_USER:-root}"
    if id "$usr" &>/dev/null && [[ "$usr" != "root" ]]; then
        usermod -aG docker "$usr"
        print_color "$GREEN" "✓ Added '$usr' to the docker group"
    else
        print_color "$YELLOW" "ⓘ Skipping adding user to docker group (user is root or not found)."
    fi

    systemctl enable docker
    systemctl start docker
    print_color "$GREEN" "✓ Docker service enabled & started"
}

verify_install() {
    print_header "Verifying installation"
    docker_version=$(docker --version 2>/dev/null || echo "missing")
    compose_version=$(docker compose version 2>/dev/null || echo "missing")

    if [[ "$docker_version" != "missing" ]]; then
        print_color "$GREEN" "Docker: $docker_version"
    else
        print_color "$RED" "✗ Docker CLI not found!"
        exit 1
    fi

    if [[ "$compose_version" != "missing" ]]; then
        print_color "$GREEN" "Docker Compose v2: $compose_version"
    else
        print_color "$RED" "✗ docker compose plugin not found!"
        exit 1
    fi

    if docker info &>/dev/null; then
        print_color "$GREEN" "✓ Docker daemon is running"
    else
        print_color "$RED" "✗ Docker daemon is not running!"
        exit 1
    fi

    print_color "$GREEN" "🎉 All checks passed!"
}

print_post_steps() {
    print_header "Next Steps"
    print_color "$BLUE" "• Log out and back in (or reboot) so 'docker' group takes effect"
    print_color "$BLUE" "• Test with: docker run hello-world"
    print_color "$BLUE" "• Use 'docker compose' instead of 'docker-compose'"
    echo
}

### ── MAIN ────────────────────────────────────────────────────────────────
install_prereqs
add_docker_repo
install_docker
post_install_config
verify_install
print_post_steps
