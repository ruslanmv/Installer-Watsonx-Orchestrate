#!/usr/bin/env bash
# install.sh — detect OS and run platform-specific installers
# Run as: bash scripts/install.sh

set -euo pipefail
IFS=$'\n\t'

# ---------------- Resolve paths ----------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
INSTALL_ROOT="$(pwd)"

# ---------------- Pretty header ----------------
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

# ---------------- Helpers ----------------
run_script() {
  local script_path="$1"; shift
  local install_dir="${1:-}"
  echo "→ Running ${script_path}"
  if [[ ! -x "${script_path}" ]]; then
    echo " (chmod +x ${script_path})"
    chmod +x "${script_path}" || true
  fi
  "${script_path}" "${install_dir}"
}

is_wsl() {
  grep -qiE '(Microsoft|WSL)' /proc/sys/kernel/osrelease 2>/dev/null && return 0
  grep -qiE '(Microsoft|WSL)' /proc/version 2>/dev/null && return 0
  return 1
}

to_windows_path() {
  local p="$1"
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$p" && return 0
  fi
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p" && return 0
  fi
  if [[ "$p" =~ ^/([a-zA-Z])/(.*)$ ]]; then
    local drv="${BASH_REMATCH[1]}"; local rest="${BASH_REMATCH[2]}"
    printf "%s:\\%s" "${drv^^}" "${rest//\//\\}"
  else
    printf "%s" "$p"
  fi
}

pick_powershell() {
  if command -v pwsh >/dev/null 2>&1; then echo "pwsh"; return; fi
  if command -v powershell >/dev/null 2>&1; then echo "powershell"; return; fi
  if [[ -x /mnt/c/Program\ Files/PowerShell/7/pwsh.exe ]]; then echo "/mnt/c/Program Files/PowerShell/7/pwsh.exe"; return; fi
  if [[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]; then echo "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"; return; fi
  echo ""
}

# ---------------- Platform detection ----------------
UNAME_S="$(uname -s 2>/dev/null || echo Unknown)"
PLATFORM=""
PLATFORM_HINT=""
PLATFORM_FLAVOR=""

print_logo

case "${UNAME_S}" in
  Darwin)
    PLATFORM="macOS"; PLATFORM_FLAVOR="Darwin"
    PLATFORM_HINT="Run from Terminal. Installers executed with /bin/bash."
    ;;
  Linux)
    if is_wsl; then
      # IMPORTANT: Treat WSL as Windows for installers (no Ubuntu auto-run).
      PLATFORM="Windows"; PLATFORM_FLAVOR="Invoked via WSL"
      PLATFORM_HINT="WSL detected. Per policy, running Windows installers via PowerShell."
    else
      PLATFORM="Linux"; PLATFORM_FLAVOR=""
      PLATFORM_HINT="Native Linux. Installers executed with /bin/bash."
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    PLATFORM="Windows"; PLATFORM_FLAVOR="POSIX layer"
    PLATFORM_HINT="POSIX-on-Windows shell. Running Windows installers via PowerShell."
    ;;
  *)
    PLATFORM="Unknown"
    PLATFORM_HINT="Unsupported platform."
    ;;
esac

echo "Environment:"
echo "---------------------------------------------"
echo " Detected OS : ${PLATFORM}${PLATFORM_FLAVOR:+ - ${PLATFORM_FLAVOR}}"
echo " Script root : ${SCRIPT_DIR}"
echo " Install root : ${INSTALL_ROOT}"
echo " Notes       : ${PLATFORM_HINT}"
echo

# ---------------- Dispatch per platform ----------------
case "${PLATFORM}" in
  macOS)
    run_script "${SCRIPT_DIR}/mac/install_python311.sh"   "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_docker.sh"      "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_watsonx_mac.sh" "${INSTALL_ROOT}"
    ;;
  Linux)
    if [[ -r /etc/os-release ]] && grep -qi '^ID=ubuntu' /etc/os-release; then
      echo "✔ Ubuntu identified"
      run_script "${SCRIPT_DIR}/ubuntu/install_python311.sh" "${INSTALL_ROOT}"
      run_script "${SCRIPT_DIR}/ubuntu/install_docker.sh"     "${INSTALL_ROOT}"
      run_script "${SCRIPT_DIR}/ubuntu/install_watsonx_pc.sh" "${INSTALL_ROOT}"
    else
      echo "❌ Unsupported Linux distro. This installer supports Ubuntu only."
      exit 1
    fi
    ;;
  Windows)
    PS_BIN="$(pick_powershell)"
    if [[ -z "${PS_BIN}" ]]; then
      echo "❌ PowerShell not found. Please install PowerShell 7 or ensure Windows PowerShell is available."
      exit 1
    fi
    SCRIPT_DIR_WIN="$(to_windows_path "${SCRIPT_DIR}")"
    INSTALL_ROOT_WIN="$(to_windows_path "${INSTALL_ROOT}")"
    "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR_WIN}\\windows\\install_python_win.ps1"   "${INSTALL_ROOT_WIN}"
    "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR_WIN}\\windows\\install_docker.ps1"      "${INSTALL_ROOT_WIN}"
    "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR_WIN}\\windows\\install_watsonx_win.ps1" "${INSTALL_ROOT_WIN}"
    ;;
  *)
    echo "❌ Unknown/unsupported platform: UNAME_S='${UNAME_S}'"
    echo " Supported: Ubuntu (Linux), macOS, and Windows."
    exit 1
    ;;
esac

echo
echo "✅ All done!"
