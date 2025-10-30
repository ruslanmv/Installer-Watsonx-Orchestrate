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
  # Detect WSL1/WSL2
  grep -qiE '(Microsoft|WSL)' /proc/sys/kernel/osrelease 2>/dev/null && return 0
  grep -qiE '(Microsoft|WSL)' /proc/version 2>/dev/null && return 0
  return 1
}

# POSIX -> Windows path (safe in WSL/MSYS/Cygwin)
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
  # Prefer PowerShell 7; fall back to Windows PowerShell
  if command -v pwsh >/dev/null 2>&1; then echo "pwsh"; return; fi
  if command -v powershell >/dev/null 2>&1; then echo "powershell"; return; fi
  if command -v pwsh.exe >/dev/null 2>&1; then echo "pwsh.exe"; return; fi
  if command -v powershell.exe >/dev/null 2>&1; then echo "powershell.exe"; return; fi
  # Common absolute fallback for WSL if PATH isn't bridged
  if [[ -x /mnt/c/Program\ Files/PowerShell/7/pwsh.exe ]]; then echo "/mnt/c/Program Files/PowerShell/7/pwsh.exe"; return; fi
  if [[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]; then echo "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"; return; fi
  echo ""
}

# ---------------- Platform detection ----------------
UNAME_S="$(uname -s 2>/dev/null || echo Unknown)"
OS_ENV="${OS:-}"
PLATFORM=""            # Windows | macOS | Linux | WSL
PLATFORM_FLAVOR=""
PLATFORM_HINT=""

# Only informational: repo on Windows drive?
ON_WIN_DRIVE=false
if [[ "${SCRIPT_DIR}" =~ ^/mnt/[a-zA-Z]/ ]] || [[ "${INSTALL_ROOT}" =~ ^/mnt/[a-zA-Z]/ ]]; then
  ON_WIN_DRIVE=true
fi

if [[ "${OS_ENV}" == "Windows_NT" ]] || [[ "${UNAME_S}" =~ ^(MINGW|MSYS|CYGWIN) ]]; then
  PLATFORM="Windows"
  if [[ -n "${MSYSTEM:-}" ]]; then
    PLATFORM_FLAVOR="Git Bash"
    PLATFORM_HINT="Running under Git Bash. Installers executed via PowerShell."
  else
    PLATFORM_FLAVOR="cmd.exe / PowerShell"
    PLATFORM_HINT="Use Command Prompt or PowerShell. Installers executed via PowerShell."
  fi
elif [[ "${UNAME_S}" == "Darwin" ]]; then
  PLATFORM="macOS"
  PLATFORM_FLAVOR="Darwin"
  PLATFORM_HINT="Run from Terminal. Installers executed with /bin/bash."
elif [[ "${UNAME_S}" == "Linux" ]]; then
  if is_wsl; then
    PLATFORM="WSL"
    if [[ "${PREFER_WINDOWS_ON_WSL:-0}" == "1" ]]; then
      PLATFORM_FLAVOR="Windows-side install"
      PLATFORM_HINT="Inside WSL. Forcing Windows installers via PowerShell (PREFER_WINDOWS_ON_WSL=1)."
    else
      PLATFORM_FLAVOR="Linux-side install"
      PLATFORM_HINT="Inside WSL. Running Linux (Ubuntu) installers. To force Windows installers, set PREFER_WINDOWS_ON_WSL=1."
    fi
  else
    PLATFORM="Linux"
    PLATFORM_HINT="Native Linux. Installers executed with /bin/bash."
  fi
else
  PLATFORM="Unknown"
  PLATFORM_HINT="Unsupported platform."
fi

PLATFORM_LABEL="${PLATFORM}${PLATFORM_FLAVOR:+ - ${PLATFORM_FLAVOR}}"

print_logo
echo "Environment:"
echo "---------------------------------------------"
echo " Detected OS : ${PLATFORM_LABEL}"
echo " Script root : ${SCRIPT_DIR}"
echo " Install root : ${INSTALL_ROOT}"
echo " Notes       : ${PLATFORM_HINT}"
echo

