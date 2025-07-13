#!/usr/bin/env bash
# install.sh — detect OS and run platform-specific installers
# This script is designed to be run from the project root, e.g., `bash scripts/install.sh`

set -euo pipefail
IFS=$'\n\t'

# Determine the directory where this script is located to reliably find sub-scripts.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# The project root is the current working directory from where the script is invoked.
# All installations will be relative to this path.
INSTALL_ROOT="$(pwd)"

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

# helper: run a script and exit if it fails
run_script() {
  local script_path="$1"
  local install_dir="$2" # Accept the installation directory as an argument

  echo "→ Running ${script_path}"
  if [[ ! -x "${script_path}" ]]; then
    echo "  (Making ${script_path} executable)"
    chmod +x "${script_path}"
  fi

  # Execute the sub-script, passing the target installation directory as its first argument.
  # The sub-script MUST be written to handle this argument.
  "${script_path}" "${install_dir}"
}

# Detect the OS via uname
OS_TYPE="$(uname -s)"

case "${OS_TYPE}" in
  Linux*)
    echo "🖥  Detected Linux"
    # Verify it's Ubuntu
    if grep -qi '^ID=ubuntu' /etc/os-release; then
      echo "✔  Ubuntu identified"
      # Note: Paths now use $SCRIPT_DIR. We also pass $INSTALL_ROOT to each script.
      run_script "${SCRIPT_DIR}/ubuntu/install_python311.sh" "${INSTALL_ROOT}"
      run_script "${SCRIPT_DIR}/ubuntu/install_docker.sh" "${INSTALL_ROOT}"
      run_script "${SCRIPT_DIR}/ubuntu/install_watsonx_pc.sh" "${INSTALL_ROOT}"

    else
      echo "❌  Unsupported Linux distro. This script only supports Ubuntu."
      exit 1
    fi
    ;;
  Darwin*)
    echo "🍎 Detected macOS"
    # --- FIXED PATH ---
    run_script "${SCRIPT_DIR}/mac/install_python311.sh" "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_docker.sh" "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_watsonx_mac.sh" "${INSTALL_ROOT}"
    ;;
  *)
    echo "❓ Unknown OS: ${OS_TYPE}"
    echo "This script supports only Ubuntu (Linux) and macOS."
    exit 1
    ;;
esac

echo "✅ All done!"