#!/usr/bin/env bash
# install.sh — detect OS and run platform-specific installers
# Run as: bash scripts/install.sh

set -euo pipefail
IFS=$'\n\t'

# Resolve this script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INSTALL_ROOT="$(pwd)"

# ── Blue runtime logo ─────────────────────────────────────────────
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

# Helper: run a sub-script and exit if it fails
run_script() {
  local script_path="$1"
  local install_dir="$2"
  echo "→ Running ${script_path}"
  if [[ ! -x "${script_path}" ]]; then
    echo "  (Making ${script_path} executable)"
    chmod +x "${script_path}" || true
  fi
  "${script_path}" "${install_dir}"
}

# NOTE: is_wsl() function and associated Windows path conversion helpers 
#       are kept but will only be used if OS_TYPE is MINGW/MSYS (Git Bash)
#       not for Linux/WSL Ubuntu.

# Detect WSL
is_wsl() {
  # Works for WSL1/WSL2
  grep -qiE '(Microsoft|WSL)' /proc/sys/kernel/osrelease 2>/dev/null && return 0
  grep -qiE '(Microsoft|WSL)' /proc/version 2>/dev/null && return 0
  return 1
}

# Convert POSIX path -> Windows path (prefers wslpath, then cygpath, else fallback)
to_windows_path() {
  local p="$1"
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$p"
    return
  fi
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
    return
  fi
  # crude fallback for /c/... style
  if [[ "$p" =~ ^/([a-zA-Z])/(.*)$ ]]; then
    local drv="${BASH_REMATCH[1]}"
    local rest="${BASH_REMATCH[2]}"
    printf "%s:\\%s" "${drv^^}" "${rest//\//\\}"
  else
    printf "%s" "$p"
  fi
}

# Pick PowerShell 7 first (pwsh), else Windows PowerShell. In WSL, try *.exe.
pick_powershell() {
  if command -v pwsh >/dev/null 2>&1; then echo "pwsh"; return; fi
  if command -v powershell >/dev/null 2>&1; then echo "powershell"; return; fi
  if command -v pwsh.exe >/dev/null 2>&1; then echo "pwsh.exe"; return; fi
  if command -v powershell.exe >/dev/null 2>&1; then echo "powershell.exe"; return; fi
  echo ""
}

OS_TYPE="$(uname -s)"

case "${OS_TYPE}" in
  Linux*)
    echo "🖥  Detected Linux"
    # This block will now correctly execute inside WSL Ubuntu as if it were native Linux
    if grep -qi '^ID=ubuntu' /etc/os-release; then
      echo "✔  Ubuntu identified"
      run_script "${SCRIPT_DIR}/ubuntu/install_python311.sh" "${INSTALL_ROOT}"
      run_script "${SCRIPT_DIR}/ubuntu/install_docker.sh" "${INSTALL_ROOT}"
      run_script "${SCRIPT_DIR}/ubuntu/install_watsonx_pc.sh" "${INSTALL_ROOT}"
    else
      echo "❌ Unsupported Linux distro. This script only supports Ubuntu."
      exit 1
    fi
    ;;
  Darwin*)
    echo "🍎 Detected macOS"
    run_script "${SCRIPT_DIR}/mac/install_python311.sh" "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_docker.sh" "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_watsonx_mac.sh" "${INSTALL_ROOT}"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    echo "🪟 Detected Windows"
    PS_BIN="$(pick_powershell)"
    if [[ -z "$PS_BIN" ]]; then
      echo "❌ PowerShell not found. Please install PowerShell 7+ (pwsh) or ensure 'powershell' is on PATH."
      exit 1
    fi
    echo "→ Using PowerShell: $PS_BIN"

    SCRIPT_DIR_WIN="$(to_windows_path "$SCRIPT_DIR")"
    INSTALL_ROOT_WIN="$(to_windows_path "$INSTALL_ROOT")"

    PS_INSTALL_PY="${SCRIPT_DIR_WIN}\\windows\\install_python_win.ps1"
    PS_INSTALL_DOCKER="${SCRIPT_DIR_WIN}\\windows\\install_docker.ps1"
    PS_INSTALL_WX="${SCRIPT_DIR_WIN}\\windows\\install_watsonx_win.ps1"

    "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$PS_INSTALL_PY" "$INSTALL_ROOT_WIN"
    "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$PS_INSTALL_DOCKER" "$INSTALL_ROOT_WIN"
    "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$PS_INSTALL_WX" "$INSTALL_ROOT_WIN"
    ;;
  *)
    echo "❓ Unknown OS: ${OS_TYPE}"
    echo "This script supports Ubuntu (Linux), macOS, and Windows."
    exit 1
    ;;
esac

echo "✅ All done!"