# ---------------- Dispatch per platform ----------------
case "${PLATFORM}" in
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
  WSL)
    if [[ -r /etc/os-release ]] && grep -qi '^ID=ubuntu' /etc/os-release; then
      echo "✔ Ubuntu on WSL identified"
      if [[ "${PREFER_WINDOWS_ON_WSL:-0}" == "1" ]]; then
        echo "→ PREFER_WINDOWS_ON_WSL=1 set. Invoking Windows installers from WSL via PowerShell."
        PS_BIN="$(pick_powershell)"
        if [[ -z "${PS_BIN}" ]]; then
          echo "❌ PowerShell not found on Windows side. Please install PowerShell 7 or ensure powershell.exe is on PATH."
          exit 1
        fi
        SCRIPT_DIR_WIN="$(to_windows_path "${SCRIPT_DIR}")"
        INSTALL_ROOT_WIN="$(to_windows_path "${INSTALL_ROOT}")"
        PS_INSTALL_PY="${SCRIPT_DIR_WIN}\\windows\\install_python_win.ps1"
        PS_INSTALL_DOCKER="${SCRIPT_DIR_WIN}\\windows\\install_docker.ps1"
        PS_INSTALL_WX="${SCRIPT_DIR_WIN}\\windows\\install_watsonx_win.ps1"

        "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${PS_INSTALL_PY}" "${INSTALL_ROOT_WIN}"
        "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${PS_INSTALL_DOCKER}" "${INSTALL_ROOT_WIN}"
        "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${PS_INSTALL_WX}" "${INSTALL_ROOT_WIN}"
      else
        echo "→ Proceeding with Linux (WSL) installers."
        run_script "${SCRIPT_DIR}/ubuntu/install_python311.sh" "${INSTALL_ROOT}"
        run_script "${SCRIPT_DIR}/ubuntu/install_docker.sh"     "${INSTALL_ROOT}"
        run_script "${SCRIPT_DIR}/ubuntu/install_watsonx_pc.sh" "${INSTALL_ROOT}"
      fi
    else
      echo "❌ Unsupported WSL distro. This installer supports Ubuntu on WSL."
      exit 1
    fi
    ;;
  macOS)
    run_script "${SCRIPT_DIR}/mac/install_python311.sh"   "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_docker.sh"      "${INSTALL_ROOT}"
    run_script "${SCRIPT_DIR}/mac/install_watsonx_mac.sh" "${INSTALL_ROOT}"
    ;;
  Windows)
    PS_BIN="${PS_BIN:-$(pick_powershell)}"
    if [[ -z "${PS_BIN}" ]]; then
      echo "❌ PowerShell not found. Install PowerShell 7 (recommended) or ensure Windows PowerShell is on PATH."
      exit 1
    fi
    echo "→ Using PowerShell: ${PS_BIN}"

    SCRIPT_DIR_WIN="$(to_windows_path "${SCRIPT_DIR}")"
    INSTALL_ROOT_WIN="$(to_windows_path "${INSTALL_ROOT}")"

    PS_INSTALL_PY="${SCRIPT_DIR_WIN}\\windows\\install_python_win.ps1"
    PS_INSTALL_DOCKER="${SCRIPT_DIR_WIN}\\windows\\install_docker.ps1"
    PS_INSTALL_WX="${SCRIPT_DIR_WIN}\\windows\\install_watsonx_win.ps1"

    "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${PS_INSTALL_PY}" "${INSTALL_ROOT_WIN}"
    "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${PS_INSTALL_DOCKER}" "${INSTALL_ROOT_WIN}"
    "${PS_BIN}" -NoProfile -ExecutionPolicy Bypass -File "${PS_INSTALL_WX}" "${INSTALL_ROOT_WIN}"
    ;;
  *)
    echo "❌ Unknown/unsupported platform: UNAME_S='${UNAME_S}', OS='${OS_ENV}'"
    echo " Supported: Ubuntu (Linux/WSL), macOS, and Windows."
    exit 1
    ;;
esac

echo
echo "✅ All done!"
